import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/transactions/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SendRoute {
  send('/send'),
  sendTransactionDetails('details');

  const SendRoute(this.path);

  final String path;
}

class SendRouter {
  static final route = GoRoute(
    path: SendRoute.send.path,
    builder: (context, state) {
      // Pass a preselected wallet to the send bloc if one is set in the URI
      //  of the incoming route
      final wallet = state.extra is Wallet ? state.extra! as Wallet : null;
      return BlocProvider(
        create:
            (_) =>
                locator<SendCubit>(param1: wallet)
                  ..loadWalletWithRatesAndFees(),
        child: const SendScreen(),
      );
    },
    routes: [
      GoRoute(
        path: SendRoute.sendTransactionDetails.path,
        builder: (context, state) {
          final tx = state.extra! as WalletTransaction;
          return BlocProvider(
            create:
                (context) =>
                    locator<TransactionDetailsCubit>()..loadTxDetails(tx),
            child: const TransactionDetailsScreen(title: 'Send'),
          );
        },
      ),
    ],
  );
}
