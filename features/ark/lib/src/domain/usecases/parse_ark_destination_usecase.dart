import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';

/// Classifies a request for the native quote validator. This is not proof an
/// Ark address belongs to a server or that an invoice can be paid. Those checks
/// belong to quote; offline validation never invents a spend authorization.
final class ParseArkDestinationUsecase {
  const ParseArkDestinationUsecase();
  Result<ArkPaymentDestination, ArkFailure> execute(
    String input, {
    required BitcoinNetwork network,
  }) {
    final value = input.trim();
    final lower = value.toLowerCase();
    if (value.isEmpty ||
        value.length > 10000 ||
        value.contains(RegExp(r'\s'))) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (isArkAddress(value, network: network)) {
      return Ok(
        ArkPaymentDestination(kind: ArkDestinationKind.ark, value: value),
      );
    }
    final invoice = lower.startsWith('lightning:')
        ? value.substring(10)
        : value;
    if (RegExp(
      r'^ln(bc|tb|bcrt)[0-9a-z]+$',
      caseSensitive: false,
    ).hasMatch(invoice)) {
      return Ok(
        ArkPaymentDestination(kind: ArkDestinationKind.bolt11, value: invoice),
      );
    }
    return const Err(ArkInvalidRequestFailure());
  }
}
