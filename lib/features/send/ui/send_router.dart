import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/public/send_route.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_screen.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendRouter {
  static final route = GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      final args = state.extra is SendRouteArgs
          ? state.extra! as SendRouteArgs
          : null;
      // A raw Wallet remains a supported route payload for regular sends.
      final wallet =
          args?.wallet ??
          (state.extra is Wallet ? state.extra! as Wallet : null);
      return _SendRouteView(
        key: state.pageKey,
        wallet: wallet,
        args: args,
        pendingTransactionId: args?.pendingTransactionId,
        spWalletLabel: args?.isSpMode == true
            ? context.loc.walletSpTitle
            : null,
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
  final SendRouteArgs? args;
  final String? pendingTransactionId;
  final String? spWalletLabel;

  const _SendRouteView({
    super.key,
    this.wallet,
    this.args,
    this.pendingTransactionId,
    this.spWalletLabel,
  });

  @override
  State<_SendRouteView> createState() => _SendRouteViewState();
}

class _SendRouteViewState extends State<_SendRouteView> {
  late final SendCubit _cubit;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _cubit = locator<SendCubit>(
      param1: widget.wallet,
      param2: (args: widget.args, spWalletLabel: widget.spWalletLabel),
    );
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
