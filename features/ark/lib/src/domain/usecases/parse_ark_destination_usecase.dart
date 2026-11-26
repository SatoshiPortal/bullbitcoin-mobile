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
    if (value.isEmpty ||
        value.length > 10000 ||
        value.codeUnits.any((unit) => unit > 127) ||
        value.contains(RegExp(r'\s'))) {
      return const Err(ArkInvalidRequestFailure());
    }
    final lower = value.toLowerCase();
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
    if (_bitcoinSyntax(value, network)) {
      return Ok(
        ArkPaymentDestination(kind: ArkDestinationKind.bitcoin, value: value),
      );
    }
    return const Err(ArkInvalidRequestFailure());
  }
}

/// Classification only. Native quote validates checksum, network and fees.
/// BIP21 is intentionally excluded: query amounts must not be ignored.
bool _bitcoinSyntax(String value, BitcoinNetwork network) {
  if (value.length > 90) {
    return false;
  }
  final prefix = switch (network) {
    BitcoinNetwork.mainnet => 'bc1',
    BitcoinNetwork.testnet || BitcoinNetwork.signet => 'tb1',
    BitcoinNetwork.regtest => 'bcrt1',
  };
  final lower = value.toLowerCase();
  if ((value == lower || value == value.toUpperCase()) &&
      RegExp(
        '^$prefix'
        r'[ac-hj-np-z02-9]{6,}$',
      ).hasMatch(lower)) {
    return true;
  }
  final legacyPrefix = network.isMainnet ? '[13]' : '[mn2]';
  return RegExp(
    '^$legacyPrefix'
    r'[1-9A-HJ-NP-Za-km-z]{25,34}$',
  ).hasMatch(value);
}
