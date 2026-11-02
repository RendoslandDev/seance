# séance

A dark, editorial meditation app built in Flutter — a faithful, fully working
implementation of the *séance* concept design.

## Features

- **Sign in with your phone number** — the only thing a member gives is their
  phone number (Ghana +233 by default; other countries selectable, or type a
  full +number). Firebase texts a 6-digit code; confirming it signs the member
  in, or creates their account the first time — sign-up and sign-in are the
  same step. Android can read the code automatically. Progress, bookmarks and
  journal entries live in Cloud Firestore and stream in real time, so every
  device signed in with that number stays in step. Builds without Firebase
  config skip sign-in and keep data on the device (for development only).
- **Real calendar** — the date strip is the current Monday–Sunday week, rolls
  over at midnight, and future days can't be marked done. Programme weeks
  unlock one per seven days from the member's first visit. Profile shows
  all-time sessions, active days, current streak and saved items.
- **Real-world reading, with the template kept** — the Library tab's *Readings*
  view pulls live passages from the open Wikipedia API (a fresh set of topics
  every day) and lists them above the
  bundled, curated template set, so it always has content (and degrades to the
  template offline). Pull-to-refresh re-fetches. Tap a piece for a full reader.
- **The Bible** — a Bible tab with the complete **King James Version** and
  **World English Bible** (both public domain, bundled so they work offline).
  Pick any book and chapter, type a reference (`John 3:16`, `ps 23`) to jump
  there, or search every verse for a phrase. The last place read is remembered.
  Data is built by `tool/build_bible.py` from eBible.org's texts.
- **Watch** — the Bible tab's second view: the latest teaching, Bible-study and
  debate/apologetics videos from YouTube channels listed in
  `functions/channels.json` (BibleProject, Ligonier, Desiring God, Mike Winger,
  Wes Huff, Testify, Premier Unbelievable?, Reasonable Faith, Cross Examined,
  InspiringPhilosophy). Videos play in-app. Native apps read the channels'
  public feeds directly; the web app reads them through the `videos` Cloud
  Function (see below). A bundled snapshot covers offline use.
- **The complete Wesley hymn book** — the Library tab's *Hymns* view opens on
  John Wesley's *Collection of Hymns for the Use of the People Called
  Methodists* (1876 edition): all 1,026 hymns in book order under their parts
  and sections, searchable by number or any words in the text. The data
  (`assets/data/wesley_1876.json`) is built by `tool/build_wesley_hymns.py` from
  the public-domain CCEL edition.
- **Hymns from around the world** — a second book in the *Hymns* view, a
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

## Privacy, terms and accounts

- **Privacy Policy** and **Terms of Service** live in `assets/legal/*.md`. The
  app shows them in-app (Profile, and the sign-in screen's consent line) and
  `tool/build_legal.py` publishes them as `web/privacy.html` and
  `web/terms.html` for the website and store listings.
- **Profile → Delete account** permanently erases a member's progress,
  bookmarks and journal from Firestore and removes their sign-in account, as
  the App Store and Play Store require.

**Going live: see [LAUNCH.md](LAUNCH.md)** for the step-by-step checklist
(Firebase, website, App Store, Google Play).

## Deploying to the web

The web build is hosted on Firebase Hosting, alongside Auth and Firestore.

1. **Create a Firebase project** at <https://console.firebase.google.com> on the
   **Blaze (pay-as-you-go)** plan, which Cloud Functions require. The live video
   feed is one function call per 15 minutes thanks to CDN caching, so it stays
   well inside the free allowance. Then:
   - *Build → Authentication → Sign-in method*: enable **Phone**.
   - *Authentication → Settings → SMS region policy*: allow the countries you
     serve (at least **Ghana**). SMS is billed per message by Firebase /
     Identity Platform; check current pricing for your regions.
   - Optional: *Sign-in method → Phone → Phone numbers for testing* lets you
     add fake numbers with fixed codes for trying the flow without sending SMS.
   - *Build → Firestore Database*: create a database (production mode).
   - *Project settings → Your apps*: add a **Web** app and copy its config.
2. **Add the config**: `cp config/firebase.example.json config/firebase.json`
   and fill in the values (`config/firebase.json` is git-ignored). Firebase
   web keys are public identifiers; access is enforced by `firestore.rules`.
3. **Install the CLI once**: `npm install -g firebase-tools`, then
   `firebase login` and `firebase use --add` (pick your project).
4. **Deploy**: `./scripts/deploy_web.sh` — runs the tests, builds
   `build/web` with your config, and deploys Hosting, the `videos` function
   (served at `/api/videos`) and the Firestore security rules. The site is served at `https://<project-id>.web.app`.
5. **Custom domain (optional)**: *Hosting → Add custom domain*, then add that
   domain under *Authentication → Settings → Authorized domains* so phone
   sign-in (and its reCAPTCHA check) works there.

To run locally with accounts enabled:
`flutter run -d chrome --dart-define-from-file=config/firebase.json`.

For Android/iOS store builds, phone sign-in also needs: on **Android**, your
app's SHA-1 and SHA-256 fingerprints added in *Project settings*; on **iOS**,
an APNs key uploaded in *Project settings → Cloud Messaging* and the
reversed client ID / encoded app ID added as a URL scheme. Register those apps in the same Firebase project
(or run `flutterfire configure`, which regenerates `lib/firebase_options.dart`),
and set up release signing (see "Publishing the apps" below).

### Updating bundled content

- **Video channels**: edit `functions/channels.json`, then
  `node functions/feed.js --snapshot` to refresh the offline snapshot, and
  redeploy.
- **Bible / hymn data**: see the usage notes at the top of
  `tool/build_bible.py` and `tool/build_wesley_hymns.py`.
