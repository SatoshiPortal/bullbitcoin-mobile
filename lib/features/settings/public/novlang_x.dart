import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:novlang/novlang.dart';

/// Applies the store-compliance vocabulary ("Novlang", ref. Orwell's Newspeak)
/// to a sensitive string.
///
/// Some words the app really uses (e.g. "Exchange") are not allowed by an app
/// store's review policy, which forces a euphemism ("Account"). Rather than
/// editing the real strings, each sensitive string keeps its real l10n key and
/// gains a store-suffixed twin (`<key>NewspeakApple`, later `<key>NewspeakGoogle`).
///
/// The pure selection logic lives in `package:novlang`; this extension only
/// resolves the active [NewspeakPolicy] from the platform and the hidden
/// superuser toggle, then delegates to [NewspeakPolicy.pick].
extension NovlangX on BuildContext {
  /// The active [NewspeakPolicy] for the current platform + superuser state.
  ///
  /// Superuser unlocked → [NewspeakPolicy.none] (real words). Otherwise the
  /// platform's store policy: iOS → apple, Android → google, else none.
  ///
  /// Reads `isSuperuser` with `select` so a screen rebuilds when superuser is
  /// toggled (a `read` would leave stale text on screen). Uses
  /// [defaultTargetPlatform] rather than `dart:io` `Platform` so widget tests
  /// can drive it with `debugDefaultTargetPlatformOverride`.
  NewspeakPolicy get _novlangPolicy {
    final isSuperuser =
        select((SettingsCubit cubit) => cubit.state.isSuperuser) ?? false;
    if (isSuperuser) return NewspeakPolicy.none;

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => NewspeakPolicy.apple,
      TargetPlatform.android => NewspeakPolicy.google,
      _ => NewspeakPolicy.none,
    };
  }

  /// Picks the store-compliant wording for a sensitive string.
  ///
  /// Pass the real string plus whichever store twins exist. A store with no
  /// twin (or the `none` policy) falls back to [real], so a caller that only
  /// has an Apple twin simply omits `google` and Android shows the real word.
  ///
  /// Must be called from `build` (like any `select`), not from a callback.
  ///
  /// ```dart
  /// Text(context.novlang(
  ///   real: context.loc.settingsExchangeSettingsTitle,
  ///   apple: context.loc.settingsExchangeSettingsTitleNewspeakApple,
  /// ))
  /// ```
  String novlang({required String real, String? apple, String? google}) {
    return _novlangPolicy.pick(real: real, apple: apple, google: google);
  }
}
