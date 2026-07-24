# séance

A dark, editorial meditation app built in Flutter — a faithful, fully working
implementation of the *séance* concept design.

## Features

- **Sign-in gate** — a full-bleed login with **Continue with Google** and four
  social-handle options (Apple, Facebook, X, Instagram). Sessions persist across
  launches via `shared_preferences`; the Profile tab signs out.
- **Real-world reading, with the template kept** — the Library tab's *Readings*
  view pulls live passages from the open Wikipedia API and lists them above the
  bundled, curated template set, so it always has content (and degrades to the
  template offline). Pull-to-refresh re-fetches. Tap a piece for a full reader.
- **Hymns from around the world** — the Library tab's *Hymns* view ships a
  bundled, public-domain hymn library (Methodist/Wesley, Presbyterian/Reformed,
  global & ecumenical, and metrical psalms). Filter by tradition, search by
  title/first line/author, and open a hymn for verse-by-verse text with tune,
  meter, scripture and hymnal references.
- **Saved** collects bookmarked readings *and* hymns in labeled sections.

- **Brand header** — `séance` wordmark (Playfair Display), centered date strip
  with activity dots, a `TODAY` pill, and a `WEEKS` button.
- **Date navigation** — tap any day (13–19) to view that day's schedule; the
  selected day expands into a pill, today shows `TODAY`, completed days show a dot.
- **Time-grouped timeline** — Morning / Day / Evening / Night sections, each with
  its time range and a mix of expanded cards (image + copy) and compact cards.
- **Completion toggles** — tap a card or its status ring to mark a practice done.
  A solid ring + check means done; an animated dotted ring means pending.
- **Hero week card** — grayscale portrait, time-aware greeting
  (morning/afternoon/evening), `WELCOME • 2 MIN` intro pill, and the active week
  title. Tap to begin.
- **WEEKS panel** — a programme sheet listing every week; select one to swap the
  hero, with locked weeks gated.
- **Navigation rail** — Today / Journey / Library / Saved / Profile. Journey lists
  the programme; Profile shows live stats (sessions, active days, current week).
- **Responsive** — two-column layout (side rail + timeline + hero) on wide
  screens, a stacked layout with a bottom nav bar on phones.

## Architecture

- `lib/theme.dart` — palette + typography.
- `lib/models.dart` — `Session` / `DayPart` / `DaySchedule` / `WeekInfo` and the
  `AppState` (`ChangeNotifier`, no external deps) holding seed data + interactions.
- `lib/widgets/` — `top_bar`, `side_nav`, `session_card`, `timeline`, `hero_card`,
  `weeks_panel`, `tab_views`.
- `lib/main.dart` — theme, backdrop vignette, and the responsive layout.

Fonts (Playfair Display, Inter) and imagery are bundled under `assets/` so the app
renders identically offline.

## Run

```sh
flutter pub get
flutter run -d macos      # best for the wide two-column layout
flutter run               # any connected device / simulator
flutter test              # widget tests
```
# seance
