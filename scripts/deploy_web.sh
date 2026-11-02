#!/usr/bin/env bash
# Build the web app with Firebase config and deploy it to Firebase Hosting.
#   1. cp config/firebase.example.json config/firebase.json  (fill in values)
#   2. firebase login && firebase use --add                   (once)
#   3. ./scripts/deploy_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f config/firebase.json ]]; then
  echo "Missing config/firebase.json — copy config/firebase.example.json and fill it in." >&2
  exit 1
fi

# Clean first: a stale build cache can ship an outdated plugin registrant.
flutter clean
flutter pub get
flutter test
flutter build web --release --dart-define-from-file=config/firebase.json
(cd functions && npm install --omit=dev)
firebase deploy --only functions,hosting,firestore:rules
