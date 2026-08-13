import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';

enum PayjoinStatus { started, requested, proposed, completed, aborted, expired }

sealed class PayjoinSession {
  final PayjoinStatus status;
  final String id;
  final BitcoinNetwork network;
  final String walletId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Sats? amount;
  final String? originalTransactionId;
  final String? transactionId;
  final bool hasProposal;
  final bool isExchange;

  PayjoinSession({
    required this.status,
    required this.id,
    required this.network,
    required this.walletId,
    required this.createdAt,
    required this.expiresAt,
    this.amount,
    this.originalTransactionId,
    this.transactionId,
    this.hasProposal = false,
    this.isExchange = false,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    if (walletId.trim().isEmpty) {
      throw ArgumentError.value(walletId, 'walletId', 'must not be blank');
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'must be after createdAt',
      );
    }
  }

  String get logRef => logRefForId(id);

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isAborted => status == PayjoinStatus.aborted;
  bool get isExpired => status == PayjoinStatus.expired;
  bool get isOngoing => !isCompleted && !isAborted && !isExpired;
  bool get isTestnet => !network.isMainnet;
  bool get isBitcoin => true;
  bool get isLiquid => false;
  int? get amountSat => amount?.value.toInt();
  String? get originalTxId => originalTransactionId;
  String? get txId => transactionId;

  bool get canManuallyBroadcastOriginal {
    if (isCompleted || isAborted || isExchange) return false;
    return switch (this) {
      PayjoinReceiverSession(:final hasOriginalTransaction) =>
        hasOriginalTransaction,
      PayjoinSenderSession(:final originalTransactionId) =>
        originalTransactionId != null,
    };
  }

  static String logRefForId(String id) {
    final isOpaqueReceiverId =
        id.length == 16 && RegExp(r'^[0-9a-f]{16}$').hasMatch(id);
    if (isOpaqueReceiverId) return id;
    return sha256.convert(utf8.encode(id)).toString().substring(0, 16);
  }
}

final class PayjoinReceiverSession extends PayjoinSession {
  final String payjoinUri;
  final bool hasOriginalTransaction;

  PayjoinReceiverSession({
    required super.status,
    required super.id,
    required super.network,
    required super.walletId,
    required super.createdAt,
    required super.expiresAt,
    required this.payjoinUri,
    this.hasOriginalTransaction = false,
    super.amount,
    super.originalTransactionId,
    super.transactionId,
    super.hasProposal,
    super.isExchange,
  }) {
    if (payjoinUri.trim().isEmpty) {
      throw ArgumentError.value(payjoinUri, 'payjoinUri', 'must not be blank');
    }
  }

  bool get hasOriginalTx => hasOriginalTransaction;
  String get pjUri => payjoinUri;
}

final class PayjoinSenderSession extends PayjoinSession {
  PayjoinSenderSession({
    required super.status,
    required String uri,
    required super.network,
    required super.walletId,
    required super.createdAt,
    required super.expiresAt,
    required super.amount,
    required super.originalTransactionId,
    super.transactionId,
    super.hasProposal,
    super.isExchange,
  }) : super(id: uri);

  String get uri => id;

  @override
  int get amountSat => amount!.value.toInt();

  @override
  String get originalTxId => originalTransactionId!;
}
