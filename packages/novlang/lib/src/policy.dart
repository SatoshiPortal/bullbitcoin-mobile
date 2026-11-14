import 'package:flutter/foundation.dart' show TargetPlatform;

/// Which store vocabulary constraint applies to the user-visible text.
///
/// The catalogue words are the real words. A policy other than [none] only
/// substitutes the words that store imposes; the superuser always sees the
/// real words.
enum NovlangPolicy {
  /// No substitution: the catalogue words are shown.
  none,

  /// App Store vocabulary: `swap` → `transfer`, `exchange` → `account`,
  /// `exchange rate` → `rate`.
  apple,

  /// Play Store vocabulary. Non-custodial wallets are outside the policy that
  /// restricts wording, so nothing is substituted. Kept distinct from [none]
  /// so a future Play constraint has a place to land.
  google,
}

/// Resolves the vocabulary policy for [platform].
///
/// [isSuperuser] is `null` while the setting is not loaded yet: the store
/// constraint of the platform applies until the user is known to be a
/// superuser. A superuser always gets [NovlangPolicy.none].
NovlangPolicy resolveNovlangPolicy(TargetPlatform platform, bool? isSuperuser) {
  if (isSuperuser == true) return NovlangPolicy.none;
  return switch (platform) {
    TargetPlatform.iOS => NovlangPolicy.apple,
    TargetPlatform.android => NovlangPolicy.google,
    _ => NovlangPolicy.none,
  };
}
