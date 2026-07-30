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

final class PayjoinLegacySnapshot {
  final int sourceSchemaVersion;
  final List<PayjoinLegacySender> senders;
  final List<PayjoinLegacyReceiver> receivers;
  final PayjoinLegacyPolicy policy;

  const PayjoinLegacySnapshot({
    required this.sourceSchemaVersion,
    required this.senders,
    required this.receivers,
    required this.policy,
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
  final bool isAborted;

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
    required this.isAborted,
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
  final bool isAborted;

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
    required this.isAborted,
  });
}

final class PayjoinLegacyPolicy {
  final bool enabled;
  final int minimumAmountSat;
  final int sessionLifetimeSeconds;

  const PayjoinLegacyPolicy({
    required this.enabled,
    required this.minimumAmountSat,
    required this.sessionLifetimeSeconds,
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
  final StackTrace? trace;

  PayjoinLogEvent({
    required this.level,
    required this.code,
    this.sessionRef,
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
