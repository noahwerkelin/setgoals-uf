# SetGoals Design System Reference

Create `docs/DESIGN-SYSTEM.md` — a single copy-paste style guide you can drop into any new project to reproduce this exact look. Below is the content it will contain.

## Typography

- Font: **Albert Sans** (weights 400/500/600/700), loaded via `<link>` to Google Fonts, never a CSS `@import`.
- Stack: `"Albert Sans", ui-sans-serif, system-ui, sans-serif`
- Font features: `font-feature-settings: "ss01", "cv11"`, antialiased.
- Scale in use: page title `text-2xl font-semibold tracking-tight`, eyebrow `text-sm font-medium` in sage-600, labels `text-xs`, micro-labels `text-[10px] uppercase tracking-widest`, stat values `text-xl font-medium tabular-nums`.

## Color scheme

One 9-step "sage" ramp drives everything; semantic tokens point at it, so swapping the ramp reskins the whole app (that is how the PRO theme picker works).

```css
--sage-50:  oklch(0.985 0.005 130);
--sage-100: oklch(0.965 0.008 130);
--sage-200: oklch(0.92  0.014 130);
--sage-300: oklch(0.85  0.022 132);
--sage-500: oklch(0.66  0.035 140);
--sage-600: oklch(0.58  0.038 142);
--sage-700: oklch(0.5   0.04  144);
--sage-900: oklch(0.3   0.025 145);
--sage-950: oklch(0.18  0.018 145);
```

Semantic mapping (light): background = sage-50, foreground = sage-950, card = pure white, primary = sage-600, primary-foreground = near-white, muted/secondary = sage-100, accent = sage-200, border = `sage-950 / 6%`, input = `/10%`, ring = sage-600, destructive = `oklch(0.6 0.2 25)`.
Dark mode: background sage-950, card `oklch(0.22 0.018 145)`, primary sage-500, borders `white/8%`.

Alternate ramps (rose, blue, pink, lavender, amber, slate) keep the same lightness/chroma and only change hue — that is the trick behind the washed-out palette.

## Shape, elevation, motion

- `--radius: 1rem`; scale runs sm 12 / md 14 / lg 16 / xl 20 / 2xl 24 / 3xl 28 / full.
- Cards: `rounded-3xl bg-card p-5 ring-1 ring-black/5 shadow-sm` — hairline ring instead of a hard border.
- Floating nav: `rounded-3xl bg-card/85 backdrop-blur-xl ring-1 ring-black/5`, shadow `0 10px 30px -10px rgb(0 0 0 / 0.15)`.
- Entry animation `rise`: 8px translate + fade, `0.5s cubic-bezier(0.16, 1, 0.3, 1)`; ring progress uses the same easing over 1.2s.
- Ambient "aura": 3 blurred (30px) full-round blobs of the theme color drifting on 18/21/24s loops, disabled under `prefers-reduced-motion`.

## Buttons

shadcn `new-york` Button via `cva`. Base: `inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium transition-colors focus-visible:ring-1 focus-visible:ring-ring disabled:opacity-50`.
Variants: default (`bg-primary text-primary-foreground shadow hover:bg-primary/90`), destructive, outline (`border border-input bg-background`), secondary, ghost, link.
Sizes: default h-9 px-4 · sm h-8 px-3 text-xs · lg h-10 px-8 · icon 9x9.
The app's hero CTA overrides this to a pill: `rounded-full bg-primary py-3.5 text-sm font-semibold text-primary-foreground w-full`.

## Layout

Mobile-first: `min-h-dvh bg-background`, content centered in `max-w-md` with `pb-28`, page header `px-6 pt-10 pb-4`, fixed pill nav 20px from the bottom, max width 360px. Icons: lucide, `size-5`, stroke 1.8 (2.4 when active).

## Deliverable

`docs/DESIGN-SYSTEM.md` containing the above plus a ready-to-paste Tailwind v4 `styles.css` block (`@theme inline` token mapping + `:root` ramps + keyframes) and the `button.tsx` cva snippet, so a new project reaches visual parity by copying two files.
