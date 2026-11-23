import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';

final class ExchangeKycHost {
  final Future<Result<ExchangeKycConfiguration, ExchangeFailure>> Function()
  loadConfiguration;
  final String Function(BuildContext, ExchangeFailure) failureMessage;
  final void Function(BuildContext) onExit;

  const ExchangeKycHost({
    required this.loadConfiguration,
    required this.failureMessage,
    required this.onExit,
  });
}
