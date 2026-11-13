import 'package:secrets/src/public/ephemeral_mnemonic.dart';
import 'package:secrets/src/widgets/secret_widgets.dart';

/// The same sealed display and backup check for an unstored setup mnemonic.
extension EphemeralMnemonicExtension on EphemeralMnemonic {
  SecretWidgets get widgets => SecretWidgets.ephemeral(this);
}
