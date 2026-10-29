import 'package:primitives/primitives.dart';

sealed class WalletSyncOptionsFailure extends Failure {
  const WalletSyncOptionsFailure();
}

final class WalletSyncOptionsStorageFailure extends WalletSyncOptionsFailure {
  const WalletSyncOptionsStorageFailure();
}

final class WalletSyncOptionsInvalidBirthdayFailure
    extends WalletSyncOptionsFailure {
  const WalletSyncOptionsInvalidBirthdayFailure();
}

final class WalletSyncNoPeersFailure extends WalletSyncOptionsFailure {
  const WalletSyncNoPeersFailure();
}

final class WalletSyncTorFailure extends WalletSyncOptionsFailure {
  const WalletSyncTorFailure();
}

final class WalletSyncPausedFailure extends WalletSyncOptionsFailure {
  const WalletSyncPausedFailure();
}

final class WalletSyncUnexpectedFailure extends WalletSyncOptionsFailure {
  const WalletSyncUnexpectedFailure();
}
