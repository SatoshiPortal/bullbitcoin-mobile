import 'package:bb_mobile/core/failures/failure.dart';

sealed class PortableBackupFailure extends Failure {
  const PortableBackupFailure();
}

final class PortableBackupInvalidPasswordFailure extends PortableBackupFailure {
  const PortableBackupInvalidPasswordFailure();
}

final class PortableBackupInvalidDataFailure extends PortableBackupFailure {
  const PortableBackupInvalidDataFailure();
}

final class PortableBackupDecryptFailure extends PortableBackupFailure {
  const PortableBackupDecryptFailure();
}

final class PortableBackupNetworkFailure extends PortableBackupFailure {
  const PortableBackupNetworkFailure();
}

final class PortableBackupCancelledFailure extends PortableBackupFailure {
  const PortableBackupCancelledFailure();
}
