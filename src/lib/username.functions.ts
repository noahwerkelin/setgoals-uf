import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { normalizeUsername, validUsername } from "./username";

const Input = z.object({ username: z.string().min(1).max(40) });

/**
 * Checks whether a username is free across both regular accounts and child
 * profiles. Case-insensitive. Uses the service-role client because the
 * underlying DB function is not exposed to anon/authenticated roles.
 */
export const isUsernameAvailable = createServerFn({ method: "POST" })
  .inputValidator((d: unknown) => Input.parse(d))
  .handler(async ({ data }): Promise<boolean> => {
    const clean = normalizeUsername(data.username);
    if (!validUsername(clean)) return false;
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: ok, error } = await supabaseAdmin.rpc("username_available", { _username: clean });
    if (error) throw error;
    return ok === true;
  });
