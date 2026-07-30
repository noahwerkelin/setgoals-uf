import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function randomCode(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  const chars = [...bytes].map((b) => ALPHABET[b % ALPHABET.length]);
  return `${chars.slice(0, 4).join("")}-${chars.slice(4).join("")}`;
}

const DEFAULT_TTL_DAYS = 7;

export type ChildCodeResult = {
  code: string;
  expiresAt: string;
  status: string;
};

/** Parent-only: (re)issue a fresh single-use invitation code for one child profile. */
export const issueChildCode = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ childId: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<ChildCodeResult> => {
    const { supabase, userId } = context;
    const { data: child, error } = await supabase
      .from("children")
      .select("id, parent_id, auth_user_id, invitation_status")
      .eq("id", data.childId)
      .maybeSingle();
    if (error) throw error;
    if (!child || child.parent_id !== userId) throw new Error("Not found");
    if (child.auth_user_id) throw new Error("This child has already joined — the code cannot be changed.");

    const expiresAt = new Date(Date.now() + DEFAULT_TTL_DAYS * 86400_000).toISOString();
    for (let attempt = 0; attempt < 6; attempt++) {
      const code = randomCode();
      const { error: upErr } = await supabase
        .from("children")
        .update({ code, invitation_status: "pending", invitation_expires_at: expiresAt })
        .eq("id", child.id);
      if (!upErr) return { code, expiresAt, status: "pending" };
      if (upErr.code !== "23505") throw upErr;
    }
    throw new Error("Could not generate a unique code, please try again.");
  });

const RedeemInput = z.object({
  code: z
    .string()
    .trim()
    .toUpperCase()
    .transform((s) => s.replace(/[^A-Z0-9]/g, ""))
    .refine((s) => s.length === 8, "Invalid code"),
});

function randomPassword(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(36).padStart(2, "0")).join("");
}

/**
 * Public: a child redeems a parent invitation code. No email/password needed —
 * an account is provisioned automatically and linked to that one child profile.
 * Codes are single-use. Returns credentials so the client can sign in.
 */
export const redeemChildCode = createServerFn({ method: "POST" })
  .inputValidator((d: unknown) => RedeemInput.parse(d))
  .handler(async ({ data }): Promise<{ email: string; password: string }> => {

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const formatted = `${data.code.slice(0, 4)}-${data.code.slice(4)}`;

    const { data: child, error } = await supabaseAdmin
      .from("children")
      .select("id, parent_id, name, username, avatar, birthday, auth_user_id, invitation_status, invitation_expires_at")
      .eq("code", formatted)
      .maybeSingle();
    if (error) throw error;
    if (!child) throw new Error("Invalid invitation code.");
    if (child.auth_user_id || child.invitation_status === "connected") {
      throw new Error("This invitation code has already been used.");
    }
    if (new Date(child.invitation_expires_at as string).getTime() < Date.now()) {
      await supabaseAdmin.from("children").update({ invitation_status: "expired" }).eq("id", child.id);
      throw new Error("This invitation code has expired. Ask your parent for a new one.");
    }

    const email = `child.${child.id}@child.setgoals.app`;
    const password = randomPassword();
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        display_name: child.name,
        avatar_url: child.avatar,
        ...(child.username ? { username: child.username } : {}),
      },
    });

    if (createErr || !created.user) throw new Error(createErr?.message ?? "Could not create the account.");
    const childUserId = created.user.id;

    // Claim the profile atomically: only succeeds while still unclaimed.
    const { data: claimed, error: claimErr } = await supabaseAdmin
      .from("children")
      .update({
        auth_user_id: childUserId,
        invitation_status: "connected",
      })
      .eq("id", child.id)
      .is("auth_user_id", null)
      .select("id")
      .maybeSingle();
    if (claimErr || !claimed) {
      await supabaseAdmin.auth.admin.deleteUser(childUserId);
      throw new Error("This invitation code has already been used.");
    }

    await supabaseAdmin.from("profiles").update({ role: "child" }).eq("id", childUserId);
    await supabaseAdmin.from("parent_child_relationships").insert({
      parent_id: child.parent_id,
      child_profile_id: child.id,
      child_user_id: childUserId,
    });

    return { email, password };
  });

const DeleteInput = z.object({
  childId: z.string().uuid(),
  password: z.string().min(1),
});

/**
 * Parent-only: permanently delete a child profile and, when the child has
 * joined, their auth account (which signs them out everywhere).
 * Requires the parent's password as confirmation.
 */
export const deleteChild = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => DeleteInput.parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true }> => {
    const { supabase, userId, claims } = context;
    const email = (claims as { email?: string }).email;
    if (!email) throw new Error("Password confirmation is not available for this account.");

    // Re-authenticate the parent with a throwaway client (no session persistence).
    const { createClient } = await import("@supabase/supabase-js");
    const key = process.env.SUPABASE_PUBLISHABLE_KEY!;
    const check = createClient(process.env.SUPABASE_URL!, key, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: (input: RequestInfo | URL, init?: RequestInit) => {
          const h = new Headers(init?.headers);
          if (key.startsWith("sb_") && h.get("Authorization") === `Bearer ${key}`) h.delete("Authorization");
          h.set("apikey", key);
          return fetch(input, { ...init, headers: h });
        },
      },
    });
    const { error: pwErr } = await check.auth.signInWithPassword({ email, password: data.password });
    if (pwErr) throw new Error("Incorrect password.");
    await check.auth.signOut();

    const { data: child, error } = await supabase
      .from("children")
      .select("id, parent_id, auth_user_id")
      .eq("id", data.childId)
      .maybeSingle();
    if (error) throw error;
    if (!child || child.parent_id !== userId) throw new Error("Not found");

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const childUserId = child.auth_user_id as string | null;

    if (childUserId) {
      await supabaseAdmin.from("parent_child_relationships").delete().eq("child_user_id", childUserId);
      await supabaseAdmin.from("activity_steps").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("earned_balances").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("streaks").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("restriction_settings").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("user_settings").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("user_roles").delete().eq("user_id", childUserId);
      await supabaseAdmin.from("profiles").delete().eq("id", childUserId);
    }

    await supabaseAdmin.from("children").delete().eq("id", child.id);
    if (childUserId) {
      const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(childUserId);
      if (delErr) throw new Error(delErr.message);
    }
    return { ok: true };
  });
