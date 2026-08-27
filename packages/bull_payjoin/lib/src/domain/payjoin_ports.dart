import 'dart:typed_data';

import 'package:primitives/primitives.dart';

abstract interface class PayjoinWalletPort {
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  });

  Future<bool Function(Uint8List script)> createOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  });

  /// Answers whether an outpoint belongs to this wallet.
  ///
  /// Deliberately keyed on the outpoint and never on the previous output's
  /// scriptPubKey: in a payjoin proposal that script comes from the sender's
  /// PSBT, so a sender could misdeclare it and make one of our own coins look
  /// foreign to a script-based check. The outpoint is the consensus identity of
  /// the input — forging it means spending a different coin.
  ///
  /// Must answer for every output the wallet has ever owned, spent included, so
  /// the receiver's guard has no gap to reason about.
  Future<bool Function(Outpoint outpoint)> createOutpointOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  });

  Future<String Function(String psbt)> createPsbtProcessor({
    required String walletId,
    required BitcoinNetwork network,
  });

  Future<List<PayjoinUtxo>> spendableUtxos({
    required String walletId,
    required BitcoinNetwork network,
  });
}

abstract interface class PayjoinBlockchainPort {
  Future<void> broadcastTransaction({
    required BitcoinNetwork network,
    required Uint8List transaction,
  });

  Future<void> broadcastPsbt({
    required BitcoinNetwork network,
    required String psbt,
  });
}

/// Live network fee estimation, used only to bound the receiver's exposure.
///
/// Kept apart from [PayjoinBlockchainPort]: broadcasting talks to the chain,
/// estimation talks to a fee source (a user-configurable mempool server), so it
/// is not fully trusted input — every value it returns is clamped before use.
abstract interface class PayjoinFeesPort {
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network});
}

abstract interface class PayjoinTransactionPort {
  Stream<void> watchWallet(String walletId);

  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  });

  Future<void> refreshWallet(String walletId);
}

abstract interface class PayjoinLabelsPort {
  Future<void> labelTransaction({
    required String walletId,
    required String transactionId,
  });
}

abstract interface class PayjoinLegacyDataPort {
  Future<PayjoinLegacySnapshot> readSnapshot();
}

abstract interface class PayjoinLogPort {
  void write(PayjoinLogEvent event);
}

final class PayjoinUtxo {
  final Outpoint outpoint;
  final Sats value;
  final Uint8List scriptPubkey;
  final Uint8List scriptSig;
  final int sequence;
  final List<Uint8List> witness;
  final Uint8List? redeemScript;
  final Uint8List? witnessScript;
  final bool confirmed;

  PayjoinUtxo({
    required this.outpoint,
    required this.value,
    required this.scriptPubkey,
    required this.confirmed,
    Uint8List? scriptSig,
    this.sequence = 0xFFFFFFFF,
    this.witness = const <Uint8List>[],
    this.redeemScript,
    this.witnessScript,
  }) : scriptSig = scriptSig ?? Uint8List(0) {
    if (outpoint.txId.trim().isEmpty) {
      throw ArgumentError.value(
        outpoint.txId,
        'outpoint.txId',
        'must not be blank',
      );
    }
    if (outpoint.vout < 0) {
      throw ArgumentError.value(
        outpoint.vout,
        'outpoint.vout',
        'must not be negative',
      );
    }
    if (value == Sats.zero) {
      throw ArgumentError.value(value, 'value', 'must be greater than zero');
    }
    if (scriptPubkey.isEmpty) {
      throw ArgumentError.value(
        scriptPubkey,
        'scriptPubkey',
        'must not be empty',
      );
    }
    if (sequence < 0 || sequence > 0xFFFFFFFF) {
      throw ArgumentError.value(
        sequence,
        'sequence',
        'must fit an unsigned 32-bit integer',
      );
    }
  }
}

/// The payjoin state readable from the root database, as it actually shipped.
///
/// Carries no policy: the root `settings` payjoin columns only ever existed in
/// schema 14, which was never released (every tag up to v6.12.5 is on 13), so
/// no installation can hold a user-chosen policy to import. A fresh payjoin
/// database is seeded from `PayjoinPolicy.defaults()` instead.
final class PayjoinLegacySnapshot {
  final int sourceSchemaVersion;
  final List<PayjoinLegacySender> senders;
  final List<PayjoinLegacyReceiver> receivers;

  const PayjoinLegacySnapshot({
    required this.sourceSchemaVersion,
    required this.senders,
    required this.receivers,
  });
}

final class PayjoinLegacySender {
  final String uri;
  final bool isTestnet;
  final String protocolState;
  final String walletId;
  final String originalPsbt;
  final String originalTransactionId;
  final int amountSat;
  final int createdAt;
  final int expireAfterSec;
  final String? proposalPsbt;
  final String? transactionId;
  final bool isExpired;
  final bool isCompleted;

  const PayjoinLegacySender({
    required this.uri,
    required this.isTestnet,
    required this.protocolState,
    required this.walletId,
    required this.originalPsbt,
    required this.originalTransactionId,
    required this.amountSat,
    required this.createdAt,
    required this.expireAfterSec,
    required this.proposalPsbt,
    required this.transactionId,
    required this.isExpired,
    required this.isCompleted,
  });
}

final class PayjoinLegacyReceiver {
  final String id;
  final String address;
  final bool isTestnet;
  final String protocolState;
  final String walletId;
  final String payjoinUri;
  final BigInt maximumFeeRateSatPerVbyte;
  final int createdAt;
  final int expireAfterSec;
  final Uint8List? originalTransaction;
  final String? originalTransactionId;
  final int? amountSat;
  final String? proposalPsbt;
  final String? transactionId;
  final bool isExpired;
  final bool isCompleted;

  const PayjoinLegacyReceiver({
    required this.id,
    required this.address,
    required this.isTestnet,
    required this.protocolState,
    required this.walletId,
    required this.payjoinUri,
    required this.maximumFeeRateSatPerVbyte,
    required this.createdAt,
    required this.expireAfterSec,
    required this.originalTransaction,
    required this.originalTransactionId,
    required this.amountSat,
    required this.proposalPsbt,
    required this.transactionId,
    required this.isExpired,
    required this.isCompleted,
  });
}

enum PayjoinLogLevel { debug, info, warning, severe }

enum PayjoinLogCode {
  lifecycle,
  sessionStarted,
  sessionResumed,
  sessionCompleted,
  sessionAborted,
  sessionExpired,
  relayFailure,
  walletFailure,
  signingFailure,
  broadcastFailure,
  storageFailure,
  migrationFailure,
}

final class PayjoinLogEvent {
  final PayjoinLogLevel level;
  final PayjoinLogCode code;
  final String? sessionRef;

  /// What actually went wrong, for the host to report. Carried deliberately:
  /// without it a failure reaches the app as a bare [code], which collapses
  /// every cause behind it into one signature — a locked database, a rejected
  /// broadcast and a failed migration become indistinguishable in crash
  /// reports. Unlike a free-form message this is not composed by the call
  /// site, so it cannot smuggle a session identifier into the logs.
  final Object? error;
  final StackTrace? trace;

  PayjoinLogEvent({
    required this.level,
    required this.code,
    this.sessionRef,
    this.error,
    this.trace,
  }) {
    final sessionRef = this.sessionRef;
    if (sessionRef != null &&
        (sessionRef.length != 16 || sessionRef.contains(RegExp('[^0-9a-f]')))) {
      throw ArgumentError.value(
        sessionRef,
        'sessionRef',
        'must be a privacy-safe 16-character lowercase hex value',
      );
    }
  }
}
