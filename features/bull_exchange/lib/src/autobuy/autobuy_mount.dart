import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

import '../account/domain/usecases/get_user_summary_usecase.dart';
import '../default_wallets/default_wallets_payout_fields.dart';
import 'domain/usecases/load_autobuy_context_usecase.dart';
import 'domain/usecases/save_autobuy_preference_usecase.dart';
import 'presentation/autobuy_bloc.dart';
import 'domain/autobuy_switch.dart';
import 'ui/autobuy_flow_shell.dart';
import 'ui/widgets/autobuy_home_card.dart';

typedef AutoBuyHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  DefaultWalletsPayoutFields payoutFields,
  Widget Function(BuildContext, String) addressViewer,
  Uri terms,
});

abstract final class AutoBuyNavigation {
  static const routeName = 'autoBuy';
  static const path = '/auto-buy';

  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(routeName);
}

/// One route: the flow's page is a function of its state.
GoRoute autoBuyRoute(AutoBuyHost host) => GoRoute(
  name: AutoBuyNavigation.routeName,
  path: AutoBuyNavigation.path,
  builder: (_, _) {
    final exchange = host.exchange();
    return BlocProvider(
      create: (_) {
        final getUserSummary = GetUserSummaryUsecase(exchange);
        return AutoBuyFlowBloc(
          session: exchange.currentSession,
          accessChanges: exchange.watchAccess(),
          loadContext: LoadAutoBuyContextUsecase(exchange, getUserSummary),
          saveAutoBuy: SaveAutoBuyPreferenceUsecase(exchange),
          getUserSummary: getUserSummary,
        );
      },
      child: AutoBuyFlowShell(
        host: (
          exchange: exchange,
          payoutFields: host.payoutFields,
          addressViewer: host.addressViewer,
          terms: host.terms,
        ),
      ),
    );
  },
);

class ExchangeAutoBuyCard extends StatefulWidget {
  final Exchange Function() exchange;
  final bool isActive;
  final bool isRestricted;
  final Future<void> Function() onStatusChanged;

  const ExchangeAutoBuyCard({
    required this.exchange,
    required this.isActive,
    required this.isRestricted,
    required this.onStatusChanged,
    super.key,
  });

  @override
  State<ExchangeAutoBuyCard> createState() => _ExchangeAutoBuyCardState();
}

class _ExchangeAutoBuyCardState extends State<ExchangeAutoBuyCard> {
  late final AutoBuySwitchBloc _bloc = () {
    final exchange = widget.exchange();
    return AutoBuySwitchBloc(
      session: exchange.currentSession,
      saveAutoBuy: SaveAutoBuyPreferenceUsecase(exchange),
      getUserSummary: GetUserSummaryUsecase(exchange),
      active: widget.isActive,
      restricted: widget.isRestricted,
      onAccountChanged: widget.onStatusChanged,
    );
  }();

  @override
  void didUpdateWidget(ExchangeAutoBuyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.isRestricted != widget.isRestricted) {
      _bloc.add(
        SwitchSummaryChanged(
          active: widget.isActive,
          restricted: widget.isRestricted,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _bloc,
    child: AutoBuyHomeCard(
      onActivate: () async {
        await AutoBuyNavigation.open(context);
        if (context.mounted) await widget.onStatusChanged();
      },
    ),
  );
}
