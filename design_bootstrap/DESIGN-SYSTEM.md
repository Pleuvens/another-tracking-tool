# Media Tracker — Design System

Live references: `Design System.dc.html` (foundations/components), `Screens.dc.html` (page drafts).

## Direction
Light, warm, paper-toned UI. No fixed brand color — every accent/glow comes from each title's poster/backdrop art. Rounded, friendly type. Balanced density (poster-forward, not spreadsheet-dense). French-first copy, EN fallback.

## Color
Neutrals (warm, low-chroma):
- Paper 0: `oklch(98.5% 0.008 75)`
- Paper: `oklch(97% 0.012 75)` — page background
- Paper 2 / card: `oklch(94% 0.014 70)`
- Line: `oklch(88% 0.012 70)`
- Ink soft (secondary text): `oklch(45% 0.02 60)`
- Ink (primary text): `oklch(22% 0.015 60)`

Status hues (only fixed colors in the system — status only, never branding; shared chroma, hue varies):
- Watching: `oklch(70% 0.09 85)`
- Completed: `oklch(65% 0.08 145)`
- Dropped: `oklch(62% 0.09 25)`
- Planned: `oklch(65% 0.06 250)`

Poster-driven accents: dominant color extracted per title, used as ambient glow behind posters, hover highlights, tint on rating chips. Missing/low-quality art → quiet blurred neutral gradient, never a broken image or loud icon.

## Typography
- Headings: Quicksand 600/700
- Body/UI: Nunito Sans 400/700/800
- Labels/eyebrows: Nunito Sans 800, 12px, uppercase, tracked

## Components
Rounded corners (12–20px), generous tap targets, no drop shadows — depth from tone shift, not shadow. Pill buttons/status chips, avatar stacks for "who's watched," star ratings, search field as a pill input.

## Screens drafted
1. **Accueil (Activity feed)** — left sidebar nav (browser-first), chronological household activity, grouped by day.
2. **Fiche titre (Media detail)** — backdrop glow from poster color, status segmented control, my rating, "qui a regardé" list, users' average rating (plain %, no badge chrome).
3. **Recherche (Catalog/search)** — one-tap watched/watchlist actions directly on result rows.
4. **Triage mémoire** — one-card-at-a-time queue, four actions (Vu/Commencé/Prévu/Abandonné) + skip, playful unknown-date copy, suggestion reasons (shared director/actor, household taste) instead of a source toggle.

## Voice
Playful only in the margins (empty states, confirmations) — titles/dates/ratings stay plain. FR and EN land the same tone independently, not literal translations.
