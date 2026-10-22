import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";

/**
 * Today's family overview for the iOS app (same data as getFamilyToday on the
 * web) plus each member's step-earned screen time for the caller's local day.
 * Requires the signed-in user's bearer token.
 */

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

export const Route = createFileRoute("/api/public/family-today")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
        if (!token) return json({ error: "Unauthorized" }, 401);

        const url = process.env["SUPABASE_URL"]!;
        const key = process.env["SUPABASE_PUBLISHABLE_KEY"]!;
        const anon = createClient(url, key, {
          auth: { persistSession: false, autoRefreshToken: false },
          global: {
            fetch: (i: RequestInfo | URL, init?: RequestInit) => {
              const h = new Headers(init?.headers);
              if (key.startsWith("sb_") && h.get("Authorization") === `Bearer ${key}`) h.delete("Authorization");
              h.set("apikey", key);
              return fetch(i, { ...init, headers: h });
            },
          },
        });
        const { data: userRes, error: userErr } = await anon.auth.getUser(token);
        const uid = userRes?.user?.id;
        if (userErr || !uid) return json({ error: "Unauthorized" }, 401);

        const dayParam = new URL(request.url).searchParams.get("day") ?? "";
        const day = /^\d{4}-\d{2}-\d{2}$/.test(dayParam) ? dayParam : new Date().toISOString().slice(0, 10);

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { data, error } = await supabaseAdmin.rpc("family_today", { _uid: uid });
        if (error) return json({ error: "Could not load family" }, 500);
        const rows = (data ?? []) as Array<{
          member_id: string; name: string; avatar: string | null; steps: number; relation: string; is_self: boolean;
        }>;

        // Map family members to their auth accounts to read today's earned minutes.
        const childIds = rows.filter((r) => r.relation === "child").map((r) => r.member_id);
        const authByMember = new Map<string, string>();
        for (const r of rows) if (r.relation === "parent") authByMember.set(r.member_id, r.member_id);
        if (childIds.length) {
          const { data: kids } = await supabaseAdmin.from("children").select("id,auth_user_id").in("id", childIds);
          for (const k of kids ?? []) if (k.auth_user_id) authByMember.set(k.id, k.auth_user_id);
        }
        const parentId = rows.find((r) => r.relation === "parent")?.member_id;
        const authIds = [...new Set(authByMember.values())];
        const earned = new Map<string, number>();
        const avatars = new Map<string, string | null>();
        if (authIds.length) {
          const { data: bal } = await supabaseAdmin
            .from("earned_balances").select("user_id,earned_min").eq("day", day).in("user_id", authIds);
          for (const b of bal ?? []) earned.set(b.user_id, b.earned_min ?? 0);
        }
        if (parentId) {
          const { data: prof } = await supabaseAdmin.from("profiles").select("id,avatar_url").eq("id", parentId).maybeSingle();
          if (prof) avatars.set(prof.id, (prof as { avatar_url?: string | null }).avatar_url ?? null);
        }

        return json(rows.map((r) => {
          const auth = authByMember.get(r.member_id);
          return {
            ...r,
            steps: Number(r.steps) || 0,
            avatar: r.avatar ?? avatars.get(r.member_id) ?? null,
            earned_min: auth ? earned.get(auth) ?? 0 : 0,
          };
        }));
      },
    },
  },
});
