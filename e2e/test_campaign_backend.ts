import assert from 'node:assert/strict';
import postgres from 'postgres';

const connection = process.env.SUPABASE_DB_URL;
if (!connection) throw new Error('Database test connection unavailable');
const db = postgres(connection, { max: 1 });
try {
  await db.begin(async tx => {
    const [schema] = await tx`select to_regprocedure('public.get_native_advertisements(text,text)') is not null as present`;
    assert.equal(schema.present, true, 'Tests must target the migrated backend');
    const [user] = await tx`select id from public.profiles where role<>'child' and not exists(select 1 from public.admin_roles a where a.user_id=profiles.id) limit 1`;
    if (!user) throw new Error('An ordinary profile is required for rollback-only checks');
    await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: user.id, role: 'authenticated', aal: 'aal1' })}, true), set_config('request.jwt.claim.sub', ${user.id}, true)`;
    await tx`update public.profiles set birthday=null where id=${user.id}`;
    let [eligible] = await tx`select public.campaign_audience_match(${user.id},'{}',null,true,false) as ok`;
    assert.equal(eligible.ok, false, 'Unknown age must never receive ads');
    await tx`update public.profiles set birthday=current_date-interval '17 years' where id=${user.id}`;
    [eligible] = await tx`select public.campaign_audience_match(${user.id},'{}',null,true,false) as ok`;
    assert.equal(eligible.ok, false, 'Under-18s must never receive ads');
    await tx`update public.profiles set birthday=current_date-interval '18 years' where id=${user.id}`;
    [eligible] = await tx`select public.campaign_audience_match(${user.id},'{}',null,true,false) as ok`;
    assert.equal(eligible.ok, true, 'An adult can be eligible');
    const [openBefore] = await tx`select coalesce((select opens from public.app_activity_days where user_id=${user.id} and day=current_date),0) as n`;
    await tx`select public.record_app_open('1.0.0','ios')`;
    const [openAfter] = await tx`select opens as n from public.app_activity_days where user_id=${user.id} and day=current_date`;
    assert.equal(openAfter.n, openBefore.n+1, 'An app open increments caller telemetry');
    const [challenge] = await tx`insert into public.sponsored_challenges(internal_name,content,metric,target,reward_minutes,join_mode,status,starts_at,ends_at) values ('ROLLBACK TEST','{"sv":{"title":"Test"},"en":{"title":"Test"}}','steps',1,30,'automatic','active',now()-interval '1 day',now()+interval '1 day') returning id`;
    await tx`insert into public.activity_steps(user_id,day,steps,distance_km,exercise_minutes,source) values(${user.id},current_date,10,1.5,7,'manual') on conflict(user_id,day,source) do update set steps=10,distance_km=1.5,exercise_minutes=7`;
    const [before] = await tx`select coalesce((select bonus_min from public.earned_balances where user_id=${user.id} and day=current_date),0) as bonus`;
    const [first] = await tx`select public.claim_sponsored_challenge_reward(${challenge.id},current_date) as result`;
    assert.equal(first.result.granted, true);
    assert.equal(first.result.minutes, 30);
    const [second] = await tx`select public.claim_sponsored_challenge_reward(${challenge.id},current_date) as result`;
    assert.equal(second.result.granted, false, 'A reward is never granted twice');
    const [after] = await tx`select bonus_min from public.earned_balances where user_id=${user.id} and day=current_date`;
    assert.equal(after.bonus_min, before.bonus+30);
    const [stats] = await tx`select s.distance_km, s.exercise_minutes, s.screen_time_bonus_seconds, (select sum(distance_km) from public.activity_steps where user_id=${user.id} and day=current_date) expected from public.user_daily_stats s where user_id=${user.id} and stat_date=current_date`;
    assert.equal(Number(stats.distance_km),Number(stats.expected));
    assert.equal(stats.screen_time_bonus_seconds,after.bonus_min*60);
    await tx.savepoint(async sp => {
      let denied=false;
      try { await sp`select public.admin_delete_user(${user.id},'security test')`; } catch { denied=true; }
      assert.equal(denied,true,'Ordinary users cannot request administrative deletion');
    }).catch(e => { if(e.code !== '25P02') throw e; });
    console.log('Campaign telemetry, age, reward and stats checks passed; rolling back');
    throw new Error('ROLLBACK_SUCCESS');
  });
} catch (e) {
  if (!(e instanceof Error) || e.message !== 'ROLLBACK_SUCCESS') throw e;
} finally { await db.end(); }
