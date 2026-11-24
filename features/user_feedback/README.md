# user_feedback

In-app feedback. Shaking the phone, or Settings → Send feedback, opens the hosted feedback form in a sheet. The form posts to the feedback service, which stores the report, posts it to the team's Slack channel and files or updates a GitHub issue.

## Build configuration

The form address is set at build time:

```bash
fvm flutter run --dart-define=FEEDBACK_FORM_URL=https://feedback.example.com/
```

Without it the feature is off: no Settings row and no shake prompt. Only `https` is accepted, plus `http` on `localhost` for development.

## Shake detection

- iOS: the system shake gesture (the one behind "Shake to Undo"), forwarded by this package's small native plugin (`ios/user_feedback`). It hooks `UIWindow.motionEnded`, reports the shake and then runs the original handler. It reads no sensor data, needs no permission, and also works in the Simulator (Device → Shake).
- Android has no system shake gesture, so the accelerometer stream is fed to `ShakeDetector` (3 strong jolts within 800 ms, then a 3 s cooldown).

## Privacy

- The app sends device facts only: app version, platform, OS version, language and the current route name (never its parameters).
- A shake takes a screenshot of the current screen, but the form shows it to the user and attaches it only if they tick the box.
- No screenshot is taken while a protected screen (recovery phrase, seed view) is mounted, whatever the screen-privacy preference.
- The web view cannot navigate away from the form's site.

## Dependencies

- `sensors_plus`: accelerometer stream for shake detection on Android. No permission is needed.
- `webview_flutter`: shows the hosted form; already used by the exchange screens.
- `package_info_plus`: app version sent with the report.
- `screen_privacy`: tells whether a protected screen is mounted, so the shake never captures it.
- `bull_ui`, `bull_logger`: shared UI kit and logging.
