import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bitcoin_descriptor_backup_repository.dart';
import 'package:meta/meta.dart';

final class FetchBitcoinBackupUsecase {
  final BitcoinDescriptorBackupRepository _repository;
  const FetchBitcoinBackupUsecase(this._repository);
  @useResult
  Future<Result<BitcoinBackupFetch, BullVaultFailure>> execute({
    required String input,
    required BitcoinBackupNetwork network,
    required ElectrumConnection connection,
    required DescriptorBackupSession session,
  }) => _repository.fetch(input, network, connection, session);
}
