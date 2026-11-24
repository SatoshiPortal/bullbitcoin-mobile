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
    String? destination,
    FeeRate? feeRate,
    Sats? maxClaimFee,
  }) = ArkEmergencyExitQuoteRequest;
  factory ArkQuoteRequest.exitProgress({FeeRate? feeRate}) =
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

/// An emergency exit of [ids].
///
/// Without a [destination] the quote is an estimate only: it prices the claim
/// for a placeholder address and can never be confirmed. Without a [feeRate]
/// the native wallet picks the chain's current fast rate, which the quote
/// records so a replay prices the same. Without a [maxClaimFee] the quote
/// allows twice the estimated claim fee, so an ordinary fee rise before the
/// claim does not block it.
final class ArkEmergencyExitQuoteRequest extends ArkQuoteRequest {
  final List<String> ids;
  final String? destination;
  final FeeRate? feeRate;
  final Sats? maxClaimFee;
  ArkEmergencyExitQuoteRequest({
    required List<String> ids,
    this.destination,
    this.feeRate,
    this.maxClaimFee,
  }) : ids = validateIds(ids) {
    final destination = this.destination;
    if (destination != null &&
        (destination.isEmpty || destination.trim() != destination)) {
      throw ArgumentError('Invalid exit destination');
    }
    final maximum = maxClaimFee;
    if (maximum != null && maximum.value <= BigInt.zero) {
      throw ArgumentError('Positive claim fee ceiling required');
    }
  }
}

/// Broadcasts the exit transactions that are due. Without a [feeRate] the
/// native wallet picks the chain's fast rate, which the quote records so a
/// replay prices the same.
final class ArkExitProgressQuoteRequest extends ArkQuoteRequest {
  final FeeRate? feeRate;
  const ArkExitProgressQuoteRequest({this.feeRate});
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

  /// For an emergency exit, the estimated fee of the claim that later sends
  /// the recovered funds to [destination]; it comes out of [amount]. [fee] is
  /// then the exit broadcast fee, paid from the confirmed on-chain reserve.
  final Sats? claimFee;

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
    this.claimFee,
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
