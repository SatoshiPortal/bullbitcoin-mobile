/// The sealed widgets: the only way a secret's words reach a screen.
///
/// Each reads the mnemonic inside its own state and hands the host widgets
/// with no text accessor. `SealedWord` is the seal itself, not part of the
/// surface, and stays out of this list. A host reaches these through
/// `secret.widgets` — the constructors are `@internal`.
library;

export 'mnemonic_challenge.dart' show MnemonicChallenge, MnemonicTile;
export 'mnemonic_view.dart' show MnemonicView;
export 'secret_widgets.dart' show SecretWidgets;
