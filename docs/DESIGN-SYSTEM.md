# SetGoals Design System

A copy-paste style guide for reproducing this look in another project (Tailwind v4 + shadcn/ui, `new-york` style, lucide icons).

---

## 1. Typography

**Albert Sans**, weights 400 / 500 / 600 / 700. Load with a `<link>` in the document head — never `@import` a remote URL in `styles.css`.

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Albert+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />
```

Stack: `"Albert Sans", ui-sans-serif, system-ui, sans-serif`
Body: antialiased, `font-feature-settings: "ss01", "cv11"`.

| Role | Classes |
| --- | --- |
| Page title | `text-2xl font-semibold tracking-tight text-balance` |
| Eyebrow above title | `text-sm font-medium text-sage-600` |
| Micro label | `text-[10px] font-medium uppercase tracking-widest` |
| Body / labels | `text-sm`, `text-xs` |
| Stat value | `text-xl font-medium tabular-nums` |

---

## 2. Color scheme

One 9-step ramp (`--sage-*`) drives everything. Semantic tokens only ever point at the ramp, so swapping the ramp reskins the entire app — that is how the theme picker works. All values are `oklch`, deliberately low-chroma for a washed-out feel.

Light semantics: background = sage-50, foreground = sage-950, card = pure white, primary = sage-600, secondary/muted = sage-100, accent = sage-200, border = sage-950 @ 6%, input @ 10%, ring = sage-600, destructive = `oklch(0.6 0.2 25)`.

Alternate ramps (rose, blue, pink, lavender, amber, slate) keep identical lightness/chroma and change only hue.

---

## 3. Shape, elevation, motion

- `--radius: 1rem`. Scale: sm 12 · md 14 · lg 16 · xl 20 · 2xl 24 · 3xl 28 · full.
- **Card:** `rounded-3xl bg-card p-5 shadow-sm ring-1 ring-black/5` — hairline ring, never a hard border.
- **Input:** `w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5`.
- **Floating nav:** `rounded-3xl bg-card/85 p-1.5 ring-1 ring-black/5 backdrop-blur-xl`, shadow `0 10px 30px -10px rgb(0 0 0 / 0.15)`.
- **Entry animation `rise`:** 8px translate + fade, `0.5s cubic-bezier(0.16, 1, 0.3, 1)`. Same easing for ring progress over 1.2s.
- **Ambient aura:** three 30px-blurred full-round blobs in the theme color drifting on 18s / 21s / 24s loops; disabled under `prefers-reduced-motion`.

---

## 4. Buttons

shadcn Button via `cva`:

```ts
const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium cursor-pointer transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 disabled:cursor-not-allowed [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground shadow hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90",
        outline: "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-md px-3 text-xs",
        lg: "h-10 rounded-md px-8",
        icon: "h-9 w-9",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);
```

Hero CTA override (the pill used across the app):
`w-full rounded-full bg-primary py-3.5 text-sm font-semibold text-primary-foreground`

---

## 5. Layout

Mobile-first shell:

```tsx
<div className="min-h-dvh bg-background text-foreground font-sans">
  <div className="mx-auto w-full max-w-md pb-28">{children}</div>
  <BottomNav />
</div>
```

- Page header: `flex items-end justify-between px-6 pb-4 pt-10`.
- Bottom nav: `fixed bottom-5 left-1/2 -translate-x-1/2 w-[calc(100%-32px)] max-w-[360px]`.
- Icons: lucide, `size-5`, `strokeWidth` 1.8 (2.4 when active). Tap targets `min-h-11 min-w-11`.
- Never hardcode colors (`text-white`, `bg-[#...]`) — always use the semantic tokens below.

---

## 6. Drop-in `styles.css` (Tailwind v4)

```css
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

@theme inline {
  --font-sans: "Albert Sans", ui-sans-serif, system-ui, sans-serif;

  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
  --radius-2xl: calc(var(--radius) + 8px);
  --radius-3xl: calc(var(--radius) + 12px);

  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);

  --color-sage-50: var(--sage-50);
  --color-sage-100: var(--sage-100);
  --color-sage-200: var(--sage-200);
  --color-sage-300: var(--sage-300);
  --color-sage-500: var(--sage-500);
  --color-sage-600: var(--sage-600);
  --color-sage-700: var(--sage-700);
  --color-sage-900: var(--sage-900);
  --color-sage-950: var(--sage-950);
}

:root {
  --radius: 1rem;

  /* Default ramp — sage */
  --sage-50:  oklch(0.985 0.005 130);
  --sage-100: oklch(0.965 0.008 130);
  --sage-200: oklch(0.92  0.014 130);
  --sage-300: oklch(0.85  0.022 132);
  --sage-500: oklch(0.66  0.035 140);
  --sage-600: oklch(0.58  0.038 142);
  --sage-700: oklch(0.5   0.04  144);
  --sage-900: oklch(0.3   0.025 145);
  --sage-950: oklch(0.18  0.018 145);
}

/* Alternate ramps: same lightness/chroma, different hue. */
:root[data-theme="rose"] {
  --sage-50: oklch(0.985 0.006 20);  --sage-100: oklch(0.965 0.012 20);
  --sage-200: oklch(0.92 0.022 20);  --sage-300: oklch(0.85 0.034 22);
  --sage-500: oklch(0.66 0.06 22);   --sage-600: oklch(0.58 0.07 24);
  --sage-700: oklch(0.5 0.072 26);   --sage-900: oklch(0.3 0.04 26);
  --sage-950: oklch(0.18 0.028 26);
}
:root[data-theme="blue"] {
  --sage-50: oklch(0.985 0.006 240); --sage-100: oklch(0.965 0.012 240);
  --sage-200: oklch(0.92 0.024 240); --sage-300: oklch(0.85 0.038 242);
  --sage-500: oklch(0.66 0.06 245);  --sage-600: oklch(0.58 0.07 248);
  --sage-700: oklch(0.5 0.07 250);   --sage-900: oklch(0.3 0.04 250);
  --sage-950: oklch(0.18 0.028 250);
}
:root[data-theme="pink"] {
  --sage-50: oklch(0.985 0.006 350); --sage-100: oklch(0.965 0.012 350);
  --sage-200: oklch(0.92 0.024 350); --sage-300: oklch(0.85 0.036 350);
  --sage-500: oklch(0.66 0.06 350);  --sage-600: oklch(0.58 0.07 350);
  --sage-700: oklch(0.5 0.072 350);  --sage-900: oklch(0.3 0.04 350);
  --sage-950: oklch(0.18 0.028 350);
}
:root[data-theme="lavender"] {
  --sage-50: oklch(0.985 0.006 295); --sage-100: oklch(0.965 0.012 295);
  --sage-200: oklch(0.92 0.024 295); --sage-300: oklch(0.85 0.036 295);
  --sage-500: oklch(0.66 0.06 295);  --sage-600: oklch(0.58 0.068 295);
  --sage-700: oklch(0.5 0.07 295);   --sage-900: oklch(0.3 0.04 295);
  --sage-950: oklch(0.18 0.028 295);
}
:root[data-theme="amber"] {
  --sage-50: oklch(0.985 0.006 80);  --sage-100: oklch(0.965 0.014 80);
  --sage-200: oklch(0.92 0.028 78);  --sage-300: oklch(0.85 0.042 76);
  --sage-500: oklch(0.66 0.07 74);   --sage-600: oklch(0.58 0.078 72);
  --sage-700: oklch(0.5 0.078 70);   --sage-900: oklch(0.3 0.045 70);
  --sage-950: oklch(0.18 0.03 70);
}
:root[data-theme="slate"] {
  --sage-50: oklch(0.985 0.003 250); --sage-100: oklch(0.965 0.006 250);
  --sage-200: oklch(0.92 0.01 250);  --sage-300: oklch(0.85 0.015 250);
  --sage-500: oklch(0.66 0.022 250); --sage-600: oklch(0.58 0.025 250);
  --sage-700: oklch(0.5 0.028 250);  --sage-900: oklch(0.3 0.02 250);
  --sage-950: oklch(0.18 0.014 250);
}

:root {
  --background: var(--sage-50);
  --foreground: var(--sage-950);
  --card: oklch(1 0 0);
  --card-foreground: var(--sage-950);
  --popover: oklch(1 0 0);
  --popover-foreground: var(--sage-950);
  --primary: var(--sage-600);
  --primary-foreground: oklch(0.99 0 0);
  --secondary: var(--sage-100);
  --secondary-foreground: var(--sage-900);
  --muted: var(--sage-100);
  --muted-foreground: var(--sage-600);
  --accent: var(--sage-200);
  --accent-foreground: var(--sage-900);
  --destructive: oklch(0.6 0.2 25);
  --destructive-foreground: oklch(0.99 0 0);
  --border: oklch(0.18 0.018 145 / 0.06);
  --input: oklch(0.18 0.018 145 / 0.1);
  --ring: var(--sage-600);
}

.dark {
  --background: var(--sage-950);
  --foreground: var(--sage-50);
  --card: oklch(0.22 0.018 145);
  --card-foreground: var(--sage-50);
  --popover: oklch(0.22 0.018 145);
  --popover-foreground: var(--sage-50);
  --primary: var(--sage-500);
  --primary-foreground: var(--sage-950);
  --secondary: oklch(0.26 0.02 145);
  --secondary-foreground: var(--sage-50);
  --muted: oklch(0.26 0.02 145);
  --muted-foreground: oklch(0.7 0.025 142);
  --accent: oklch(0.3 0.025 145);
  --accent-foreground: var(--sage-50);
  --border: oklch(1 0 0 / 0.08);
  --input: oklch(1 0 0 / 0.12);
  --ring: var(--sage-500);
}

@layer base {
  * { border-color: var(--color-border); }
  html, body {
    background-color: var(--color-background);
    color: var(--color-foreground);
    -webkit-font-smoothing: antialiased;
    font-feature-settings: "ss01", "cv11";
  }
}

@keyframes ring-draw {
  from { stroke-dashoffset: var(--from, 999); }
  to   { stroke-dashoffset: var(--to, 0); }
}
.animate-ring-draw { animation: ring-draw 1.2s cubic-bezier(0.16, 1, 0.3, 1) both; }

@keyframes rise {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.animate-rise { animation: rise 0.5s cubic-bezier(0.16, 1, 0.3, 1) both; }

@keyframes aura-drift-a {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
  50%      { transform: translate3d(14%, 10%, 0) scale(1.18); }
}
@keyframes aura-drift-b {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1.1); }
  50%      { transform: translate3d(-16%, -12%, 0) scale(0.92); }
}
@keyframes aura-drift-c {
  0%, 100% { transform: translate3d(0, 0, 0) scale(0.95); }
  50%      { transform: translate3d(10%, -14%, 0) scale(1.25); }
}
.aura-blob { position: absolute; border-radius: 9999px; filter: blur(30px); will-change: transform; }
.aura-a { animation: aura-drift-a 18s ease-in-out infinite; }
.aura-b { animation: aura-drift-b 24s ease-in-out infinite; }
.aura-c { animation: aura-drift-c 21s ease-in-out infinite; }

@media (prefers-reduced-motion: reduce) {
  .aura-a, .aura-b, .aura-c { animation: none; }
}
```

Switch themes at runtime with `document.documentElement.dataset.theme = "blue"`.

---

## 7. Checklist for a new project

1. Add the Albert Sans `<link>` to the head.
2. Paste section 6 into `src/styles.css`.
3. Install shadcn (`new-york`, base color slate, CSS variables) and paste the button `cva` from section 4.
4. Use only semantic tokens (`bg-card`, `text-muted-foreground`, `ring-black/5`) in components.
5. Reach for `rounded-3xl` cards, pill CTAs, and `animate-rise` on page entry.
