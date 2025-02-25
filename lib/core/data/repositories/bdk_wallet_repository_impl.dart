import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkWalletRepositoryImpl
    implements WalletRepository, BitcoinWalletRepository {
  final String _id;
  final bdk.Wallet _publicWallet;

  BdkWalletRepositoryImpl({
    required String id,
    required bdk.Wallet publicWallet,
  })  : _id = id,
        _publicWallet = publicWallet;

  @override
  String get id => _id;

  @override
  Network get network => _publicWallet.network().network;

  @override
  Future<Balance> getBalance() async {
    final balanceInfo = _publicWallet.getBalance();

    final balance = Balance(
      confirmedSat: balanceInfo.confirmed,
      immatureSat: balanceInfo.immature,
      trustedPendingSat: balanceInfo.trustedPending,
      untrustedPendingSat: balanceInfo.untrustedPending,
      spendableSat: balanceInfo.spendable,
      totalSat: balanceInfo.total,
    );

    return balance;
  }

  @override
  Future<void> sync({
    required String blockchainUrl,
    String? socks5,
    required int retry,
    int? timeout,
    required BigInt stopGap,
    required bool validateDomain,
  }) async {
    final blockchain = await _createBlockchain(
      url: blockchainUrl,
      socks5: socks5,
      retry: retry,
      timeout: timeout,
      stopGap: stopGap,
      validateDomain: validateDomain,
    );

    await _publicWallet.sync(blockchain: blockchain);
  }

  @override
  Future<Address> getAddressByIndex(int index) async {
    final addressInfo = _publicWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
      kind: AddressKind.external,
      state: await _isAddressUsed(addressInfo.address.asString())
          ? AddressStatus.used
          : AddressStatus.unused,
      balanceSat: await _getAddressBalance(addressInfo.address.asString()),
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress() async {
    final addressInfo = _publicWallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
      kind: AddressKind.external,
      state: AddressStatus.unused,
    );

    return address;
  }

  Future<bdk.Blockchain> _createBlockchain({
    required String url,
    String? socks5,
    required int retry,
    int? timeout,
    required BigInt stopGap,
    required bool validateDomain,
  }) async {
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: url,
          socks5: socks5,
          retry: retry,
          timeout: timeout,
          stopGap: stopGap,
          validateDomain: validateDomain,
        ),
      ),
    );

    return blockchain;
  }

  Future<bool> _isAddressUsed(String address) async {
    final txOutputLists = await Future.wait(
      _publicWallet.listTransactions(includeRaw: false).map((tx) async {
        return await tx.transaction?.output() ?? <bdk.TxOut>[];
      }),
    );

    final outputs = txOutputLists.expand((list) => list).toList();
    final isUsed = await Future.any(
      outputs.map((output) async {
        final generatedAddress = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
          network: _publicWallet.network(),
        );
        return generatedAddress.asString() == address;
      }),
    ).catchError((_) => false); // To handle empty lists

    return isUsed;
  }

  Future<BigInt> _getAddressBalance(String address) async {
    final utxos = _publicWallet.listUnspent();
    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      final utxoAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: utxo.txout.scriptPubkey.bytes),
        network: _publicWallet.network(),
      );

      if (utxoAddress.asString() == address) {
        balance += utxo.txout.value;
      }
    }

    return balance;
  }
}

extension BdkNetworkX on bdk.Network {
  Network get network {
    if (this == bdk.Network.bitcoin) {
      return Network.bitcoinMainnet;
    } else {
      return Network.bitcoinTestnet;
    }
  }
}
