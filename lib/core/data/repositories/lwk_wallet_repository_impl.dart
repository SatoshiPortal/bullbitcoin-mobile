import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_repository.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class LwkWalletRepositoryImpl
    implements WalletRepository, LiquidWalletRepository {
  final String _id;
  final Network _network;
  final lwk.Wallet _wallet;
  final String _electrumUrl;
  final bool _validateElectrumDomain;

  const LwkWalletRepositoryImpl({
    required String id,
    required Network network,
    required lwk.Wallet wallet,
    required String electrumUrl,
    required bool validateDomain,
  })  : _id = id,
        _network = network,
        _wallet = wallet,
        _electrumUrl = electrumUrl,
        _validateElectrumDomain = validateDomain;

  static Future<LwkWalletRepositoryImpl> public({
    required WalletMetadata walletMetadata,
    required ElectrumServer electrumServer,
  }) async {
    final network = walletMetadata.network.lwkNetwork;

    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/${walletMetadata.id}';

    final descriptor = lwk.Descriptor(
      ctDescriptor: walletMetadata.externalPublicDescriptor,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbDir,
      descriptor: descriptor,
    );

    return LwkWalletRepositoryImpl(
      id: walletMetadata.id,
      network: walletMetadata.network,
      wallet: wallet,
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  static Future<LwkWalletRepositoryImpl> private({
    required WalletMetadata walletMetadata,
    required ElectrumServer electrumServer,
    required MnemonicSeed mnemonicSeed,
  }) async {
    final network = walletMetadata.network.lwkNetwork;

    // TODO: check if the same path as the public wallet can be used or not
    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/${walletMetadata.id}';

    final mnemonic = mnemonicSeed.mnemonicWords.join(' ');
    final descriptor = await lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: network,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbDir,
      descriptor: descriptor,
    );

    return LwkWalletRepositoryImpl(
      id: walletMetadata.id,
      network: walletMetadata.network,
      wallet: wallet,
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  @override
  String get id => _id;

  @override
  Network get network => _network;

  @override
  Future<Balance> getBalance() async {
    final balances = await _wallet.balances();

    final lBtcAssetBalance = balances.firstWhere((balance) {
      final lBtcAssetId =
          network == Network.liquidTestnet ? lwk.lTestAssetId : lwk.lBtcAssetId;
      return balance.assetId == lBtcAssetId;
    }).value;

    final balance = Balance(
      confirmedSat: BigInt.from(lBtcAssetBalance),
      immatureSat: BigInt.zero,
      trustedPendingSat: BigInt.zero,
      untrustedPendingSat: BigInt.zero,
      spendableSat: BigInt.from(lBtcAssetBalance),
      totalSat: BigInt.from(lBtcAssetBalance),
    );

    return balance;
  }

  @override
  Future<Address> getNewAddress() async {
    final lastUnusedAddressInfo = await _wallet.addressLastUnused();
    final newIndex = lastUnusedAddressInfo.index + 1;
    final addressInfo = await _wallet.address(index: newIndex);

    final address = Address.liquid(
      index: addressInfo.index,
      address: addressInfo.confidential,
      kind: AddressKind.external,
      state: AddressStatus.unused,
    );

    return address;
  }

  @override
  Future<Address> getAddressByIndex(int index) async {
    final addressInfo = await _wallet.address(index: index);

    final address = Address.liquid(
      index: addressInfo.index,
      address: addressInfo.confidential,
      kind: AddressKind.external,
      state: AddressStatus.used,
      // TODO: add more fields
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress() async {
    final addressInfo = await _wallet.addressLastUnused();

    final address = Address.liquid(
      index: addressInfo.index,
      address: addressInfo.confidential,
      kind: AddressKind.external,
      state: AddressStatus.unused,
      // TODO: add more fields
    );

    return address;
  }

  @override
  Future<void> sync() async {
    await _wallet.sync(
      electrumUrl: _electrumUrl,
      validateDomain: _validateElectrumDomain,
    );
  }
}

extension NetworkX on Network {
  lwk.Network get lwkNetwork {
    switch (this) {
      case Network.liquidMainnet:
        return lwk.Network.mainnet;
      case Network.liquidTestnet:
        return lwk.Network.testnet;
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        throw UnsupportedLwkNetworkException(
          'Bitcoin network is not supported by LWK',
        );
    }
  }
}

class UnsupportedLwkNetworkException implements Exception {
  final String message;

  UnsupportedLwkNetworkException(this.message);
}
