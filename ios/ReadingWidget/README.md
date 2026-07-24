# iOS home-screen widget — Xcode setup

The Dart + Android sides are wired and working. iOS WidgetKit requires a one-time
**Widget Extension target** that can only be added from Xcode. The Swift code,
`Info.plist` and entitlements already live in this folder — you just attach them
to a new target and turn on the App Group.

## 1. Add the Widget Extension target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File ▸ New ▸ Target… ▸ Widget Extension**.
3. Product Name: **`ReadingWidget`**. Uncheck *Include Configuration Intent*.
   Finish, and when prompted **do not** activate a new scheme (Cancel is fine).
4. Xcode generates a stub `ReadingWidget.swift` / `Info.plist` inside a new
   `ReadingWidget` group. **Delete those generated files** (Move to Trash) and
   instead **Add Files to "Runner"…** selecting the existing files in this
   `ios/ReadingWidget/` folder:
   - `ReadingWidget.swift`
   - `Info.plist`
   - `ReadingWidget.entitlements`
   Make sure they are added to the **ReadingWidget** target (not Runner).

## 2. Point the target at our Info.plist / entitlements

In the **ReadingWidget** target ▸ **Build Settings**:
- `Info.plist File` → `ReadingWidget/Info.plist`
- `Code Signing Entitlements` → `ReadingWidget/ReadingWidget.entitlements`
- `iOS Deployment Target` → 14.0 or higher (16+ recommended).

## 3. Enable the App Group on BOTH targets

The widget reads the data the app writes through a shared App Group.

1. Select the **Runner** target ▸ **Signing & Capabilities** ▸ **+ Capability**
   ▸ **App Groups**. Add `group.com.example.seance`.
   (`ios/Runner/Runner.entitlements` already declares it; if Runner had no
   entitlements file before, set *Code Signing Entitlements* →
   `Runner/Runner.entitlements`.)
2. Select the **ReadingWidget** target ▸ **Signing & Capabilities** ▸ App Groups
   ▸ add the same `group.com.example.seance`.

> If you change the app's bundle id, update the group id in three places:
> this entitlements pair, `ReadingWidget.swift` (`appGroupId`), and
> `lib/services/widget_service.dart` (`WidgetService.appGroupId`).

## 4. Run

`flutter run` (or build the Runner scheme). Launch the app once so it pushes the
current reading, then long-press the home screen ▸ **+** ▸ search "séance" /
"Weekly reading" to add the widget.

## Notes
- Data keys written by Dart: `reading_title`, `reading_excerpt`, `reading_meta`.
- The widget `kind` is `ReadingWidget` — it must match the `iOSName` passed in
  `WidgetService.pushWeeklyReading`.
- Notifications (Monday 08:00) work independently of the widget and need no
  Xcode target — iOS will prompt for permission on first launch.
