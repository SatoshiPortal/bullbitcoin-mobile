import 'package:primitives/primitives.dart';

/// Internal identity, never a signing authorization.
final class PaymentKey {
  final NetworkEnv network;
  final String hash;

  PaymentKey(this.network, this.hash) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('Expected canonical payment hash');
    }
  }
}

final class BoundPaymentRequest {
  final PaymentKey key;
  final String request;
  final int amountMsat;

  BoundPaymentRequest(this.key, this.request, this.amountMsat) {
    if (request.isEmpty ||
        amountMsat <= 0 ||
        amountMsat > 2100000000000000000) {
      throw const FormatException('Invalid bound payment request');
    }
  }
}

final class PaymentSource {
  final String walletId;
  final String rail;
  final int maxDebitSat;

  PaymentSource(this.walletId, this.rail, this.maxDebitSat) {
    if (walletId.isEmpty ||
        !{'liquid', 'bitcoin'}.contains(rail) ||
        maxDebitSat <= 0 ||
        maxDebitSat > 2100000000000000) {
      throw const FormatException('Invalid reviewed source');
    }
  }
}

final class PaymentReview {
  final String policyId;
  final List<PaymentSource> sources;

  PaymentReview(this.policyId, List<PaymentSource> sources)
    : sources = List.unmodifiable(sources) {
    if (policyId.isEmpty ||
        sources.isEmpty ||
        sources.length > 2 ||
        sources.map((s) => s.walletId).toSet().length != sources.length) {
      throw const FormatException('Invalid payment review');
    }
  }
}

enum PaymentStage {
  reviewed,
  preflight,
  preflightRefused,
  creating,
  created,
  fundingSealed,
  pending,
  unknown,
  paid,
}

final class PaymentAttempt {
  final int ordinal;
  final String operationId;
  final int reviewId;
  final PaymentSource source;
  final PaymentStage stage;
  final String? backendReference;
  final String? receiptReference;

  const PaymentAttempt({
    required this.ordinal,
    required this.operationId,
    required this.reviewId,
    required this.source,
    required this.stage,
    this.backendReference,
    this.receiptReference,
  });
}

final class PaymentSnapshot {
  final BoundPaymentRequest request;
  final PaymentReview review;
  final int reviewId;
  final int revision;
  final int attemptCount;
  final PaymentStage stage;
  final int? activeOrdinal;
  final List<PaymentAttempt> attempts;

  PaymentSnapshot({
    required this.request,
    required this.review,
    required this.reviewId,
    required this.revision,
    required this.attemptCount,
    required this.stage,
    required List<PaymentAttempt> attempts,
    required this.activeOrdinal,
  }) : attempts = List.unmodifiable(attempts);
  PaymentAttempt? get active => activeOrdinal == null
      ? null
      : attempts.singleWhere((a) => a.ordinal == activeOrdinal);
}

/// References are correlation data supplied by trusted later integration.
final class PaymentReceipt {
  final NetworkEnv network;
  final String operationId;
  final String walletId;
  final String backendReference;
  final String reference;

  PaymentReceipt({
    required this.network,
    required this.operationId,
    required this.walletId,
    required this.backendReference,
    required this.reference,
  }) {
    if ([
      operationId,
      walletId,
      backendReference,
      reference,
    ].any((s) => s.isEmpty)) {
      throw const FormatException('Empty receipt correlation');
    }
  }
}

enum PreflightRefusalReason {
  insufficientFunds,
  unavailable,
  policyRefused,
  quoteExpired,
}

/// A local preflight fact. Accepted only before create has been sealed.
final class PreflightRefusal {
  final NetworkEnv network;
  final String operationId;
  final String walletId;
  final PreflightRefusalReason reason;
  final String reference;

  PreflightRefusal({
    required this.network,
    required this.operationId,
    required this.walletId,
    required this.reason,
    required this.reference,
  }) {
    if ([operationId, walletId, reference].any((s) => s.isEmpty)) {
      throw const FormatException('Empty preflight correlation');
    }
  }
}
