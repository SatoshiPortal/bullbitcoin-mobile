import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

abstract class LedgerDeviceRepository {
  @useResult
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> scanDevices({
    SignerDeviceEntity? deviceType,
  });

  @useResult
  Future<Result<Null, LedgerFailure>> connectDevice(LedgerDeviceEntity device);

  @useResult
  Future<Result<WatchOnlyWalletEntity, LedgerFailure>> getWatchOnlyWallet(
    LedgerDeviceEntity device, {
    required String label,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  });

  @useResult
  Future<Result<String, LedgerFailure>> signPsbt(
    LedgerDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  });

  @useResult
  Future<Result<bool, LedgerFailure>> verifyAddress(
    LedgerDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  });

  Future<void> disconnectConnection(LedgerDeviceEntity device);
  Future<void> dispose();
}
