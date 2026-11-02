# Launch checklist

Everything in the code is ready. These are the steps only you can do: they
need your accounts, keys or decisions. Work top to bottom.

## 1. Fill in the legal documents

- [ ] In `assets/legal/privacy.md` and `assets/legal/terms.md`, replace
      **`[OPERATOR NAME]`** (you or your organisation) and **`[CONTACT EMAIL]`**
      (an inbox you check, for support and data requests).
- [ ] Run `python3 tool/build_legal.py` to refresh `web/privacy.html` and
      `web/terms.html`.
- [ ] Read both documents once. They describe exactly what the app does today;
      if you add analytics, ads or anything else that collects data, update them.

## 2. Firebase (accounts, database, website)

1. [ ] Create a project at <https://console.firebase.google.com> and switch it
       to the **Blaze** plan (needed for the video-feed function and for SMS
       beyond the small free daily allowance).
2. [ ] **Authentication → Sign-in method → Phone**: enable.
3. [ ] **Authentication → Settings → SMS region policy**: allow **Ghana** and any
       other countries you serve. SMS is billed per message.
4. [ ] Optional: **Phone → Phone numbers for testing**: add a fake number with a
       fixed code so you (and app reviewers) can sign in without real SMS.
5. [ ] **Firestore Database**: create it (production mode).
6. [ ] **Project settings → Your apps**: add a **Web** app, an **iOS** app with
       bundle ID `com.rendosland.seance`, and an **Android** app with package
       `com.rendosland.seance`.
7. [ ] Copy `config/firebase.example.json` to `config/firebase.json` and fill in
       the values from those apps.

## 3. Website

- [ ] `npm install -g firebase-tools`, `firebase login`, `firebase use --add`.
- [ ] `./scripts/deploy_web.sh` → your site is live at
      `https://<project-id>.web.app` with `/privacy.html` and `/terms.html`.
- [ ] Open the site on your phone, sign in with your number, and try each tab.
- [ ] Custom domain (optional): **Hosting → Add custom domain**, then add it under
      **Authentication → Settings → Authorized domains**.

## 4. iPhone app (App Store)

You need an Apple Developer account ($99/year).

- [ ] In Xcode (`open ios/Runner.xcworkspace`), select the **Runner** target →
      **Signing & Capabilities** → choose your Team. Bundle ID is already
      `com.rendosland.seance`.
- [ ] Phone sign-in on iOS: upload an **APNs key** in Firebase (**Project settings
      → Cloud Messaging**), and add the iOS app's **Encoded App ID** (shown in
      Firebase → Project settings → your iOS app) as a URL scheme under
      **Runner → Info → URL Types**.
- [ ] Optional home-screen widget: follow `ios/ReadingWidget/README.md`
      (app group `group.com.rendosland.seance`).
- [ ] Build: `flutter build ipa --release --dart-define-from-file=config/firebase.json`,
      then upload `build/ios/ipa/*.ipa` with the Transporter app.
- [ ] In App Store Connect: add screenshots, the description, **Privacy Policy URL**
      (`https://<your-site>/privacy.html`), support URL, and the **App Privacy**
      answers: *Phone Number*, *User ID* and *Other User Content* (journal) —
      collected, linked to the user, used for **App Functionality**, **not**
      used for tracking.
- [ ] Give the reviewer a test phone number and code (from step 2.4) in
      **App Review Information**.

## 5. Android app (Google Play)

You need a Google Play developer account ($25 once) and Java (install Android
Studio, which includes it, then run `flutter doctor`).

- [ ] Create an upload key:
      `keytool -genkey -v -keystore ~/seance-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Create `android/key.properties` (it is git-ignored):
      ```
      storePassword=…
      keyPassword=…
      keyAlias=upload
      storeFile=/Users/<you>/seance-upload.jks
      ```
      Keep the `.jks` file and passwords safe: you need them for every update.
- [ ] Phone sign-in on Android: add your app's **SHA-1** and **SHA-256**
      fingerprints in Firebase (**Project settings → your Android app**). Get
      them with `cd android && ./gradlew signingReport`, and after your first
      upload also add the **Play App Signing** fingerprints from the Play Console.
- [ ] Build: `flutter build appbundle --release --dart-define-from-file=config/firebase.json`
      and upload `build/app/outputs/bundle/release/app-release.aab`.
- [ ] In the Play Console: store listing, **Privacy Policy URL**, the **Data
      safety** form (same answers as Apple's App Privacy above; data is encrypted
      in transit; users can request deletion in the app), content rating, and
      the **account deletion URL** (`https://<your-site>/privacy.html`, which
      explains Profile → Delete account).

## 6. Before each release

- [ ] `flutter analyze && flutter test`
- [ ] Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+`
      must go up for every store upload).
- [ ] Refresh the offline video list: `node functions/feed.js --snapshot`.
