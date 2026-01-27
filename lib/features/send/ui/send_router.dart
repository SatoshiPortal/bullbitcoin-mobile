import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_screen.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

enum SendRoute {
  send('/send'),
  requestIdentifier('request-identifier');

  const SendRoute(this.path);

  final String path;
}

class SendRouter {
  static final route = GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      // Pass a preselected wallet to the send bloc if one is set in the URI
      //  of the incoming route
      final wallet = state.extra is Wallet ? state.extra! as Wallet : null;
      return BlocProvider(
        create: (_) =>
            sl<SendCubit>(param1: wallet)..loadWalletWithRatesAndFees(),
        child: const SendScreen(),
      );
    },
    routes: [
      GoRoute(
        name: SendRoute.requestIdentifier.name,
        path: SendRoute.requestIdentifier.path,
        builder: (context, state) => BlocProvider(
          create: (_) => RequestIdentifierCubit(),
          child: const RequestIdentifierScreen(),
        ),
      ),
    ],
  );
}
