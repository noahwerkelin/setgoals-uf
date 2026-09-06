import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

/**
 * Hard-deletes an account (and, for parents, every linked child account) or a
 * single child profile. Callable from the web app and the iOS app with the
 * signed-in user's bearer token plus their password as confirmation.
 */

const Input = z.object({
  password: z.string().min(1),
  childId: z.string().uuid().optional(),
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Removes every row a user owns, then their auth account. */
async function purgeUser(admin: any, userId: string) {
  await admin.from("parent_child_relationships").delete().eq("child_user_id", userId);
  await admin.from("parent_child_relationships").delete().eq("parent_id", userId);
  await admin.from("screentime_grants").delete().eq("child_user_id", userId);
  await admin.from("screentime_grants").delete().eq("parent_id", userId);
  await admin.from("task_notifications").delete().eq("user_id", userId);
  await admin.from("tasks").delete().eq("parent_id", userId);
  await admin.from("tasks").delete().eq("child_user_id", userId);
  await admin.from("activity_steps").delete().eq("user_id", userId);
  await admin.from("earned_balances").delete().eq("user_id", userId);
  await admin.from("streaks").delete().eq("user_id", userId);
  await admin.from("restriction_settings").delete().eq("user_id", userId);
  await admin.from("user_badges").delete().eq("user_id", userId);
  await admin.from("friendships").delete().eq("user_id", userId);
  await admin.from("friendships").delete().eq("friend_id", userId);
  await admin.from("subscriptions").delete().eq("user_id", userId);
  await admin.from("data_export_requests").delete().eq("user_id", userId);
  await admin.from("account_deletion_requests").delete().eq("user_id", userId);
  await admin.from("user_settings").delete().eq("user_id", userId);
  await admin.from("user_roles").delete().eq("user_id", userId);
  await admin.from("profiles").delete().eq("id", userId);
  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) throw new Error(error.message);
}

/** Deletes one child profile plus, when they joined, their auth account. */
async function purgeChild(admin: any, child: { id: string; auth_user_id: string | null }) {
  await admin.from("tasks").delete().eq("child_id", child.id);
  if (child.auth_user_id) await purgeUser(admin, child.auth_user_id);
  await admin.from("children").delete().eq("id", child.id);
}

export const Route = createFileRoute("/api/public/delete-account")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
        if (!token) return json({ error: "Unauthorized" }, 401);

        let input: z.infer<typeof Input>;
        try {
          input = Input.parse(await request.json());
        } catch {
          return json({ error: "Invalid request" }, 400);
        }

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
        const user = userRes?.user;
        if (userErr || !user?.email) return json({ error: "Unauthorized" }, 401);

        // Password confirmation.
        const { error: pwErr } = await anon.auth.signInWithPassword({
          email: user.email,
          password: input.password,
        });
        if (pwErr) return json({ error: "wrong_password" }, 403);
        await anon.auth.signOut();

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

        try {
          if (input.childId) {
            const { data: child } = await supabaseAdmin
              .from("children")
              .select("id, parent_id, auth_user_id")
              .eq("id", input.childId)
              .maybeSingle();
            if (!child || child.parent_id !== user.id) return json({ error: "Not found" }, 404);
            await purgeChild(supabaseAdmin, child as any);
            return json({ ok: true });
          }

          const { data: children } = await supabaseAdmin
            .from("children")
            .select("id, auth_user_id")
            .eq("parent_id", user.id);
          for (const c of children ?? []) await purgeChild(supabaseAdmin, c as any);
          await purgeUser(supabaseAdmin, user.id);
          return json({ ok: true });
        } catch (e) {
          return json({ error: e instanceof Error ? e.message : "Deletion failed" }, 500);
        }
      },
    },
  },
});
