import 'package:primitives/primitives.dart';

import 'ark_account.dart';

enum ArkOperationKind {
  payment,
  renewal,
  emergencyExit,
  exitProgress,
  claim,
  board,
}

enum ArkDestinationKind { ark, bolt11, bitcoin }

final class ArkPaymentDestination {
  final ArkDestinationKind kind;
  final String value;
  ArkPaymentDestination({required this.kind, required this.value}) {
    if (value.isEmpty || value.trim() != value) {
      throw ArgumentError('Invalid payment destination');
    }
  }
}

sealed class ArkQuoteRequest {
  const ArkQuoteRequest();
  factory ArkQuoteRequest.payment({
    required ArkPaymentDestination destination,
    required Sats amount,
  }) = ArkPaymentQuoteRequest;
  factory ArkQuoteRequest.renewal({required List<String> ids}) =
      ArkRenewalQuoteRequest;
  factory ArkQuoteRequest.emergencyExit({
    required List<String> ids,
    required String destination,
    required FeeRate feeRate,
    required Sats maxClaimFee,
  }) = ArkEmergencyExitQuoteRequest;
  factory ArkQuoteRequest.exitProgress({required FeeRate feeRate}) =
      ArkExitProgressQuoteRequest;
  factory ArkQuoteRequest.claim({
    required List<String> ids,
    required String destination,
    required Sats maxFee,
  }) = ArkClaimQuoteRequest;
  factory ArkQuoteRequest.board({required Sats amount}) = ArkBoardQuoteRequest;
}

final class ArkPaymentQuoteRequest extends ArkQuoteRequest {
  final ArkPaymentDestination destination;
  final Sats amount;
  ArkPaymentQuoteRequest({required this.destination, required this.amount}) {
    requirePositive(amount);
  }
}

final class ArkRenewalQuoteRequest extends ArkQuoteRequest {
  final List<String> ids;
  ArkRenewalQuoteRequest({required List<String> ids}) : ids = validateIds(ids);
}

final class ArkEmergencyExitQuoteRequest extends ArkQuoteRequest {
  final List<String> ids;
  final String destination;
  final FeeRate feeRate;
  final Sats maxClaimFee;
  ArkEmergencyExitQuoteRequest({
    required List<String> ids,
    required this.destination,
    required this.feeRate,
    required this.maxClaimFee,
  }) : ids = validateIds(ids) {
    if (destination.isEmpty) throw ArgumentError('Missing exit destination');
  }
}

final class ArkExitProgressQuoteRequest extends ArkQuoteRequest {
  final FeeRate feeRate;
  const ArkExitProgressQuoteRequest({required this.feeRate});
}

final class ArkClaimQuoteRequest extends ArkQuoteRequest {
  final List<String> ids;
  final String destination;
  final Sats maxFee;
  ArkClaimQuoteRequest({
    required List<String> ids,
    required this.destination,
    required this.maxFee,
  }) : ids = validateIds(ids) {
    if (destination.isEmpty) throw ArgumentError('Missing claim destination');
  }
}

final class ArkBoardQuoteRequest extends ArkQuoteRequest {
  final Sats amount;
  ArkBoardQuoteRequest({required this.amount}) {
    requirePositive(amount);
  }
}

final class ArkQuote {
  final String id;
  final ArkAccountId account;
  final int generation;
  final Uri chainSource;
  final int configGeneration;
  final ArkOperationKind kind;
  final Sats amount;
  final Sats fee;
  final Sats net;
  final List<String> selectedIds;
  final List<String> reserveOutpoints;
  final String? destination;
  final ArkDestinationKind? destinationKind;
  final int observedTip;
  final DateTime validUntil;
  final FeeRate? feeRate;
  final Sats? confirmedReserveExposure;
  final Sats? maxClaimFee;

  ArkQuote({
    required this.id,
    required this.account,
    required this.generation,
    required this.chainSource,
    required this.configGeneration,
    required this.kind,
    required this.amount,
    required this.fee,
    required this.net,
    List<String> selectedIds = const [],
    List<String> reserveOutpoints = const [],
    this.destination,
    this.destinationKind,
    required this.observedTip,
    required this.validUntil,
    this.feeRate,
    this.confirmedReserveExposure,
    this.maxClaimFee,
  }) : selectedIds = List.unmodifiable(selectedIds),
       reserveOutpoints = List.unmodifiable(reserveOutpoints) {
    if (id.isEmpty || generation < 0 || observedTip < 0) {
      throw ArgumentError('Invalid quote identity or observation');
    }
  }
}

List<String> validateIds(List<String> ids) {
  if (ids.isEmpty ||
      ids.any((id) => id.isEmpty) ||
      ids.toSet().length != ids.length) {
    throw ArgumentError('Explicit distinct VTXO ids required');
  }
  return List.unmodifiable(ids);
}

void requirePositive(Sats amount) {
  if (amount.value == BigInt.zero ||
      amount.value > BigInt.from(2100000000000000)) {
    throw ArgumentError('Positive amount required');
  }
}
