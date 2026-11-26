import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// Whether the access decision has a signed-in Exchange session.
bool exchangeSignedIn(ExchangeAccess access) => access.isSignedIn;

/// Rebuilds account entry points as the access/session decision changes.
class ExchangeAccessBuilder extends StatelessWidget {
  const ExchangeAccessBuilder({
    required this.exchange,
    required this.builder,
    super.key,
  });

  final Exchange exchange;
  final Widget Function(BuildContext, ExchangeAccess) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<ExchangeAccess>(
    stream: exchange.watchAccess(),
    initialData: exchange.currentAccess,
    builder: (context, snapshot) =>
        builder(context, snapshot.data ?? exchange.currentAccess),
  );
}
