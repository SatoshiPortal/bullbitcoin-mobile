import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/locator.dart';

class WalletMetadataDatasource {
  final SqliteDatasource _sqlite;

  const WalletMetadataDatasource({
    required SqliteDatasource sqliteDatasource,
  }) : _sqlite = sqliteDatasource;

  Future<WalletMetadataModel> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    required String label,
    required bool isDefault,
  }) async {
    final xpub = await Bip32Derivation.getAccountXpub(
      seedBytes: seed.bytes,
      network: network,
      scriptType: scriptType,
    );

    String descriptor;
    String changeDescriptor;
    if (network.isBitcoin) {
      final xprv = Bip32Derivation.getXprvFromSeed(seed.bytes, network);
      descriptor =
          await DescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
        xprv,
        scriptType: scriptType,
        isTestnet: network.isTestnet,
      );
      changeDescriptor =
          await DescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
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

      descriptor =
          await DescriptorDerivation.derivePublicLiquidDescriptorFromMnemonic(
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

    final bip32Xpub = Bip32Derivation.getBip32Xpub(xpub);
    final xpubBase58 = bip32Xpub.toBase58();
    final fingerprint = bip32Xpub.fingerprintHex;

    final descriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
      xpubBase58,
      fingerprint: fingerprint,
      scriptType: scriptType,
      isTestnet: network.isTestnet,
    );
    final changeDescriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
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

  Future<void> store(WalletMetadataModel metadata) async {
    final sqliteMetadata = WalletMetadataMapper.fromModelToSqlite(metadata);
    await locator<SqliteDatasource>().store<WalletMetadata>(sqliteMetadata);
  }

  Future<WalletMetadataModel?> get(String id) async {
    final table = _sqlite.walletMetadatas;
    final metadata = await (_sqlite.select(table)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();

    if (metadata == null) return null;
    return WalletMetadataMapper.fromSqliteToModel(metadata);
  }

  Future<List<WalletMetadataModel>> getAll() async {
    final table = _sqlite.walletMetadatas;

    final metadatas = await _sqlite.select(table).get();
    return metadatas
        .map((e) => WalletMetadataMapper.fromSqliteToModel(e))
        .toList();
  }

  Future<void> delete(String id) async {
    await (_sqlite.delete(_sqlite.walletMetadatas)
          ..where((t) => t.id.equals(id)))
        .go();
  }
}

class MnemonicSeedNeededException implements Exception {
  final String message;

  MnemonicSeedNeededException(this.message);
}
