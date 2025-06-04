import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange');

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouter {
  static final exchangeHomeRoute = GoRoute(
    name: ExchangeRoute.exchangeHome.name,
    path: ExchangeRoute.exchangeHome.path,
    builder: (context, state) {
      return BlocProvider(
        create: (context) => locator<ExchangeHomeCubit>(),
        child: const ExchangeHomeScreen(),
      );
    },
  );
}
