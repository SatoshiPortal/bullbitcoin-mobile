import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Outpoint, Result;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;

/// Loads a wallet's values at its latest committed revision, or throws
/// [WalletSnapshotException] with the typed failure.
typedef LoadWallet = Future<sync.Wallet> Function(sync.WalletKey key);

/// The wallet values the app reads, from the values `sync` publishes, shaped
/// into the app's models. No native handle is involved.
class SyncWalletValuesDatasource {
  final LoadWallet _load;

  SyncWalletValuesDatasource({required this._load});

  static sync.WalletKey _key(WalletModel wallet) =>
      sync.WalletKey(id: wallet.id, network: wallet.network.shared);

  Future<sync.Wallet> _wallet(WalletModel wallet) => _load(_key(wallet));

  /// Data of a value read right after its load, or the reason it has none.
  static D _data<D extends Object>(sync.WalletValue<D> value) =>
      switch (value) {
        sync.WalletValue(status: sync.ValueStatus.ready, :final data?) ||
        sync.WalletValue(status: sync.ValueStatus.stale, :final data?) => data,
        sync.WalletValue(:final failure) => throw WalletSnapshotException(
          failure ?? const sync.SyncBusyFailure(),
        ),
      };

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    final balances = _data((await _wallet(wallet)).balances.now);
    return BalanceModel(
      confirmedSat: balances.confirmedSat,
      immatureSat: balances.immatureSat,
      trustedPendingSat: balances.trustedPendingSat,
      untrustedPendingSat: balances.untrustedPendingSat,
      spendableSat: balances.spendableSat,
      totalSat: balances.totalSat,
    );
  }

  Future<List<WalletUtxoModel>> getUtxos({
    required WalletModel wallet,
  }) async => [
    for (final coin in _data((await _wallet(wallet)).coins.now)) _utxo(coin),
  ];

  /// The coins with their frozen state, as sync publishes them. Throws
  /// while the freezes are unknown: a coin never reads as unfrozen.
  Future<List<({WalletUtxoModel model, bool frozen})>> getCoins({
    required WalletModel wallet,
  }) async => [
    for (final coin in _data((await _wallet(wallet)).coins.now))
      (model: _utxo(coin), frozen: coin.frozen),
  ];

  /// Number of L-BTC coins, the count that matters for LWK's input limit.
  Future<int> getLbtcUtxoCount({required WalletModel wallet}) async =>
      _data((await _wallet(wallet)).coins.now).length;

  /// The unspent coins exactly at the latest committed revision, for a
  /// protocol decision. Retries briefly while the writer is busy.
  Future<List<WalletUtxoModel>> getExactUtxos({
    required WalletModel wallet,
  }) async {
    final handle = await _wallet(wallet);
    final coins = await _exact(handle.unspent);
    return [for (final coin in coins) _utxo(coin)];
  }

  /// Exact ownership at the latest committed revision: scripts the index
  /// derives and outputs held, spent ones included. Retries briefly while
  /// the writer is busy; never answers from an older revision.
  Future<sync.OwnershipIndex> getOwnership({
    required WalletModel wallet,
  }) async {
    final handle = await _wallet(wallet);
    return _exact(handle.ownership);
  }

  Future<bool> isMine(Uint8List script, {required WalletModel wallet}) async =>
      (await getOwnership(wallet: wallet)).ownsScript(script);

  Future<bool> areAddressesMine(
    List<String> addresses, {
    required WalletModel wallet,
  }) async {
    final network = wallet.network.shared;
    if (network is! BitcoinNetwork) {
      throw const WalletSnapshotException(sync.SyncUnsupportedNetworkFailure());
    }
    final ownership = await getOwnership(wallet: wallet);
    for (final address in addresses) {
      switch (sync.bitcoinAddressScript(address, network)) {
        case Ok(value: final script) when ownership.ownsScript(script):
          continue;
        case Ok():
          return false;
        case Err(:final failure):
          throw WalletSnapshotException(failure);
      }
    }
    return true;
  }

  /// Bitcoin: last revealed index of the keychain, -1 when none. Liquid: the
  /// last unused external index; Liquid exposes no change keychain.
  Future<int> getLastAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final book = _data((await _wallet(wallet)).addresses.book.now);
    if (!isChange) return book.receiveIndex;
    final change = book.changeIndex;
    if (change == null) {
      throw const WalletSnapshotException(sync.SyncUnsupportedNetworkFailure());
    }
    return change;
  }

  /// Bitcoin address, or Liquid confidential address, at [index].
  Future<String> getAddressByIndex(
    int index, {
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final handle = await _wallet(wallet);
    final value = await handle.addresses
        .at(
          index,
          // Liquid has no change keychain; its index is always external.
          keychain: isChange && wallet is PublicBdkWalletModel
              ? sync.Keychain.internal
              : sync.Keychain.external,
        )
        .watch()
        .firstWhere((value) => value.status != sync.ValueStatus.notLoaded);
    return _data(value).address;
  }

  /// Balance per address, from the coins: Bitcoin address, Liquid
  /// confidential address.
  Future<Map<String, BigInt>> getAddressBalancesSat({
    required WalletModel wallet,
  }) async {
    final balances = <String, BigInt>{};
    for (final coin in _data((await _wallet(wallet)).coins.now)) {
      final address = switch (coin) {
        sync.BitcoinCoin(:final address) => address,
        sync.LiquidCoin(:final confidentialAddress) => confidentialAddress,
      };
      if (address == null) continue;
      balances[address] = (balances[address] ?? BigInt.zero) + coin.amountSat;
    }
    return balances;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final handle = await _wallet(wallet);
    // Both values come from one frame: no await between the two reads.
    final transactions = _data(handle.transactions.now);
    final book = _data(handle.addresses.book.now);
    final filter = toAddress != null && toAddress.isNotEmpty ? toAddress : null;
    final result = switch (wallet) {
      PublicBdkWalletModel() => _bitcoinHistory(
        transactions.whereType<sync.BitcoinTransaction>().toList(),
        network: wallet.network,
        toAddress: filter,
      ),
      PublicLwkWalletModel() => _liquidHistory(
        transactions.whereType<sync.LiquidTransaction>().toList(),
        book,
        network: wallet.network,
        toAddress: filter,
      ),
    };
    return result;
  }

  static Future<T> _exact<T>(
    Future<Result<T, sync.SyncFailure>> Function() query,
  ) async {
    for (var attempt = 1; ; attempt++) {
      switch (await query()) {
        case Ok(:final value):
          return value;
        case Err(failure: sync.SyncBusyFailure()) when attempt < 5:
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        case Err(:final failure):
          throw WalletSnapshotException(failure);
      }
    }
  }

  /// The wallet cannot price a transaction whose previous outputs it does not
  /// know; its history fails as a whole, as it did before sync published it.
  static int _feeOf(sync.ChainTransaction tx) =>
      tx.feeSat ??
      (throw const WalletSnapshotException(sync.SyncNeedsRepairFailure()));

  static WalletUtxoModel _utxo(sync.Coin coin) => switch (coin) {
    sync.BitcoinCoin() => WalletUtxoModel.bitcoin(
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: Uint8List.fromList(coin.scriptPubkey),
      // A wallet coin always has an address form; keep the old fallback.
      address: coin.address ?? '',
      isExternalKeyChain: coin.keychain == sync.Keychain.external,
      confirmations: coin.confirmations,
    ),
    sync.LiquidCoin() => WalletUtxoModel.liquid(
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: coin.scriptPubkey,
      standardAddress: coin.standardAddress,
      confidentialAddress: coin.confidentialAddress,
      blockHeight: coin.blockHeight,
    ),
  };

  static List<WalletTransactionModel> _bitcoinHistory(
    List<sync.BitcoinTransaction> transactions, {
    required Network network,
    String? toAddress,
  }) {
    final allOutputs = <Outpoint, bool>{
      for (final tx in transactions)
        for (final output in tx.outputs)
          (txId: tx.txid, vout: output.vout): output.isOwn,
    };
    return [
      for (final tx in transactions)
        if (toAddress == null ||
            tx.outputs.any((output) => output.address == toAddress))
          _bitcoinTransaction(tx, allOutputs, network),
    ];
  }

  static WalletTransactionModel _bitcoinTransaction(
    sync.BitcoinTransaction tx,
    Map<Outpoint, bool> allOutputs,
    Network network,
  ) {
    final inputs = [
      for (var vin = 0; vin < tx.inputs.length; vin++)
        TransactionInputModel.bitcoin(
          txId: tx.txid,
          vin: vin,
          isOwn: allOutputs[tx.inputs[vin].previousOutput] ?? false,
          scriptSig: Uint8List.fromList(tx.inputs[vin].scriptSig),
          previousTxId: tx.inputs[vin].previousOutput.txId,
          previousTxVout: tx.inputs[vin].previousOutput.vout,
        ),
    ];
    final outputs = [
      for (final output in tx.outputs)
        TransactionOutputModel.bitcoin(
              txId: tx.txid,
              vout: output.vout,
              isOwn: output.isOwn,
              value: output.valueSat,
              scriptPubkey: Uint8List.fromList(output.scriptPubkey),
              address: output.address,
              isChange: output.isChange,
            )
            as BitcoinTransactionOutputModel,
    ];
    final isToSelf =
        inputs.every((input) => input.isOwn) &&
        outputs.every((output) => output.isOwn);
    final isIncoming = tx.receivedSat > tx.sentSat;
    return WalletTransactionModel(
      txId: tx.txid,
      isIncoming: isIncoming,
      amountSat: bitcoinNetAmountSat(
        isToSelf: isToSelf,
        isIncoming: isIncoming,
        outputs: outputs,
        sent: tx.sentSat,
        received: tx.receivedSat,
        fee: _feeOf(tx),
      ),
      feeSat: _feeOf(tx),
      vsize: tx.vsize,
      confirmationTimestamp: tx.confirmationTime,
      isToSelf: isToSelf,
      inputs: inputs,
      outputs: outputs,
      network: network,
      isRbf: tx.isExplicitlyRbf,
    );
  }

  /// The amount to show for a transaction, from this wallet's point of view.
  static int bitcoinNetAmountSat({
    required bool isToSelf,
    required bool isIncoming,
    required List<BitcoinTransactionOutputModel> outputs,
    required int sent,
    required int received,
    required int fee,
  }) {
    if (isToSelf) {
      // `sent` is the whole utxo we spent, not what we paid: coin selection
      // spends whole utxos and hands the rest back as change.
      final toDestination = outputs
          .where((output) => !output.isChange)
          .fold(0, (sum, output) => sum + (output.value?.toInt() ?? 0));
      // Nothing paid out — a consolidation. The fee is the only balance change.
      return toDestination > 0 ? toDestination : fee;
    }

    // The sender paid the fee, so it never left this balance.
    if (isIncoming) return received - sent;

    // We paid the fee, so take it off to leave what reached the recipient.
    return sent - received - fee;
  }

  static List<WalletTransactionModel> _liquidHistory(
    List<sync.LiquidTransaction> transactions,
    sync.AddressBook book, {
    required Network network,
    String? toAddress,
  }) {
    final used = <String>{
      for (final address in book.receive) ...[
        address.address,
        ?address.standardAddress,
      ],
    };
    bool isWallet(sync.LiquidTxOut out) =>
        used.contains(out.standardAddress) ||
        used.contains(out.confidentialAddress);
    final result = <WalletTransactionModel>[];
    for (final tx in transactions) {
      if (toAddress != null &&
          !tx.outputs.any(
            (output) =>
                output.standardAddress == toAddress ||
                output.confidentialAddress == toAddress,
          )) {
        continue;
      }
      final isIncoming = tx.kind == 'incoming';
      final finalBalance = tx.policyBalanceSat;
      final isToSelf =
          tx.kind == 'redeposit' || finalBalance.abs() == _feeOf(tx);
      var changeAmountInToSelf = 0;
      final inputs = [
        for (var vin = 0; vin < tx.inputs.length; vin++)
          TransactionInputModel.liquid(
            txId: tx.txid,
            vin: vin,
            isOwn: isToSelf || isWallet(tx.inputs[vin]),
            value: tx.inputs[vin].valueSat,
            scriptPubkey: tx.inputs[vin].scriptPubkey,
            previousTxId: tx.inputs[vin].outpoint.txId,
            previousTxVout: tx.inputs[vin].outpoint.vout,
          ),
      ];
      final outputs = <TransactionOutputModel>[];
      for (var vout = 0; vout < tx.outputs.length; vout++) {
        final output = tx.outputs[vout];
        final owned = isWallet(output);
        if (isToSelf && !owned) {
          changeAmountInToSelf += output.valueSat.toInt();
        }
        outputs.add(
          TransactionOutputModel.liquid(
            txId: tx.txid,
            vout: vout,
            isOwn: isToSelf || owned,
            value: output.valueSat,
            scriptPubkey: output.scriptPubkey,
            address: output.confidentialAddress,
          ),
        );
      }
      final sumOutputs = outputs
          .map((output) => output.value?.toInt() ?? 0)
          .fold(0, (int a, b) => a + b);
      final toDestination = sumOutputs - changeAmountInToSelf;
      // LWK lists only this wallet's outputs and cannot list change
      // addresses, so a redeposit to an unlisted address of the wallet has
      // no recognised destination. With a single L-BTC output, that output
      // is the destination; any other ambiguous case stays unresolved.
      final sole = tx.outputs.length == 1 ? tx.outputs.first : null;
      final soleRedepositSat =
          tx.kind == 'redeposit' && sole != null && sole.isPolicyAsset
          ? sole.valueSat.toInt()
          : null;
      final netAmountSat = isToSelf
          ? toDestination == 0
                ? soleRedepositSat ?? 0
                : toDestination
          : isIncoming
          ? finalBalance
          : finalBalance.abs() - _feeOf(tx);
      result.add(
        WalletTransactionModel(
          txId: tx.txid,
          isIncoming: isIncoming,
          amountSat: netAmountSat,
          feeSat: _feeOf(tx),
          vsize: tx.vsize,
          confirmationTimestamp: tx.confirmationTime,
          isToSelf: isToSelf,
          inputs: inputs,
          outputs: outputs,
          network: network,
          unblindedUrl: tx.unblindedUrl,
          isRbf: false,
        ),
      );
    }
    return result;
  }
}
