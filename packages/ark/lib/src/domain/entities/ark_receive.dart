import 'package:primitives/primitives.dart';

import 'ark_quote.dart';

sealed class ArkReceiveRequest {
  const ArkReceiveRequest();
  factory ArkReceiveRequest.arkAddress({Sats? amount, String? message}) =
      ArkAddressReceiveRequest;
  factory ArkReceiveRequest.bolt11({
    required Sats amount,
    String? description,
    int? expirySeconds,
  }) = ArkBolt11ReceiveRequest;
}

final class ArkAddressReceiveRequest extends ArkReceiveRequest {
  final Sats? amount;
  final String? message;
  const ArkAddressReceiveRequest({this.amount, this.message});
}

final class ArkBolt11ReceiveRequest extends ArkReceiveRequest {
  final Sats amount;
  final String? description;
  final int? expirySeconds;
  ArkBolt11ReceiveRequest({
    required this.amount,
    this.description,
    this.expirySeconds,
  }) {
    requirePositive(amount);
    final expiry = expirySeconds;
    if (expiry != null && expiry <= 0) {
      throw ArgumentError('Invalid invoice expiry');
    }
  }
}

final class ArkReceiveDestination {
  final ArkDestinationKind kind;
  final String value;
  final DateTime? expiresAt;
  final Sats? net;
  final Sats? fee;
  ArkReceiveDestination({
    required this.kind,
    required this.value,
    this.expiresAt,
    this.net,
    this.fee,
  }) {
    if (value.isEmpty || kind == ArkDestinationKind.bitcoin) {
      throw ArgumentError('Invalid receive destination');
    }
  }
}
