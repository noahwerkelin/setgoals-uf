import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/integrations/supabase/types';

type Admin = SupabaseClient<Database>;
const ownedTables = [
  'task_notifications', 'activity_steps', 'earned_balances', 'streaks',
  'restriction_settings', 'user_badges', 'subscriptions', 'data_export_requests',
  'account_deletion_requests', 'coach_messages', 'coach_challenges', 'coach_insights',
  'coach_profiles', 'user_daily_stats', 'app_activity_days', 'campaign_events',
  'sponsored_challenge_rewards', 'sponsored_challenge_participants',
  'admin_support_notes', 'promotional_entitlements', 'admin_account_flags',
  'admin_preferences', 'admin_pro_grants', 'user_settings', 'user_roles',
] as const;

async function check(result: PromiseLike<{ error: { message: string } | null }>) {
  const { error } = await result;
  if (error) throw new Error('Account cleanup failed');
}

/** Delete only explicitly enumerated account-owned rows; preserve pseudonymous audit records. */
export async function deleteAdminTarget(admin: Admin, target: string) {
  const { data: children, error } = await admin.from('children').select('id,auth_user_id').eq('parent_id', target);
  if (error) throw new Error('Could not inspect family');
  // Children first: a retry must still discover undeleted children via the parent.
  const ids = [...new Set([...(children ?? []).flatMap(c => c.auth_user_id ? [c.auth_user_id] : []), target])];
  const { data: roles, error: roleError } = await admin.from('admin_roles').select('user_id').in('user_id', ids);
  if (roleError || roles?.length) throw new Error('Remove admin roles before deletion');

  // Tasks reference children and notifications reference tasks: remove in FK order.
  const { data: tasks, error: taskError } = await admin.from('tasks').select('id').in('parent_id', ids);
  if (taskError) throw new Error('Could not inspect tasks');
  if (tasks?.length) await check(admin.from('task_notifications').delete().in('task_id', tasks.map(t => t.id)));
  for (const id of ids) {
    await check(admin.from('task_notifications').delete().eq('user_id', id));
    await check(admin.from('tasks').delete().eq('parent_id', id));
    const { data: submitted, error: submittedError } = await admin.from('tasks').select('id').eq('child_user_id', id);
    if (submittedError) throw new Error('Could not inspect tasks');
    if (submitted?.length) await check(admin.from('task_notifications').delete().in('task_id', submitted.map(t => t.id)));
    await check(admin.from('tasks').delete().eq('child_user_id', id));
    await check(admin.from('parent_child_relationships').delete().eq('parent_id', id));
    await check(admin.from('parent_child_relationships').delete().eq('child_user_id', id));
    await check(admin.from('screentime_grants').delete().eq('parent_id', id));
    await check(admin.from('screentime_grants').delete().eq('child_user_id', id));
    await check(admin.from('friend_requests').delete().eq('sender_id', id));
    await check(admin.from('friend_requests').delete().eq('recipient_id', id));
    await check(admin.from('friendships').delete().eq('user_id', id));
    await check(admin.from('friendships').delete().eq('friend_id', id));
    await check(admin.from('username_reservations').delete().eq('owner_id', id));
    for (const table of ownedTables) await check(admin.from(table).delete().eq('user_id', id));
    // Linked child profiles must go before their Auth user. No parent session is touched.
    await check(admin.from('children').delete().eq('auth_user_id', id));
    await check(admin.from('children').delete().eq('parent_id', id));
    await check(admin.from('profiles').delete().eq('id', id));
    const { error: authError } = await admin.auth.admin.deleteUser(id);
    if (authError && authError.code !== 'user_not_found') throw new Error('Auth deletion failed');
  }
}
