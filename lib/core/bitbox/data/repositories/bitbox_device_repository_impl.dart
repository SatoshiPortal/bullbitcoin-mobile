import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

class BitBoxDeviceRepositoryImpl implements BitBoxDeviceRepository {
  final BitBoxDeviceDatasource _datasource;

  BitBoxDeviceRepositoryImpl({required this._datasource});

  /// [isCleanup] downgrades the log to `warning`: a failed teardown
  /// (disconnect/dispose) is not user-facing and shouldn't page as `severe`.
  Future<Result<T, BitBoxFailure>> _guard<T>(
    Future<T> Function() run, {
    bool isCleanup = false,
  }) async {
    try {
      return Ok(await run());
    } on BitBoxFailure catch (f) {
      log.warning('BitBox failure: ${f.runtimeType}', error: f.logMessage);
      return Err(f);
    } catch (e, st) {
      if (isCleanup) {
        log.warning('BitBox cleanup failed', error: e, trace: st);
      } else {
        log.severe(message: 'BitBox operation failed', error: e, trace: st);
      }
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<BitBoxDeviceEntity>, BitBoxFailure>> scanDevices() =>
      _guard(() async {
        final models = await _datasource.scanDevices();
        return models.map((model) => model.toEntity()).toList();
      });

  @override
  Future<Result<void, BitBoxFailure>> connectDevice(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.connectDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> unlockDevice(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.unlockDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> pairDevice(BitBoxDeviceEntity device) =>
      _guard(() => _datasource.pairDevice(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> getXpub(
    BitBoxDeviceEntity device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.getXpub(
      device.toModel(),
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<String, BitBoxFailure>> getMasterFingerprint(
    BitBoxDeviceEntity device,
  ) => _guard(() => _datasource.getMasterFingerprint(device.toModel()));

  @override
  Future<Result<String, BitBoxFailure>> signPsbt(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.signPsbt(
      device.toModel(),
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<bool, BitBoxFailure>> verifyAddress(
    BitBoxDeviceEntity device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) => _guard(
    () => _datasource.verifyAddress(
      device.toModel(),
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<void, BitBoxFailure>> registerWalletPolicy(
    BitBoxDeviceEntity device, {
    required Wallet wallet,
    String? signerId,
  }) => _guard(() async {
    final model = device.toModel();
    final signer = await _matchWalletSigner(
      model,
      wallet: wallet,
      signerId: signerId,
      isTestnet: wallet.isTestnet,
    );
    _ensureSupportedPolicy(wallet, signer);
    final registered = await _datasource.isWalletPolicyRegistered(
      model,
      descriptor: wallet.publicDescriptor,
      isTestnet: wallet.isTestnet,
    );
    if (!registered) {
      await _datasource.registerWalletPolicy(
        model,
        descriptor: wallet.publicDescriptor,
        isTestnet: wallet.isTestnet,
        name: _walletPolicyName(wallet),
      );
    }
  });

  @override
  Future<Result<String, BitBoxFailure>> signWalletPsbt(
    BitBoxDeviceEntity device, {
    required Wallet wallet,
    required String signerId,
    required String psbt,
  }) => _guard(() async {
    final model = device.toModel();
    final signer = await _matchWalletSigner(
      model,
      wallet: wallet,
      signerId: signerId,
      isTestnet: wallet.isTestnet,
    );
    _ensureSupportedPolicy(wallet, signer);
    if (!await _datasource.isWalletPolicyRegistered(
      model,
      descriptor: wallet.publicDescriptor,
      isTestnet: wallet.isTestnet,
    )) {
      throw const WalletPolicyNotRegisteredBitBoxFailure();
    }
    return _datasource.signWalletPsbt(
      model,
      descriptor: wallet.publicDescriptor,
      psbt: psbt,
      isTestnet: wallet.isTestnet,
    );
  });

  @override
  Future<Result<bool, BitBoxFailure>> verifyWalletAddress(
    BitBoxDeviceEntity device, {
    required Wallet wallet,
    required String address,
    required BitcoinPolicyKeychain keychain,
    required int index,
    String? signerId,
  }) => _guard(() async {
    final model = device.toModel();
    final signer = await _matchWalletSigner(
      model,
      wallet: wallet,
      signerId: signerId,
      isTestnet: wallet.isTestnet,
    );
    _ensureSupportedPolicy(wallet, signer);
    if (!await _datasource.isWalletPolicyRegistered(
      model,
      descriptor: wallet.publicDescriptor,
      isTestnet: wallet.isTestnet,
    )) {
      throw const WalletPolicyNotRegisteredBitBoxFailure();
    }
    final verifiedAddress = await _datasource.verifyWalletAddress(
      model,
      descriptor: wallet.publicDescriptor,
      isTestnet: wallet.isTestnet,
      keychain: keychain,
      index: index,
    );
    if (verifiedAddress != address) {
      throw const AddressMismatchBitBoxFailure();
    }
    return true;
  });

  Future<WalletSigner> _matchWalletSigner(
    BitBoxDeviceModel device, {
    required Wallet wallet,
    required bool isTestnet,
    String? signerId,
  }) async {
    final fingerprint = (await _datasource.getMasterFingerprint(
      device,
    )).toLowerCase();
    final candidates = wallet.signers.where(
      (signer) =>
          signer.signerDevice?.isBitBox == true &&
          (signerId == null || signer.id == signerId),
    );
    for (final signer in candidates) {
      if (signer.descriptorKeys.any(
        (key) => key.masterFingerprint.toLowerCase() != fingerprint,
      )) {
        continue;
      }
      var matches = true;
      for (final key in signer.descriptorKeys) {
        final path = key.derivationPath;
        if (path == null || key.xpub.isEmpty) {
          matches = false;
          break;
        }
        final xpub = await _datasource.getWalletPolicyXpub(
          device,
          derivationPath: path,
          isTestnet: isTestnet,
        );
        if (!_sameXpub(xpub, key.xpub)) {
          matches = false;
          break;
        }
      }
      if (matches) return signer;
    }
    throw const WalletSignerMismatchBitBoxFailure();
  }

  static void _ensureSupportedPolicy(Wallet wallet, WalletSigner signer) {
    if (!wallet.supportsWalletPolicySigner(signer)) {
      throw const UnsupportedWalletPolicyBitBoxFailure();
    }
  }

  static String? _walletPolicyName(Wallet wallet) {
    final source = wallet.label?.trim() ?? '';
    final name = source.codeUnits
        .where((unit) => unit >= 0x20 && unit <= 0x7e)
        .map(String.fromCharCode)
        .join()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) return null;
    return name.length <= 30 ? name : name.substring(0, 30).trimRight();
  }

  static bool _sameXpub(String first, String second) =>
      Bip32Derivation.getBip32Xpub(first).toBase58() ==
      Bip32Derivation.getBip32Xpub(second).toBase58();

  @override
  Future<Result<void, BitBoxFailure>> disconnectConnection(
    BitBoxDeviceEntity device,
  ) => _guard(
    () => _datasource.disconnectConnection(device.toModel()),
    isCleanup: true,
  );

  @override
  Future<Result<void, BitBoxFailure>> dispose() =>
      _guard(() => _datasource.dispose(), isCleanup: true);
}
