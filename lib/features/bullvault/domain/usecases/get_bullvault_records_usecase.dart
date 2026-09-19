import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

final class GetBullVaultRecordsUsecase {
  final BullVaultRepository _repository;

  const GetBullVaultRecordsUsecase(this._repository);

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> execute() =>
      _repository.getAll();
}

final class GetBullVaultRecordUsecase {
  final BullVaultRepository _repository;

  const GetBullVaultRecordUsecase(this._repository);

  @useResult
  Future<Result<BullVaultRecord?, BullVaultFailure>> execute(String walletId) =>
      _repository.getByWalletId(walletId);
}

final class WatchBullVaultRecordsUsecase {
  final BullVaultRepository _repository;

  const WatchBullVaultRecordsUsecase(this._repository);

  Stream<void> execute() => _repository.changes;
}
