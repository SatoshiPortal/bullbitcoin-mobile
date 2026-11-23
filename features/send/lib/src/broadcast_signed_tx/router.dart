import 'package:send/src/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:send/src/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:send/src/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart';
import 'package:send/src/broadcast_signed_tx/presentation/pages/scan_nfc_page.dart';
import 'package:send/src/broadcast_signed_tx/presentation/pages/scan_qr_page.dart';
import 'package:electrum/electrum.dart';
import 'package:flutter/widgets.dart';
import 'package:preferences/preferences.dart';
import 'package:send/src/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:send/src/broadcast_signed_tx/domain/broadcast_imported_bitcoin_usecase.dart';
import 'package:send/src/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:send/src/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:spend/spend.dart';

enum BroadcastSignedTxRoute {
  broadcastHome('/broadcast-signed-tx'),
  broadcastScanQr('scan-qr'),
  broadcastScanNfc('scan-nfc');

  const BroadcastSignedTxRoute(this.path);

  final String path;
}

ShellRoute broadcastSignedTxRoute({
  required Spend spend,
  required Electrum electrum,
  required ActiveEnvironmentReader environment,
  required void Function(BuildContext) goToWalletHome,
  required ImageProvider successImage,
}) {
  final buildReview = BuildReviewableTransactionUsecase(
    electrum: electrum.transactions,
  );
  return ShellRoute(
    builder: (context, state, child) {
      final (prepared, network) = switch (state.extra) {
        (
          prepared: final PreparedBitcoinSpend spend,
          network: final BitcoinNetwork chain,
        ) =>
          (spend, chain),
        _ => (null, null),
      };

      return BlocProvider(
        create: (_) => BroadcastSignedTxCubit(
          broadcastImportedBitcoin: BroadcastImportedBitcoinUsecase(
            spend,
            environment,
          ),
          verifySignedTxUsecase: VerifyBroadcastSignedTxUsecase(spend),
          prepared: prepared,
          network: network,
        ),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: BroadcastSignedTxRoute.broadcastHome.name,
        path: BroadcastSignedTxRoute.broadcastHome.path,
        builder: (context, state) => BroadcastSignedTxPage(
          createReview: () => TransactionReviewCubit(
            buildReviewableTransactionUsecase: buildReview,
          ),
          onDone: goToWalletHome,
          successImage: successImage,
        ),
        routes: [
          GoRoute(
            name: BroadcastSignedTxRoute.broadcastScanQr.name,
            path: BroadcastSignedTxRoute.broadcastScanQr.path,
            builder: (context, state) =>
                BlocListener<BroadcastSignedTxCubit, BroadcastSignedTxState>(
                  listenWhen: (previous, state) =>
                      previous.transaction == null && state.transaction != null,
                  listener: (context, state) => context.pop(),
                  child: const ScanQrPage(),
                ),
          ),
          GoRoute(
            name: BroadcastSignedTxRoute.broadcastScanNfc.name,
            path: BroadcastSignedTxRoute.broadcastScanNfc.path,
            builder: (context, state) =>
                BlocListener<BroadcastSignedTxCubit, BroadcastSignedTxState>(
                  listenWhen: (previous, state) =>
                      previous.transaction == null && state.transaction != null,
                  listener: (context, state) => context.pop(),
                  child: const ScanNfcPage(),
                ),
          ),
        ],
      ),
    ],
  );
}
