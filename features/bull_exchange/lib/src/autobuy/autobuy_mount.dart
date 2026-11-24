import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

import '../default_wallets/default_wallets_payout_fields.dart';
import 'domain/usecases/get_autobuy_status_usecase.dart';
import 'domain/usecases/set_autobuy_usecase.dart';
import 'presentation/autobuy_cubit.dart';
import 'ui/screens/autobuy_screen.dart';
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

GoRoute autoBuyRoute(AutoBuyHost host) => GoRoute(
  name: AutoBuyNavigation.routeName,
  path: AutoBuyNavigation.path,
  builder: (_, _) {
    final capability = host.exchange();
    return BlocProvider(
      create: (_) =>
          _autoBuyCubit(capability, host.preferences())..loadStatus(),
      child: AutoBuyScreen(
        exchange: capability,
        payoutFields: host.payoutFields,
        addressViewer: host.addressViewer,
        terms: host.terms,
      ),
    );
  },
);

class ExchangeAutoBuyCard extends StatelessWidget {
  final Exchange Function() exchange;
  final Preferences Function() preferences;
  final bool isActive;
  final bool isRestricted;
  final Future<void> Function() onStatusChanged;

  const ExchangeAutoBuyCard({
    required this.exchange,
    required this.preferences,
    required this.isActive,
    required this.isRestricted,
    required this.onStatusChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _autoBuyCubit(exchange(), preferences()),
    child: AutoBuyHomeCard(
      isActive: isActive,
      isRestricted: isRestricted,
      onActivate: () async {
        await AutoBuyNavigation.open(context);
        if (context.mounted) await onStatusChanged();
      },
      onStatusChanged: onStatusChanged,
    ),
  );
}

AutoBuyCubit _autoBuyCubit(Exchange exchange, Preferences preferences) =>
    AutoBuyCubit(
      SetAutoBuyUsecase(preferences, exchange),
      GetAutoBuyStatusUsecase(exchange),
    );
