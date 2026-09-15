import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

final class WatchBullVaultBackupChangesUsecase {
  final BullVaultRepository _repository;

  const WatchBullVaultBackupChangesUsecase(this._repository);

  Stream<void> execute() => _repository.watchBackupChanges();
}
