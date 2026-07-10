/// Store-compliance vocabulary policy ("Novlang", ref. Orwell's Newspeak).
///
/// Some words the app really uses (e.g. "Exchange") are not allowed by an app
/// store's review policy, which forces a euphemism ("Account"). Rather than
/// editing the real strings, each sensitive string keeps its real value and is
/// given store-specific twins; this enum selects which twin — if any — to show.
///
/// This package holds only the pure selection logic: it has no knowledge of
/// Flutter, the platform, or where the "real words" toggle lives. The host app
/// resolves the active policy and calls [NewspeakPolicy.pick].
enum NewspeakPolicy {
  /// Show the real words (no store restriction, or restrictions bypassed).
  none,

  /// Apple App Store vocabulary.
  apple,

  /// Google Play Store vocabulary.
  google;

  /// Returns the store-compliant wording for a sensitive string.
  ///
  /// Pass the real value plus whichever store twins exist. A store with no twin
  /// (or [NewspeakPolicy.none]) falls back to [real], so a caller that only has
  /// an Apple twin simply omits [google].
  String pick({required String real, String? apple, String? google}) {
    return switch (this) {
      NewspeakPolicy.apple => apple ?? real,
      NewspeakPolicy.google => google ?? real,
      NewspeakPolicy.none => real,
    };
  }
}
