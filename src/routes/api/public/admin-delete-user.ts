import { createFileRoute } from '@tanstack/react-router';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import type { Database } from '@/integrations/supabase/types';

const Input = z.object({ request_id: z.string().uuid() });
const website = 'https://setgoals.se';
function response(body: unknown, status: number, origin: string | null) {
  return new Response(JSON.stringify(body), { status, headers: {
    'Content-Type': 'application/json', 'Cache-Control': 'no-store', Vary: 'Origin',
    ...(origin === website ? { 'Access-Control-Allow-Origin': website } : {}),
  } });
}
export const Route = createFileRoute('/api/public/admin-delete-user')({
  server: { handlers: {
    OPTIONS: ({ request }) => new Response(null, { status: 204, headers: {
      ...(request.headers.get('origin') === website ? { 'Access-Control-Allow-Origin': website } : {}),
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type', Vary: 'Origin',
    } }),
    POST: async ({ request }) => {
      const origin = request.headers.get('origin');
      const send = (body: unknown, status = 200) => response(body, status, origin);
      const token = (request.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
      if (!token) return send({ error: 'Unauthorized' }, 401);
      const parsed = Input.safeParse(await request.json().catch(() => null));
      if (!parsed.success) return send({ error: 'Invalid request' }, 400);
      const url = process.env['SUPABASE_URL'];
      const key = process.env['SUPABASE_PUBLISHABLE_KEY'];
      if (!url || !key) return send({ error: 'Service unavailable' }, 503);
      const caller = createClient<Database>(url, key, { auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${token}` }, fetch: (input, init) => {
          const headers = new Headers(init?.headers); headers.set('apikey', key);
          return fetch(input, { ...init, headers });
        } },
      });
      const { data: identity, error: identityError } = await caller.auth.getUser(token);
      if (identityError || !identity.user) return send({ error: 'Unauthorized' }, 401);
      // Both checks run as the caller, before loading privileged credentials.
      const { data: can, error: canError } = await caller.rpc('admin_can_write', { _perm: 'users_delete' });
      if (canError || !can) return send({ error: 'Permission and MFA required' }, 403);
      const { data: job, error: jobError } = await caller.from('admin_user_deletions').select().eq('id', parsed.data.request_id).maybeSingle();
      if (jobError || !job || job.actor_id !== identity.user.id) return send({ error: 'Not found' }, 404);
      if (job.status === 'completed') return send({ ok: true });
      if (job.target_user_id === identity.user.id) return send({ error: 'Cannot delete own admin account' }, 403);
      const { supabaseAdmin } = await import('@/integrations/supabase/client.server');
      try {
        const { deleteAdminTarget } = await import('@/lib/admin-deletion.server');
        await deleteAdminTarget(supabaseAdmin, job.target_user_id);
        const { error: updateError } = await supabaseAdmin.from('admin_user_deletions').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', job.id);
        if (updateError) throw new Error('Could not finalize deletion');
        const { error: auditError } = await supabaseAdmin.from('admin_audit_log').insert({ actor_id: identity.user.id, action: 'user_deleted', target_user_id: job.target_user_id,
          details: { request_id: job.id, reason: job.reason }, aal: 'aal2' });
        if (auditError) throw new Error('Could not finalize audit');
        return send({ ok: true });
      } catch {
        await supabaseAdmin.from('admin_user_deletions').update({ status: 'failed' }).eq('id', job.id);
        return send({ error: 'Deletion incomplete; retry the same request' }, 500);
      }
    },
  } },
});
