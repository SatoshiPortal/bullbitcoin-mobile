import 'package:bb_mobile/core/failures/failure.dart';

sealed class PassphraseWalletFailure extends Failure {
  const PassphraseWalletFailure([super.logMessage]);
}

final class InvalidPassphraseFailure extends PassphraseWalletFailure {
  const InvalidPassphraseFailure();
}

final class PassphraseWalletSeedFailure extends PassphraseWalletFailure {
  const PassphraseWalletSeedFailure();
}

final class PassphraseWalletManifestFailure extends PassphraseWalletFailure {
  const PassphraseWalletManifestFailure();
}

final class PassphraseWalletDescriptorFailure extends PassphraseWalletFailure {
  const PassphraseWalletDescriptorFailure();
}

final class PassphraseWalletConflictFailure extends PassphraseWalletFailure {
  const PassphraseWalletConflictFailure();
}

final class PassphraseWalletStorageFailure extends PassphraseWalletFailure {
  const PassphraseWalletStorageFailure();
}

final class PassphraseWalletSyncFailure extends PassphraseWalletFailure {
  const PassphraseWalletSyncFailure();
}
