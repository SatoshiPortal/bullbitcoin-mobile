import 'dart:typed_data';

import 'package:bb_mobile/core/bitcoin/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/material.dart';

class BdkWalletRepositoryImpl
    implements WalletRepository, BitcoinWalletRepository {
  final bdk.Wallet _wallet;

  BdkWalletRepositoryImpl({
    required bdk.Wallet wallet,
  }) : _wallet = wallet;

  static Future<BdkWalletRepositoryImpl> public({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbPath,
  }) async {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: externalDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalDescriptor,
      network: network,
    );

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return BdkWalletRepositoryImpl(
      wallet: wallet,
    );
  }

  static Future<BdkWalletRepositoryImpl> private({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbPath,
  }) async {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final bdkMnemonic = await bdk.Mnemonic.fromString(mnemonic);
    final secretKey = await bdk.DescriptorSecretKey.create(
      network: network,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (scriptType) {
      case ScriptType.bip84:
        external = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip49:
        external = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip44:
        external = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
    }

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return BdkWalletRepositoryImpl(
      wallet: wallet,
    );
  }

  @override
  Future<Balance> getBalance() async {
    final balanceInfo = _wallet.getBalance();

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
  Future<void> sync({required ElectrumServer electrumServer}) async {
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          socks5: electrumServer.socks5,
          retry: electrumServer.retry,
          timeout: electrumServer.timeout,
          stopGap: BigInt.from(electrumServer.stopGap),
          validateDomain: electrumServer.validateDomain,
        ),
      ),
    );
    await _wallet.sync(blockchain: blockchain);
  }

  @override
  Future<Address> getNewAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<Address> getAddressByIndex(int index) async {
    final addressInfo = _wallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<bool> isMine(Uint8List scriptBytes) async {
    final script = bdk.ScriptBuf(bytes: scriptBytes);
    final isMine = _wallet.isMine(script: script);

    return isMine;
  }

  @override
  Future<List<Utxo>> listUnspent() async {
    final unspent = _wallet.listUnspent();
    final utxos = unspent
        .map(
          (unspent) => Utxo(
            scriptPubkey: unspent.txout.scriptPubkey.bytes,
            txId: unspent.outpoint.txid,
            vout: unspent.outpoint.vout,
            value: unspent.txout.value,
          ),
        )
        .toList();
    return utxos;
  }

  @override
  Future<Transaction> buildUnsigned({
    required String address,
    required MinerFee networkFee,
    int? amountSat,
    List<TxInput>? unspendableInputs,
    bool? drain,
    List<TxInput>? selectedInputs,
    bool replaceByFees = true,
  }) async {
    bdk.TxBuilder txBuilder;

    // Get the scriptPubkey from the address
    final bdkAddress = await bdk.Address.fromString(
      s: address,
      network: _wallet.network(),
    );
    final script = bdkAddress.scriptPubkey();

    // Check if the transaction is a drain transaction
    if (drain == true) {
      txBuilder = bdk.TxBuilder().drainWallet().drainTo(script);
    } else {
      if (amountSat == null) {
        throw ArgumentError('amountSat is required');
      }
      txBuilder = bdk.TxBuilder().addRecipient(script, BigInt.from(amountSat));
    }

    if (selectedInputs != null && selectedInputs.isNotEmpty) {
      final selectableOutPoints = selectedInputs
          .map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
          .toList();
      txBuilder.addUtxos(selectableOutPoints);
    }
    if (replaceByFees) txBuilder.enableRbf();

    if (networkFee.isAbsolute) {
      txBuilder = txBuilder.feeAbsolute(BigInt.from(networkFee.value as int));
    } else {
      txBuilder = txBuilder.feeRate(networkFee.value.toDouble());
    }

    // Make sure utxos that are unspendable are not used
    final unspendableOutPoints = unspendableInputs
        ?.map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
        .toList();
    if (unspendableOutPoints != null && unspendableOutPoints.isNotEmpty) {
      // Check if there are unspents that are not in unspendableOutpoints so a transaction can be built
      final unspents = _wallet.listUnspent();
      final unspendableOutPointsSet = unspendableOutPoints.toSet();
      final unspendableUtxos = unspents.where((utxo) {
        return unspendableOutPointsSet.contains(utxo.outpoint);
      }).toList();

      if (unspendableUtxos.length == unspents.length) {
        throw NoSpendableUtxoException(
          'All unspents are unspendable',
        );
      }

      txBuilder = txBuilder.unSpendable(unspendableOutPoints);
    }

    // Finish the transaction building process
    final (psbt, _) = await txBuilder.finish(_wallet);
    return Transaction.fromBdkPsbt(psbt);
  }

  @override
  Future<Transaction> sign(Transaction unsigned) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(
      unsigned.toPsbtBase64(),
    );

    final isFinalized = await _wallet.sign(
      psbt: psbt,
      signOptions: const bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        removePartialSigs: true,
        tryFinalize: true,
        signWithTapInternalKey: false,
        allowGrinding: true,
      ),
    );
    if (!isFinalized) {
      debugPrint('Signed PSBT is not finalized');
    } else {
      debugPrint('Signed PSBT is finalized');
    }

    return Transaction.fromBdkPsbt(psbt);
  }

  @override
  Future<bool> isAddressUsed(String address) async {
    final transactions = _wallet.listTransactions(includeRaw: false);

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = await tx.transaction?.output();
      if (txOutputs != null) {
        for (final output in txOutputs) {
          final generatedAddress = await bdk.Address.fromScript(
            script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
            network: _wallet.network(),
          );

          if (generatedAddress.asString() == address) {
            return true;
          }
        }
      }
    }

    return false;
  }

  @override
  Future<BigInt> getAddressBalanceSat(String address) async {
    final utxos = _wallet.listUnspent();
    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      final utxoAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: utxo.txout.scriptPubkey.bytes),
        network: _wallet.network(),
      );

      if (utxoAddress.asString() == address) {
        balance += utxo.txout.value;
      }
    }

    return balance;
  }

  @override
  Future<List<BaseWalletTransaction>> getTransactions(String walletId) async {
    // TODO: implement getTransactions
    final transactions = _wallet.listTransactions(includeRaw: false);
    final List<BaseWalletTransaction> walletTxs = [];
    for (final tx in transactions) {
      debugPrint(tx.transaction.toString());
      final txid = tx.txid;
      final type = tx.sent == BigInt.from(0) && tx.received > BigInt.from(0)
          ? TxType.receive
          : TxType.send;
      final amount = type == TxType.send
          ? tx.sent.toInt()
          : type == TxType.receive
              ? tx.received.toInt()
              : tx.fee != null
                  ? tx.fee!.toInt()
                  : 0;
      final fees = tx.fee;
      final confirmationDateTime = tx.confirmationTime?.timestamp.toInt() ?? 0;
      final walletTx = BaseWalletTransaction(
        walletId: walletId,
        network: _wallet.network().network,
        txid: txid,
        type: type,
        amount: amount,
        fees: fees?.toInt(),
        confirmationTime: confirmationDateTime != 0
            ? DateTime.fromMillisecondsSinceEpoch(confirmationDateTime * 1000)
            : null,
      );
      walletTxs.add(walletTx);
    }
    return walletTxs;
  }
}

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        throw UnsupportedBdkNetworkException(
          'Liquid network is not supported by BDK',
        );
    }
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

class FailedToSignPsbtException implements Exception {
  final String message;

  FailedToSignPsbtException(this.message);
}

class UnsupportedBdkNetworkException implements Exception {
  final String message;

  UnsupportedBdkNetworkException(this.message);
}

class NoSpendableUtxoException implements Exception {
  final String message;

  NoSpendableUtxoException(this.message);
}
