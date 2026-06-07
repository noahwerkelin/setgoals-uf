import { useEffect, type ReactNode } from "react";
import { useNavigate, useRouterState } from "@tanstack/react-router";
import { useAuth } from "./auth";

const PUBLIC_PATHS = ["/auth", "/reset-password", "/onboarding"];

export function AuthGate({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const path = useRouterState({ select: (s) => s.location.pathname });

  const isPublic = PUBLIC_PATHS.some((p) => path === p || path.startsWith(p + "/"));

  useEffect(() => {
    if (loading) return;
    if (!user && !isPublic) {
      navigate({ to: "/auth", replace: true });
    }
  }, [user, loading, isPublic, navigate]);

  if (loading && !isPublic) {
    return (
      <div className="grid min-h-dvh place-items-center bg-background text-sm text-sage-600">
        Loading…
      </div>
    );
  }
  if (!user && !isPublic) return null;
  return <>{children}</>;
}
