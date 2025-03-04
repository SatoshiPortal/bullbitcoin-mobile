import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/bip32_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/descriptor_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';

abstract class WalletMetadataDataSource {
  Future<WalletMetadataModel> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    required String label,
    required bool isDefault,
  });
  Future<WalletMetadataModel> deriveFromXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  });
  Future<void> store(
    WalletMetadataModel metadata,
  );
  Future<WalletMetadataModel?> get(String walletId);
  Future<List<WalletMetadataModel>> getAll();
  Future<void> delete(String walletId);
}

class WalletMetadataDataSourceImpl implements WalletMetadataDataSource {
  final Bip32DataSource _bip32;
  final DescriptorDataSource _descriptor;
  final KeyValueStorageDataSource<String> _walletMetadataStorage;

  const WalletMetadataDataSourceImpl({
    required Bip32DataSource bip32,
    required DescriptorDataSource descriptor,
    required KeyValueStorageDataSource<String> walletMetadataStorage,
  })  : _bip32 = bip32,
        _descriptor = descriptor,
        _walletMetadataStorage = walletMetadataStorage;

  @override
  Future<WalletMetadataModel> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    required String label,
    required bool isDefault,
  }) async {
    final xpub = await _bip32.getAccountXpub(
      seedBytes: seed.seedBytes,
      network: network,
      scriptType: scriptType,
    );

    String descriptor;
    String changeDescriptor;
    if (network.isBitcoin) {
      final xprv = _bip32.getXprvFromSeed(seed.seedBytes, network);
      descriptor = await _descriptor.derivePublicBitcoinDescriptorFromXpriv(
        xprv,
        scriptType: scriptType,
        isTestnet: network.isTestnet,
      );
      changeDescriptor =
          await _descriptor.derivePublicBitcoinDescriptorFromXpriv(
        xprv,
        scriptType: scriptType,
        isTestnet: network.isTestnet,
        isInternalKeychain: true,
      );
    } else {
      if (seed is! MnemonicSeed) {
        throw MnemonicSeedNeededException(
          'Mnemonic seed is required for Liquid network',
        );
      }

      descriptor = await _descriptor.derivePublicLiquidDescriptorFromMnemonic(
        seed.mnemonicWords.join(' '),
        scriptType: scriptType,
        isTestnet: network.isTestnet,
      );
      changeDescriptor = descriptor;
    }

    return WalletMetadataModel(
      masterFingerprint: seed.masterFingerprint,
      xpubFingerprint: xpub.fingerprintHex,
      source: WalletSource.mnemonic.name,
      isBitcoin: network.isBitcoin,
      isLiquid: network.isLiquid,
      isMainnet: network.isMainnet,
      isTestnet: network.isTestnet,
      scriptType: scriptType.name,
      xpub: xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      isDefault: isDefault,
      label: label,
    );
  }

  @override
  Future<WalletMetadataModel> deriveFromXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    String label = '',
  }) async {
    if (network.isLiquid) {
      throw UnimplementedError(
        'Importing xpubs for Liquid network is not supported',
      );
    }

    final bip32Xpub = _bip32.getBip32Xpub(xpub);
    final xpubBase58 = bip32Xpub.toBase58();
    final fingerprint = bip32Xpub.fingerprintHex;

    final descriptor = await _descriptor.deriveBitcoinDescriptorFromXpub(
      xpubBase58,
      fingerprint: fingerprint,
      scriptType: scriptType,
      isTestnet: network.isTestnet,
    );
    final changeDescriptor = await _descriptor.deriveBitcoinDescriptorFromXpub(
      xpubBase58,
      fingerprint: fingerprint,
      scriptType: scriptType,
      isTestnet: network.isTestnet,
      isInternalKeychain: true,
    );

    return WalletMetadataModel(
      xpubFingerprint: fingerprint,
      source: WalletSource.xpub.name,
      isBitcoin: network.isBitcoin,
      isLiquid: network.isLiquid,
      isMainnet: network.isMainnet,
      isTestnet: network.isTestnet,
      scriptType: scriptType.name,
      xpub: bip32Xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      label: label,
    );
  }

  @override
  Future<void> store(
    WalletMetadataModel metadata,
  ) async {
    final value = jsonEncode(metadata.toJson());
    await _walletMetadataStorage.saveValue(key: metadata.id, value: value);
  }

  @override
  Future<WalletMetadataModel?> get(String walletId) async {
    final value = await _walletMetadataStorage.getValue(walletId);

    if (value == null) {
      return null;
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final metadata = WalletMetadataModel.fromJson(json);

    return metadata;
  }

  @override
  Future<List<WalletMetadataModel>> getAll() async {
    final map = await _walletMetadataStorage.getAll();

    return map.values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .map((json) => WalletMetadataModel.fromJson(json))
        .toList();
  }

  @override
  Future<void> delete(String walletId) {
    return _walletMetadataStorage.deleteValue(walletId);
  }
}

class MnemonicSeedNeededException implements Exception {
  final String message;

  MnemonicSeedNeededException(this.message);
}
