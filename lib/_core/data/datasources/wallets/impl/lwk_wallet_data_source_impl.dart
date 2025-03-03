import 'package:bb_mobile/_core/data/datasources/wallets/liquid_wallet_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/wallets/wallet_data_source.dart';
import 'package:bb_mobile/_core/data/models/address_model.dart';
import 'package:bb_mobile/_core/data/models/balance_model.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:lwk/lwk.dart' as lwk;

class LwkWalletDataSourceImpl
    implements WalletDataSource, LiquidWalletDataSource {
  final lwk.Network _network;
  final lwk.Wallet _wallet;
  final String _electrumUrl;
  final bool _validateElectrumDomain;

  LwkWalletDataSourceImpl({
    required lwk.Network network,
    required lwk.Wallet wallet,
    required String electrumUrl,
    required bool validateDomain,
  })  : _network = network,
        _wallet = wallet,
        _electrumUrl = electrumUrl,
        _validateElectrumDomain = validateDomain;

  static Future<LwkWalletDataSourceImpl> public({
    required String ctDescriptor,
    required String dbPath,
    required bool isTestnet,
    required ElectrumServerModel electrumServer,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = lwk.Descriptor(
      ctDescriptor: ctDescriptor,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return LwkWalletDataSourceImpl(
      network: network,
      wallet: wallet,
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  static Future<LwkWalletDataSourceImpl> private({
    required String mnemonic,
    required String dbPath,
    required bool isTestnet,
    required ElectrumServerModel electrumServer,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = await lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: network,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return LwkWalletDataSourceImpl(
      network: network,
      wallet: wallet,
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  @override
  Future<BalanceModel> getBalance() async {
    final balances = await _wallet.balances();

    final lBtcAssetBalance = balances.firstWhere((balance) {
      return balance.assetId == _lBtcAssetId;
    }).value;

    final balance = BalanceModel(
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
  Future<AddressModel> getNewAddress() async {
    final lastUnusedAddressInfo = await _wallet.addressLastUnused();
    final newIndex = lastUnusedAddressInfo.index + 1;
    final addressInfo = await _wallet.address(index: newIndex);

    final address = AddressModel(
      index: addressInfo.index,
      address: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<AddressModel> getAddressByIndex(int index) async {
    final addressInfo = await _wallet.address(index: index);

    final address = AddressModel(
      index: addressInfo.index,
      address: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<AddressModel> getLastUnusedAddress() async {
    final addressInfo = await _wallet.addressLastUnused();

    final address = AddressModel(
      index: addressInfo.index,
      address: addressInfo.confidential,
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

  @override
  Future<BigInt> getAddressBalanceSat(String address) async {
    final utxos = await _wallet.utxos();
    final blindingKey = await _wallet.blindingKey();

    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      if (utxo.unblinded.asset != _lBtcAssetId) {
        continue;
      }

      final utxoAddress = await lwk.Address.addressFromScript(
        network: _network,
        script: utxo.scriptPubkey,
        blindingKey: blindingKey,
      );

      if (utxoAddress.confidential == address ||
          utxoAddress.standard == address) {
        balance += utxo.unblinded.value;
      }
    }

    return balance;
  }

  @override
  Future<bool> isAddressUsed(String address) async {
    final txs = await _wallet.txs();
    final txOutputLists = txs.map((tx) => tx.outputs).toList();

    final outputs = txOutputLists.expand((list) => list).toList();
    final isUsed = await Future.any(
      outputs.map((output) async {
        final outputAddress = await lwk.Address.addressFromScript(
          script: output.scriptPubkey,
          network: _network,
          blindingKey: await _wallet.blindingKey(),
        );
        return outputAddress.confidential == address ||
            outputAddress.standard == address;
      }),
    ).catchError((_) => false); // To handle empty lists

    return isUsed;
  }

  String get _lBtcAssetId =>
      _network == lwk.Network.testnet ? lwk.lTestAssetId : lwk.lBtcAssetId;
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
