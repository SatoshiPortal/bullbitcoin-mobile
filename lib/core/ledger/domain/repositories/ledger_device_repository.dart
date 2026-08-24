import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:meta/meta.dart';

abstract interface class LedgerDeviceRepository {
  @useResult
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> scanDevices({
    SignerDeviceEntity? deviceType,
  });

  @useResult
  Future<Result<void, LedgerFailure>> connectDevice(LedgerDeviceEntity device);

  @useResult
  Future<Result<String, LedgerFailure>> getMasterFingerprint(
    LedgerDeviceEntity device,
  );

  @useResult
  Future<Result<String, LedgerFailure>> getXpub(
    LedgerDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
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

  @useResult
  Future<Result<void, LedgerFailure>> registerWalletPolicy(
    LedgerDeviceEntity device, {
    required Wallet wallet,
  });

  @useResult
  Future<Result<String, LedgerFailure>> signWalletPsbt(
    LedgerDeviceEntity device, {
    required Wallet wallet,
    required String signerId,
    required String psbt,
  });

  @useResult
  Future<Result<bool, LedgerFailure>> verifyWalletAddress(
    LedgerDeviceEntity device, {
    required Wallet wallet,
    required String address,
    required BitcoinPolicyKeychain keychain,
    required int index,
  });

  @useResult
  Future<Result<void, LedgerFailure>> disconnectConnection(
    LedgerDeviceEntity device,
  );

  @useResult
  Future<Result<void, LedgerFailure>> dispose();
}
