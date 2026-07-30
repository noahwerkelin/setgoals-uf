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
  email: z.string().trim().email().max(255),
  password: z.string().min(8).max(72),
});

/**
 * Public: a child redeems a parent invitation code and gets an auth account
 * permanently linked to that one child profile. Codes are single-use.
 */
export const redeemChildCode = createServerFn({ method: "POST" })
  .inputValidator((d: unknown) => RedeemInput.parse(d))
  .handler(async ({ data }): Promise<{ ok: true }> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const formatted = `${data.code.slice(0, 4)}-${data.code.slice(4)}`;

    const { data: child, error } = await supabaseAdmin
      .from("children")
      .select("id, parent_id, name, avatar, birthday, auth_user_id, invitation_status, invitation_expires_at")
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

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email: data.email,
      password: data.password,
      email_confirm: true,
      user_metadata: { display_name: child.name, avatar_url: child.avatar },
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

    return { ok: true };
  });
