import type { ReactNode } from "react";
import { BottomNav } from "./BottomNav";

type Props = {
  children: ReactNode;
  hideNav?: boolean;
};

export function AppShell({ children, hideNav }: Props) {
  return (
    <div className="min-h-dvh bg-background text-foreground font-sans">
      <div className="mx-auto w-full max-w-md pb-28">{children}</div>
      {!hideNav && <BottomNav />}
    </div>
  );
}

export function PageHeader({
  eyebrow,
  title,
  trailing,
}: {
  eyebrow?: string;
  title: string;
  trailing?: ReactNode;
}) {
  return (
    <header className="flex items-end justify-between px-6 pb-4 pt-10">
      <div className="space-y-1">
        {eyebrow && (
          <p className="text-sm font-medium text-sage-600">{eyebrow}</p>
        )}
        <h1 className="text-2xl font-semibold tracking-tight text-balance">
          {title}
        </h1>
      </div>
      {trailing}
    </header>
  );
}
