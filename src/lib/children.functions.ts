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
    if (child.auth_user_id) {
      // The linked auth account may have been deleted without clearing this
      // reference (a failed signup rollback). Only block re-issuing when the
      // account genuinely still exists; otherwise clear the ghost link.
      const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
      const { data: authCheck } = await supabaseAdmin.auth.admin.getUserById(child.auth_user_id);
      if (authCheck?.user) throw new Error("This child has already joined — the code cannot be changed.");
      await supabaseAdmin.from("username_reservations").delete().eq("owner_id", child.auth_user_id);
      const { error: clearErr } = await supabaseAdmin
        .from("children")
        .update({ auth_user_id: null, invitation_status: "pending" })
        .eq("id", child.id);
      if (clearErr) throw clearErr;
    }

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

/**
 * Public: a child redeems a parent invitation code. No email/password needed —
 * an account is provisioned automatically and linked to that one child profile.
 * Codes are single-use. Returns credentials so the client can sign in.
 */
export const redeemChildCode = createServerFn({ method: "POST" })
  .inputValidator((d: unknown) => RedeemInput.parse(d))
  .handler(async ({ data }): Promise<{ email: string; password: string }> => {
    const { redeemChildCodeServer } = await import("@/lib/children.server");
    return redeemChildCodeServer(data.code);
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
      // Tolerate a missing auth user: the account may already be gone (ghost
      // reference), and the child profile must still be deletable.
      const code = (delErr as { code?: string } | null)?.code;
      if (delErr && code !== "user_not_found" && !/user not found/i.test(delErr.message)) {
        throw new Error(delErr.message);
      }
    }
    return { ok: true };
  });

const GrantInput = z.object({
  childId: z.string().uuid(),
  minutes: z.number().int().min(1).max(600),
  note: z.string().trim().max(140).optional(),
  // Caller's local calendar day (YYYY-MM-DD); gifted minutes expire at their local midnight.
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

/**
 * Parent-only: gift bonus screen-time minutes to a linked child for today,
 * on top of whatever they earned by walking. The minutes land in the same
 * daily balance the Screen Time bridge reads, so the child's allowance
 * updates immediately.
 */
export const grantScreenTime = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => GrantInput.parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true; bonusMin: number }> => {
    const { supabase, userId } = context;
    const { data: child, error } = await supabase
      .from("children")
      .select("id, parent_id, auth_user_id")
      .eq("id", data.childId)
      .maybeSingle();
    if (error) throw error;
    if (!child || child.parent_id !== userId) throw new Error("Not found");
    const childUserId = child.auth_user_id as string | null;
    if (!childUserId) throw new Error("This child hasn't joined yet.");

    const now = new Date();
    const utcDay = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-${String(now.getUTCDate()).padStart(2, "0")}`;
    // Accept the caller's local day only when it is within one day of UTC now.
    const withinADay = (d: string) =>
      Math.abs(new Date(`${d}T00:00:00Z`).getTime() - new Date(`${utcDay}T00:00:00Z`).getTime()) <= 86_400_000;
    const day = data.day && withinADay(data.day) ? data.day : utcDay;

    const { data: existing, error: readErr } = await supabase
      .from("earned_balances")
      .select("bonus_min")
      .eq("user_id", childUserId)
      .eq("day", day)
      .maybeSingle();
    if (readErr) throw readErr;

    const bonusMin = (existing?.bonus_min ?? 0) + data.minutes;
    if (existing) {
      const { error: upErr } = await supabase
        .from("earned_balances")
        .update({ bonus_min: bonusMin, updated_at: new Date().toISOString() })
        .eq("user_id", childUserId)
        .eq("day", day);
      if (upErr) throw upErr;
    } else {
      const { error: insErr } = await supabase
        .from("earned_balances")
        .insert({ user_id: childUserId, day, bonus_min: bonusMin });
      if (insErr) throw insErr;
    }

    const { error: logErr } = await supabase.from("screentime_grants").insert({
      parent_id: userId,
      child_user_id: childUserId,
      day,
      minutes: data.minutes,
      note: data.note || null,
    });
    if (logErr) throw logErr;

    return { ok: true, bonusMin };
  });
