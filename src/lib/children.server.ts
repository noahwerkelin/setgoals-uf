// Server-only: shared by the web server function and the iOS public route.
function randomPassword(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(36).padStart(2, "0")).join("");
}

/** Redeems an 8-character (already normalised) child invitation code. */
export async function redeemChildCodeServer(code: string): Promise<{ email: string; password: string }> {

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const formatted = `${code.slice(0, 4)}-${code.slice(4)}`;

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
        child_profile_id: child.id,
        display_name: child.name,
        avatar_url: child.avatar,
        ...(child.username ? { username: child.username } : {}),
      },
    });

    if (createErr || !created.user) throw new Error(createErr?.message ?? "Could not create the account.");
    const childUserId = created.user.id;

    // The signup trigger already links auth_user_id while the account is
    // created. Confirm that link (or claim it if still empty) and mark connected.
    const { data: linked, error: linkReadErr } = await supabaseAdmin
      .from("children")
      .select("auth_user_id")
      .eq("id", child.id)
      .maybeSingle();
    let ok = !linkReadErr && !!linked && (linked.auth_user_id === childUserId || linked.auth_user_id === null);
    if (ok) {
      const { error: claimErr } = await supabaseAdmin
        .from("children")
        .update({ auth_user_id: childUserId, invitation_status: "connected" })
        .eq("id", child.id);
      if (claimErr) {
        console.error("redeemChildCode: claim failed", claimErr);
        ok = false;
      }
    }
    if (!ok) {
      console.error("redeemChildCode: link mismatch", { linkReadErr, linked, childUserId });
      // Undo cleanly so the code stays usable: drop the reservation move, the
      // ghost link, and the half-created account.
      await supabaseAdmin.from("username_reservations").update({ owner_id: child.id }).eq("owner_id", childUserId);
      await supabaseAdmin
        .from("children")
        .update({ auth_user_id: null, invitation_status: "pending" })
        .eq("id", child.id)
        .eq("auth_user_id", childUserId);
      await supabaseAdmin.auth.admin.deleteUser(childUserId);
      throw new Error("Could not join with this code. Please try again.");
    }

    await supabaseAdmin.from("profiles").update({ role: "child" }).eq("id", childUserId);
    await supabaseAdmin.from("parent_child_relationships").insert({
      parent_id: child.parent_id,
      child_profile_id: child.id,
      child_user_id: childUserId,
    });

    return { email, password };
  }
