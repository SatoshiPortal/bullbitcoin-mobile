import 'dart:math';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../domain/sync_failure.dart';
import '../../domain/wallet_revision.dart';
import '../../domain/wallet_values.dart';
import '../wallet_projections.dart';
import 'wallet_snapshot_reader.dart' show WalletSnapshotException;

/// Confirmation count for an output confirmed at [height], given the wallet's
/// [tip]. Null (unconfirmed) is 0; clamped to 0 when a reorg or mid-sync
/// window puts the tip below the height.
int confirmationsFromTip({required int tip, required int? height}) {
  if (height == null) return 0;
  return max(0, tip - height + 1);
}

/// The lookahead the reader loads Bitcoin wallets with.
const bitcoinLookahead = 25;

/// Maps a hydrated Bitcoin reader handle into frame data. Reads only:
/// nothing is revealed or persisted, and the handle stays the reader's.
WalletFrameData bitcoinFrameData(bdk.Wallet wallet, WalletRevision revision) {
  final network = wallet.network();
  final balance = wallet.balance();
  final balances = Balances(
    confirmedSat: BigInt.from(balance.confirmed.toSat()),
    immatureSat: BigInt.from(balance.immature.toSat()),
    trustedPendingSat: BigInt.from(balance.trustedPending.toSat()),
    untrustedPendingSat: BigInt.from(balance.untrustedPending.toSat()),
    spendableSat: BigInt.from(balance.trustedSpendable.toSat()),
    totalSat: BigInt.from(balance.total.toSat()),
  );

  // listOutput covers spent outputs too and hits no network.
  final changeOutpoints = <Outpoint>{};
  final ownedOutpoints = <Outpoint>{};
  for (final output in wallet.listOutput()) {
    final outpoint = (
      txId: _txid(output.outpoint.txid),
      vout: output.outpoint.vout,
    );
    ownedOutpoints.add(outpoint);
    if (output.keychain == bdk.KeychainKind.internal) {
      changeOutpoints.add(outpoint);
    }
  }

  final tip = wallet.latestCheckpoint().height;
  final coins = [
    for (final unspent in wallet.listUnspent())
      BitcoinCoin(
        outpoint: (
          txId: _txid(unspent.outpoint.txid),
          vout: unspent.outpoint.vout,
        ),
        amountSat: BigInt.from(unspent.txout.value.toSat()),
        scriptPubkey: unspent.txout.scriptPubkey.toBytes(),
        address: _address(unspent.txout.scriptPubkey.toBytes(), network),
        keychain: unspent.keychain == bdk.KeychainKind.internal
            ? Keychain.internal
            : Keychain.external,
        confirmations: confirmationsFromTip(
          tip: tip,
          height: switch (unspent.chainPosition) {
            final bdk.ConfirmedChainPosition position =>
              position.confirmationBlockTime.blockId.height,
            _ => null,
          },
        ),
      ),
  ];

  final transactions = <ChainTransaction>[];
  for (final canonical in wallet.transactions()) {
    final tx = canonical.transaction;
    final txid = _txid(tx.computeTxid());
    final outputs = tx.output();
    final sentAndReceived = wallet.sentAndReceived(tx: tx);
    final position = canonical.chainPosition;
    transactions.add(
      BitcoinTransaction(
        txid: txid,
        feeSat: _fee(wallet, tx),
        vsize: tx.vsize(),
        confirmationTime: position is bdk.ConfirmedChainPosition
            ? position.confirmationBlockTime.confirmationTime
            : null,
        inputs: [
          for (final input in tx.input())
            BitcoinInput(
              previousOutput: (
                txId: _txid(input.previousOutput.txid),
                vout: input.previousOutput.vout,
              ),
              scriptSig: input.scriptSig.toBytes(),
            ),
        ],
        outputs: [
          for (var vout = 0; vout < outputs.length; vout++)
            BitcoinOutput(
              vout: vout,
              valueSat: BigInt.from(outputs[vout].value.toSat()),
              scriptPubkey: outputs[vout].scriptPubkey.toBytes(),
              address: _address(outputs[vout].scriptPubkey.toBytes(), network),
              isOwn: wallet.isMine(script: outputs[vout].scriptPubkey),
              isChange: changeOutpoints.contains((txId: txid, vout: vout)),
            ),
        ],
        sentSat: sentAndReceived.sent.toSat(),
        receivedSat: sentAndReceived.received.toSat(),
        isExplicitlyRbf: tx.isExplicitlyRbf(),
      ),
    );
  }

  final receive = <DerivedAddress>[];
  final change = <DerivedAddress>[];
  final scripts = <Uint8List>[];
  for (final (keychain, kind, list) in [
    (Keychain.external, bdk.KeychainKind.external_, receive),
    (Keychain.internal, bdk.KeychainKind.internal, change),
  ]) {
    final next = wallet.nextDerivationIndex(keychain: kind);
    // Revealed scripts plus the lookahead the index derives beyond them.
    for (var index = 0; index < next + bitcoinLookahead; index++) {
      final info = wallet.peekAddress(keychain: kind, index: index);
      if (index < next) {
        list.add(
          DerivedAddress(
            keychain: keychain,
            index: index,
            address: info.address.toString(),
          ),
        );
      }
      scripts.add(info.address.scriptPubkey().toBytes());
      info.address.dispose();
    }
  }

  return WalletFrameData(
    revision: revision,
    balances: balances,
    coins: CoinList(coins),
    transactions: ChainTransactionList(transactions),
    addresses: AddressBook(
      receiveIndex: receive.length - 1,
      changeIndex: change.length - 1,
      receive: receive,
      change: change,
    ),
    ownership: OwnershipIndex(
      revision: revision,
      scripts: scripts,
      outpoints: ownedOutpoints,
    ),
  );
}

DerivedAddress bitcoinAddress(bdk.Wallet wallet, Keychain keychain, int index) {
  final info = wallet.peekAddress(
    keychain: keychain == Keychain.external
        ? bdk.KeychainKind.external_
        : bdk.KeychainKind.internal,
    index: index,
  );
  try {
    return DerivedAddress(
      keychain: keychain,
      index: index,
      address: info.address.toString(),
    );
  } finally {
    info.address.dispose();
  }
}

Future<BigInt> liquidPolicyBalance(
  lwk.Wallet wallet, {
  bool Function()? isCurrent,
}) async => _liquidPolicyBalance(
  wallet,
  await wallet.policyAsset(),
  isCurrent: isCurrent,
);

Future<BigInt> _liquidPolicyBalance(
  lwk.Wallet wallet,
  String policy, {
  bool Function()? isCurrent,
}) async {
  if (isCurrent?.call() == false) {
    throw const WalletSnapshotException(SyncClosedFailure());
  }
  return (await wallet.balances())
          .where((balance) => balance.assetId == policy)
          .firstOrNull
          ?.value ??
      (throw const LiquidMappingException('policy asset balance'));
}

/// Maps a hydrated Liquid reader handle into frame data. L-BTC only: coins
/// and balances of other assets are not published.
Future<WalletFrameData> liquidFrameData(
  lwk.Wallet wallet,
  WalletRevision revision,
) async {
  final policy = await wallet.policyAsset();
  final total = await _liquidPolicyBalance(wallet, policy);
  final balances = Balances(
    confirmedSat: total,
    immatureSat: BigInt.zero,
    trustedPendingSat: BigInt.zero,
    untrustedPendingSat: BigInt.zero,
    spendableSat: total,
    totalSat: total,
  );
  final coins = [
    for (final utxo in await wallet.utxos())
      if (utxo.unblinded.asset == policy)
        LiquidCoin(
          outpoint: (txId: utxo.outpoint.txid, vout: utxo.outpoint.vout),
          amountSat: utxo.unblinded.value,
          scriptPubkey: utxo.scriptPubkey,
          standardAddress: utxo.address.standard,
          confidentialAddress: utxo.address.confidential,
          blockHeight: utxo.height,
        ),
  ];
  LiquidTxOut out(lwk.TxOut value) => LiquidTxOut(
    outpoint: (txId: value.outpoint.txid, vout: value.outpoint.vout),
    valueSat: value.unblinded.value,
    scriptPubkey: value.scriptPubkey,
    standardAddress: value.address.standard,
    confidentialAddress: value.address.confidential,
    isPolicyAsset: value.unblinded.asset == policy,
  );
  final transactions = [
    for (final tx in await wallet.txs())
      LiquidTransaction(
        txid: tx.txid,
        feeSat: tx.fee.toInt(),
        vsize: tx.vsize.toInt(),
        confirmationTime: tx.timestamp,
        kind: tx.kind,
        policyBalanceSat:
            tx.balances
                .where((balance) => balance.assetId == policy)
                .map((balance) => balance.value)
                .firstOrNull ??
            0,
        unblindedUrl: tx.unblindedUrl,
        inputs: [for (final input in tx.inputs) out(input)],
        outputs: [for (final output in tx.outputs) out(output)],
      ),
  ];
  final last =
      (await wallet.addressLastUnused()).index ??
      (throw const LiquidMappingException('last unused index'));
  final receive = <DerivedAddress>[
    for (var index = 0; index <= last; index++)
      _liquidAddress(await wallet.address(index: index), index),
  ];
  return WalletFrameData(
    revision: revision,
    balances: balances,
    coins: CoinList(coins),
    transactions: ChainTransactionList(transactions),
    addresses: AddressBook(
      receiveIndex: last,
      changeIndex: null,
      receive: receive,
      change: const [],
    ),
    ownership: null,
  );
}

Future<DerivedAddress> liquidAddress(lwk.Wallet wallet, int index) async =>
    _liquidAddress(await wallet.address(index: index), index);

DerivedAddress _liquidAddress(lwk.Address address, int index) => DerivedAddress(
  keychain: Keychain.external,
  index: index,
  address: address.confidential,
  standardAddress: address.standard,
);

/// LWK returned an incomplete answer; the frame is not published.
final class LiquidMappingException implements Exception {
  final String field;
  const LiquidMappingException(this.field);

  @override
  String toString() => 'LiquidMappingException($field)';
}

/// Null when an input's previous output is unknown to the wallet: one such
/// transaction must not keep the balances and coins from being published.
int? _fee(bdk.Wallet wallet, bdk.Transaction tx) {
  try {
    return wallet.calculateFee(tx: tx).toSat();
  } on bdk.CalculateFeeException {
    return null;
  }
}

/// Consumes a freshly acquired txid, never a shared wallet handle.
String _txid(bdk.Txid txid) {
  try {
    return txid.toString();
  } finally {
    txid.dispose();
  }
}

/// Null for scripts without an address form, such as OP_RETURN.
String? _address(Uint8List script, bdk.Network network) {
  try {
    final address = bdk.Address.fromScript(
      script: bdk.Script(rawOutputScript: script),
      network: network,
    );
    try {
      return address.toString();
    } finally {
      address.dispose();
    }
  } on Exception {
    return null;
  }
}
