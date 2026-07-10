/// Store-compliance vocabulary policy (Newspeak) — pure selection logic.
///
/// Import this single barrel. The host app resolves the active
/// [NewspeakPolicy] (from platform + its own "real words" toggle) and calls
/// [NewspeakPolicy.pick] to choose the store-compliant wording.
library;

export 'src/newspeak_policy.dart';
