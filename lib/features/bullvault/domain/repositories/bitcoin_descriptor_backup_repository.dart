import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:meta/meta.dart';

abstract interface class BitcoinDescriptorBackupRepository {
  @useResult
  Result<BitcoinBackupPublication, BullVaultFailure> prepare(
    String descriptor,
    BitcoinBackupNetwork network,
  );

  @useResult
  Future<Result<BitcoinBackupFetch, BullVaultFailure>> fetch(
    String input,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  );

  @useResult
  Future<Result<RestoredBackupWallet, BullVaultFailure>> restore(
    String descriptor,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  );
}
