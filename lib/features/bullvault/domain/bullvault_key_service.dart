import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart';

final class BullVaultKeyService {
  static const _fixedNumsInternalKey =
      '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';
  final BitcoinDescriptorPort _descriptorPort;

  const BullVaultKeyService(this._descriptorPort);

  Result<BullVaultSignerKey, BullVaultFailure> localKey(
    Seed seed,
    int account,
    Network network, {
    required BullVaultSignerRole role,
    bool requiresPassphrase = false,
  }) {
    try {
      final derivationPath = Bip48Derivation.path(
        coinType: network.coinType,
        account: account,
      );
      final xpub = Bip32Derivation.deriveXpub(
        seedBytes: seed.bytes,
        derivationPath: derivationPath,
        network: network,
      );
      return Ok(
        BullVaultSignerKey(
          role: role,
          accountKey: WalletDescriptorKey(
            id: '${role.name}-account',
            signerId: 'everyday',
            masterFingerprint: seed.masterFingerprint.toLowerCase(),
            xpubFingerprint: Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
            xpub: xpub,
            derivationPath: derivationPath,
            requiresPassphrase: requiresPassphrase,
          ),
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      );
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to derive the BullVault mobile key',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    }
  }

  Result<BullVaultSignerKey, BullVaultFailure> externalKey(
    BullVaultSignerRequest request,
    BullVaultSignerRole role, {
    required Network network,
  }) {
    if (request.genericExternal) {
      if (request.device != null) {
        return const Err(BullVaultInvalidSignerFailure());
      }
    } else if (request.device?.supportsComplexTaprootRegistration != true) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    if (!request.requiresHardwareSetup &&
        (!request.genericExternal || request.device != null)) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    return _parseAccountKey(
      request.input,
      role: role,
      network: network,
      signer: request.requiresHardwareSetup
          ? SignerEntity.remote
          : SignerEntity.none,
      signerDevice: request.device,
    );
  }

  Result<BullVaultSignerKey, BullVaultFailure> _parseAccountKey(
    String input, {
    required BullVaultSignerRole role,
    required Network network,
    required SignerEntity signer,
    required SignerDeviceEntity? signerDevice,
  }) {
    final normalized = input.trim();
    if (normalized.isEmpty ||
        normalized.contains('*') ||
        normalized.contains('<') ||
        normalized.contains('(')) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    try {
      final synthetic = 'tr($_fixedNumsInternalKey,pk($normalized/<0;1>/*))';
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: synthetic,
        network: network,
      );
      if (parsed.descriptorKeys.length != 1) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      final key = parsed.descriptorKeys.single;
      final xpub = Bip32Derivation.getBip32Xpub(key.xpub);
      if (hex.encode(xpub.public) == _fixedNumsInternalKey) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      if (key.masterFingerprint.isEmpty ||
          Bip48Derivation.account(
                _normalizePath(key.derivationPath),
                coinType: network.coinType,
              ) ==
              null ||
          xpub.depth != 4 ||
          xpub.index != 0x80000002) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      return Ok(
        BullVaultSignerKey(
          role: role,
          accountKey: WalletDescriptorKey(
            id: '${role.name}-account',
            signerId: role.name,
            masterFingerprint: key.masterFingerprint,
            xpubFingerprint: key.xpubFingerprint,
            xpub: key.xpub,
            derivationPath: key.derivationPath,
          ),
          signer: signer,
          signerDevice: signerDevice,
        ),
      );
    } on Exception {
      return const Err(BullVaultInvalidSignerFailure());
    }
  }

  String? _normalizePath(String? path) =>
      path?.replaceAll('h', "'").replaceAll('H', "'");

  Seed? canonicalSeed(Seed seed) {
    if (seed is! MnemonicSeed) return seed;
    try {
      return _mnemonicSeed(seed.mnemonicWords);
    } on Exception {
      return null;
    }
  }

  Seed? seedWithPassphrase(Seed canonicalSeed, String? passphrase) {
    if (passphrase == null || passphrase.isEmpty) return canonicalSeed;
    if (canonicalSeed is! MnemonicSeed) return null;
    try {
      return _mnemonicSeed(canonicalSeed.mnemonicWords, passphrase);
    } on Exception {
      return null;
    }
  }

  Seed _mnemonicSeed(List<String> words, [String passphrase = '']) {
    final mnemonic = bip39.Mnemonic.fromWords(
      words: words,
      passphrase: passphrase,
    );
    final bytes = Uint8List.fromList(mnemonic.seed);
    final fingerprint = bip32.Bip32Keys.fromSeed(bytes).fingerprintHex;
    return Seed.mnemonic(
      mnemonicWords: mnemonic.words,
      passphrase: passphrase.isEmpty ? null : passphrase,
      bytes: bytes,
      masterFingerprint: fingerprint,
    );
  }
}
