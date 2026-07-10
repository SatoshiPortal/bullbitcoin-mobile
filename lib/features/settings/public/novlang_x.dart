import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Store-compliance vocabulary policy ("Novlang", ref. Orwell's Newspeak).
///
/// Some words the app really uses (e.g. "Exchange") are not allowed by an app
/// store's review policy, which forces a euphemism ("Account"). Instead of
/// editing the real strings, each sensitive string keeps its real l10n key and
/// gains a store-suffixed twin (`<key>NewspeakApple`, and later
/// `<key>NewspeakGoogle`). This enum selects which twin — if any — the UI shows.
///
/// The policy is derived, not stored: it is the platform's default store policy
/// unless the hidden superuser mode is unlocked, which reveals the real words
/// everywhere ([NewspeakPolicy.none]).
enum NewspeakPolicy { none, apple, google }

extension NovlangX on BuildContext {
  /// The active [NewspeakPolicy] for the current platform + superuser state.
  ///
  /// Superuser unlocked → [NewspeakPolicy.none] (real words). Otherwise the
  /// platform's store policy: iOS → [NewspeakPolicy.apple], Android →
  /// [NewspeakPolicy.google], anything else → [NewspeakPolicy.none].
  ///
  /// Reads `isSuperuser` with `select` so a screen rebuilds when superuser is
  /// toggled (a `read` would leave stale text on screen). Uses
  /// [defaultTargetPlatform] rather than `dart:io` `Platform` so widget tests
  /// can drive it with `debugDefaultTargetPlatformOverride`.
  ///
  /// Must be called from `build` (like any `select`), not from a callback.
  NewspeakPolicy get novlangPolicy {
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
  /// ```dart
  /// Text(context.novlang(
  ///   real: context.loc.settingsExchangeSettingsTitle,
  ///   apple: context.loc.settingsExchangeSettingsTitleNewspeakApple,
  /// ))
  /// ```
  String novlang({required String real, String? apple, String? google}) {
    return switch (novlangPolicy) {
      NewspeakPolicy.apple => apple ?? real,
      NewspeakPolicy.google => google ?? real,
      NewspeakPolicy.none => real,
    };
  }
}
