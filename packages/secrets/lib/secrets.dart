/// User secret material — BIP39 mnemonics and raw seeds — behind a custody boundary.
///
/// `Secrets` is the lifecycle; it hands back a `Secret`, on which every operation is a method. See the README for the contract and how to audit it.
///
/// This file *is* the surface: explicit `show` lists, so what is public is decided here and nowhere else. The failures a caller handles come through `types.dart`, the sealed widgets through `widgets/widgets.dart`; the invariant test pins the exact set of names.
library;

export 'src/public/extensions.dart'
    show
        SecretBackup,
        SecretBip85,
        SecretDerivation,
        SecretDescriptors,
        SecretExtension,
        SecretSigning;
export 'src/public/secret.dart' show Secret;
export 'src/public/secrets.dart' show RestoredVault, Secrets;
export 'src/public/types.dart';
export 'src/public/widgets.dart';
