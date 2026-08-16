# Design brief: self-hosted movie/TV tracker

## What this is
An open-source, self-hosted alternative to Yamtrack/Trakt, built for a small household of Plex users (a handful of people, not a public product). The stated design mission: **fix the UX that every tracker in this space gets wrong** — importing years of past watch history, and quickly logging what you watch without fighting a form. Speed and low friction are the core design values, more than visual flair.

## Audience
- French-first, English fallback — all copy/UI text should read naturally as French-primary with an EN toggle, not translated-from-English filler
- A handful of named users (household + close friends), not a public audience — login-gated, invite-only, no marketing/landing-page needed
- Everyone's watch history and ratings are visible to everyone on the instance — this is a shared household tool, not a private diary

## Core data shown on screen
- Movies and TV shows (anime included as ordinary rows, no separate category or badge)
- Per title: poster, French title/synopsis (falls back to English if no French translation exists), status per user (watching / completed / dropped / planned), 0–5 or 0–10 rating, watched date
- Aggregate household rating per title (average across the handful of users)
- Per-title "who's watched this and what did they think" — a short list of avatars/names + their rating
- Source tag per watch entry (synced from Plex vs manually logged vs imported) — subtle, not a badge that clutters the card

## Screens to design

1. **Activity feed (home screen)** — recent watches across all household members, chronological, poster-forward. This is what people land on. Should feel alive/social in a small-group way, not like a corporate dashboard.

2. **Media detail page** — poster/backdrop, French synopsis with EN fallback, my status/rating controls front and center, "who else watched this" list, household average rating.

3. **Catalog / search** — search across the shared catalog, results show poster + title + a quick one-tap "mark as watched" / "add to watchlist" action directly from the result card, no need to open the detail page just to log something.

4. **Bulk import / backfill flow** — this is the flagship screen, deserves the most design attention. Two paths from one entry point:
   - **File import**: upload Letterboxd CSV or MyAnimeList XML, show a progress/preview list of matched titles before committing
   - **Manual bulk-log**: a fast search-and-multi-select interface — type a title, tap multiple matching results, bulk-assign "watched" with an optional rough date/year, confirm in one action. The design goal: logging 20 remembered titles should take under a minute, not 20 separate form submissions.

5. **My list / watchlist** — separate from the activity feed (planned-to-watch, not yet-watched), grid of posters, simple status filter.

6. **Login / invite acceptance** — minimal, invite-code or invite-link based, no public signup form.

7. **Account settings** — link Plex account (for auto-sync), toggle EN/FR display language, manage password.

## Tone / visual direction
- Warm and personal, not a corporate streaming-service clone (avoid looking like a Netflix/Trakt reskin)
- Poster-forward, image-heavy — this is a visual medium, don't bury it in text-first UI
- Fast and low-chrome: minimal nav, generous tap targets, mobile-first (people will log things from their phone right after watching)
- Confidence in whitespace and typography over dense data tables — this app's whole pitch is *not* feeling like a spreadsheet with a UI on top, which is the usual failure mode in this space

## Voice & microcopy: soft and playful
Personality lives in the small, low-stakes moments — empty states, confirmations, status labels, placeholders. It should never get in the way of clarity for the actual data (titles, ratings, dates stay plain and legible). French and English copy should each land the same tone in their own language, not be a literal translation of each other.

Examples to design around:
- Unknown watch date: "Sometime, who's counting" / FR: "Un jour, dans le passé"
- Empty triage queue: "All caught up. Suspiciously caught up." / FR: "Tout est vu. Ça sent le mensonge."
- Empty watchlist: "Nothing planned yet — go feed it some ideas" / FR: "Rien de prévu — va lui trouver des idées"
- Import finished: "47 titles rescued from oblivion" / FR: "47 titres sauvés de l'oubli"
- Discarded status label: "Life's too short" / FR: "Pas le temps"

## Additional screen: memory triage (backfill from memory, no export file)
A single-card, one-at-a-time queue for logging history that exists only in someone's memory — the counterpart to the file-based import flow above, for people who never used Letterboxd/MAL/TV Time at all.

- One title per card (poster, title, year), four actions: **Seen** (completed), **Plan to** (planned), **Started it** (watching), **Discarded** (dropped) — plus an implicit skip/defer that just advances the queue without writing anything.
- Candidate source is switchable: "From my library" (anything in Plex/*arr with no watch entry yet — highest-confidence prompts) vs "Browse by decade/genre" (broader TMDB catalog, for jogging memory on things never owned locally).
- Interaction should feel like a fast tap-through loop, not a form — this is the same low-friction principle as the bulk-log flow, applied to passive discovery instead of active search.
- Watched date on this screen defaults to unknown/null — the playful placeholder copy above is the primary UI for this, not an edge case to hide.

## Explicitly out of scope for this design pass
- Any anime-specific UI treatment (there isn't one — anime is just a movie or TV row)
- Public/marketing pages
- Admin panel beyond basic invite management
