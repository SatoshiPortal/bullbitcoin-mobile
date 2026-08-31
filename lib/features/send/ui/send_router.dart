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
  final String? fixedRecipient;
  final bool sendMax;

  const SendRouteArgs({
    this.wallet,
    this.pendingTransactionId,
    this.fixedRecipient,
    this.sendMax = false,
  });
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
        fixedRecipient: args?.fixedRecipient,
        sendMax: args?.sendMax ?? false,
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
  final String? fixedRecipient;
  final bool sendMax;

  const _SendRouteView({
    super.key,
    this.wallet,
    this.pendingTransactionId,
    this.fixedRecipient,
    this.sendMax = false,
  });

  @override
  State<_SendRouteView> createState() => _SendRouteViewState();
}

class _SendRouteViewState extends State<_SendRouteView> {
  late final SendCubit _cubit;
  late final Future<bool> _initialization;

  @override
  void initState() {
    super.initState();
    _cubit = locator<SendCubit>(param1: widget.wallet);
    _initialization = _initialize();
  }

  Future<bool> _initialize() async {
    await _cubit.loadWalletWithRatesAndFees();
    if (widget.pendingTransactionId case final id?) {
      final restored = await _cubit.loadPendingTransaction(id);
      if (!restored) return false;
      if (widget.fixedRecipient case final recipient?) {
        return _cubit.restrictRestoredSend(recipient);
      }
      return true;
    } else if (widget.fixedRecipient case final recipient?) {
      return _cubit.configureRestrictedSend(
        recipient: recipient,
        sendMax: widget.sendMax,
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final requiresInitialization =
        widget.pendingTransactionId != null || widget.fixedRecipient != null;
    final child = !requiresInitialization
        ? const SendScreen()
        : FutureBuilder<bool>(
            future: _initialization,
            builder: (_, snapshot) {
              if (snapshot.connectionState != .done) {
                return const SendLoadingScreen();
              }
              return snapshot.data == true
                  ? const SendScreen()
                  : const SendLoadingScreen(hasError: true);
            },
          );
    return BlocProvider(lazy: false, create: (_) => _cubit, child: child);
  }
}
