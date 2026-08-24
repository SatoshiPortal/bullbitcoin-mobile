import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_screen.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SendRoute {
  send('/send'),
  requestIdentifier('request-identifier');

  const SendRoute(this.path);

  final String path;
}

final class SendRouteArgs {
  final Wallet? wallet;
  final String? pendingTransactionId;

  const SendRouteArgs({this.wallet, this.pendingTransactionId});
}

class SendRouter {
  static final route = GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      // Pass a preselected wallet to the send bloc if one is set in the URI
      //  of the incoming route
      final args = state.extra is SendRouteArgs
          ? state.extra! as SendRouteArgs
          : null;
      final wallet =
          args?.wallet ??
          (state.extra is Wallet ? state.extra! as Wallet : null);
      return _SendRouteView(
        key: state.pageKey,
        wallet: wallet,
        pendingTransactionId: args?.pendingTransactionId,
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

class _SendRouteView extends StatefulWidget {
  final Wallet? wallet;
  final String? pendingTransactionId;

  const _SendRouteView({super.key, this.wallet, this.pendingTransactionId});

  @override
  State<_SendRouteView> createState() => _SendRouteViewState();
}

class _SendRouteViewState extends State<_SendRouteView> {
  late final SendCubit _cubit;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _cubit = locator<SendCubit>(param1: widget.wallet);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _cubit.loadWalletWithRatesAndFees();
    if (widget.pendingTransactionId case final id?) {
      await _cubit.loadPendingTransaction(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.pendingTransactionId == null
        ? const SendScreen()
        : FutureBuilder<void>(
            future: _initialization,
            builder: (_, snapshot) => snapshot.connectionState == .done
                ? const SendScreen()
                : const SendLoadingScreen(),
          );
    return BlocProvider(lazy: false, create: (_) => _cubit, child: child);
  }
}
