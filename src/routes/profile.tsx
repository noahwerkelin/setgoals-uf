import { createFileRoute, Link } from "@tanstack/react-router";
import { ChevronRight, Settings, BarChart3, Gift, Users, Shield } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/profile")({
  head: () => ({
    meta: [
      { title: "Profile — SetGoals UF" },
      { name: "description", content: "Your profile, stats, and account." },
    ],
  }),
  component: Page,
});

function Page() {
  return (
    <AppShell>
      <PageHeader title="Profile" />
      <div className="px-6 space-y-6">
        <section className="flex items-center gap-4 rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise">
          <span className="grid size-14 place-items-center rounded-full bg-sage-200 text-sm font-semibold uppercase tracking-widest text-sage-700">
            LU
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-base font-semibold">Lukas Andersson</p>
            <p className="text-xs text-sage-600">Age group · Teen · Joined Oct 2024</p>
          </div>
          <Link to="/settings" aria-label="Settings" className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">
            <Settings className="size-4" />
          </Link>
        </section>

        <section className="grid grid-cols-3 gap-3 animate-rise" style={{ animationDelay: "60ms" }}>
          <Mini label="Steps · 30d" value="184k" />
          <Mini label="Earned" value="42h" />
          <Mini label="Streak" value="7d" />
        </section>

        <nav className="space-y-2 animate-rise" style={{ animationDelay: "120ms" }}>
          <Row to="/stats" icon={<BarChart3 className="size-4" />} label="Statistics" subtitle="Trends, charts, and history" />
          <Row to="/rewards" icon={<Gift className="size-4" />} label="Rewards" subtitle="Discounts, partner offers, avatars" />
          <Row to="/leaderboards" icon={<Users className="size-4" />} label="Leaderboards" subtitle="Friends, local, national" />
          <Row to="/parent" icon={<Shield className="size-4" />} label="Parent mode" subtitle="Approve apps and set limits" />
          <Row to="/settings" icon={<Settings className="size-4" />} label="Settings" subtitle="Notifications, integrations, account" />
        </nav>
      </div>
    </AppShell>
  );
}

function Mini({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-card p-3 text-center ring-1 ring-black/5">
      <p className="text-base font-semibold tabular-nums">{value}</p>
      <p className="mt-0.5 text-[10px] font-medium uppercase tracking-wider text-sage-600">{label}</p>
    </div>
  );
}

function Row({
  to,
  icon,
  label,
  subtitle,
}: {
  to: string;
  icon: React.ReactNode;
  label: string;
  subtitle: string;
}) {
  return (
    <Link
      to={to}
      className="flex items-center gap-4 rounded-2xl bg-card p-4 ring-1 ring-black/5"
    >
      <span className="grid size-9 place-items-center rounded-xl bg-sage-100 text-sage-700">{icon}</span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{label}</p>
        <p className="text-xs text-sage-600">{subtitle}</p>
      </div>
      <ChevronRight className="size-4 text-sage-600" />
    </Link>
  );
}
