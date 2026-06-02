import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Sign in — SetGoals UF" },
      { name: "description", content: "Sign in or create an account." },
    ],
  }),
  component: Page,
});

function Page() {
  const [mode, setMode] = useState<"signin" | "signup">("signin");
  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-6 pb-10 pt-16">
        <div className="space-y-2 animate-rise">
          <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
            SetGoals UF
          </span>
          <h1 className="text-3xl font-semibold tracking-tight">
            {mode === "signin" ? "Welcome back" : "Create your account"}
          </h1>
          <p className="text-sm text-sage-600">
            {mode === "signin" ? "Sign in to continue earning." : "Start earning screen time today."}
          </p>
        </div>

        <form
          className="mt-8 space-y-3 animate-rise"
          style={{ animationDelay: "80ms" }}
          onSubmit={(e) => {
            e.preventDefault();
            window.location.href = "/";
          }}
        >
          <label className="block">
            <span className="sr-only">Email</span>
            <input
              type="email"
              required
              placeholder="Email"
              className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none placeholder:text-sage-600 focus:ring-sage-600"
            />
          </label>
          <label className="block">
            <span className="sr-only">Password</span>
            <input
              type="password"
              required
              placeholder="Password"
              className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none placeholder:text-sage-600 focus:ring-sage-600"
            />
          </label>
          <button
            type="submit"
            className="w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground"
          >
            {mode === "signin" ? "Sign in" : "Create account"}
          </button>
        </form>

        <div className="my-6 flex items-center gap-3 text-[11px] font-medium uppercase tracking-widest text-sage-600">
          <span className="h-px flex-1 bg-sage-200" /> or <span className="h-px flex-1 bg-sage-200" />
        </div>

        <div className="space-y-2">
          <button className="w-full rounded-full bg-card py-3 text-sm font-semibold text-sage-900 ring-1 ring-black/5">
            Continue with Google
          </button>
          <button className="w-full rounded-full bg-sage-950 py-3 text-sm font-semibold text-sage-50">
            Continue with Apple
          </button>
        </div>

        <button
          onClick={() => setMode(mode === "signin" ? "signup" : "signin")}
          className="mt-8 text-center text-xs font-medium text-sage-600"
        >
          {mode === "signin" ? "New here? Create an account" : "Already have an account? Sign in"}
        </button>

        <Link to="/" className="mt-3 text-center text-[11px] text-sage-600">
          Continue as guest
        </Link>
      </div>
    </div>
  );
}
