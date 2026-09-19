import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class BuildWalletBackupSnapshotUsecase {
  final WalletBackupSnapshotRepository _repository;
  final NostrIdentityFacade _identity;
  const BuildWalletBackupSnapshotUsecase(this._repository, this._identity);
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> execute() async =>
      switch (await _identity.resolve()) {
        Err() => const Err(WalletBackupCredentialFailure()),
        Ok(:final value) => await _repository.capture(value),
      };
}

final class WatchWalletBackupSnapshotUsecase {
  final WalletBackupSnapshotRepository _repository;
  const WatchWalletBackupSnapshotUsecase(this._repository);
  Stream<void> execute() => _repository.changes;
}
