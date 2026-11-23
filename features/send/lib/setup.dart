import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:spend/spend.dart';
import 'package:swaps/order_swaps.dart' show OrderSwapRecord;
import 'package:sync/sync.dart' show WalletKey;

import 'src/broadcast_signed_tx/router.dart';
import 'src/payment/send_payment_dependencies.dart';
import 'src/payment/payment_composition.dart';
import 'src/payment/ui/send_router.dart';
import 'src/replace_by_fee/router.dart';
import 'src/consolidation/ui/consolidation_router.dart';

export 'generated/l10n/send_localizations.dart' show SendLocalizations;
export 'src/payment/send_payment_dependencies.dart'
    show SendPaymentDependencies;

typedef SendRoutes = ({
  RouteBase payment,
  RouteBase broadcastSignedTx,
  RouteBase consolidation,
  RouteBase replaceByFee,
});

abstract final class SendFeature {
  static SendRoutes mount({
    required Spend spend,
    required Fees fees,
    required Electrum electrum,
    required ActiveEnvironmentReader environment,
    required void Function(BuildContext) goToWalletHome,
    required ImageProvider broadcastSuccessImage,
    required String missingWalletRedirect,
    required int? Function(BuildContext, String) selectBalanceSat,
    required SendPaymentDependencies Function() payment,
    required void Function(BuildContext, WalletKey) openCoins,
    required Widget Function(OrderSwapRecord) orderUnderReview,
    required ImageProvider paymentArrowImage,
  }) => (
    payment: paymentRoute(
      createCubits: (args, spWalletLabel) => createPaymentCubits(
        dependencies: payment(),
        args: args,
        spWalletLabel: spWalletLabel,
        spend: spend,
        fees: fees,
        environment: environment,
      ),
      openSignedTransactionReader: (context, prepared, network) =>
          GoRouter.of(context).pushNamed<String>(
            BroadcastSignedTxRoute.broadcastHome.name,
            extra: (prepared: prepared, network: network),
          ),
      openHome: goToWalletHome,
      openCoins: openCoins,
      orderUnderReview: orderUnderReview,
      arrowImage: paymentArrowImage,
      successImage: broadcastSuccessImage,
    ),
    broadcastSignedTx: broadcastSignedTxRoute(
      spend: spend,
      electrum: electrum,
      environment: environment,
      goToWalletHome: goToWalletHome,
      successImage: broadcastSuccessImage,
    ),
    consolidation: consolidationRoute(
      spend: spend,
      missingWalletRedirect: missingWalletRedirect,
      selectBalanceSat: selectBalanceSat,
    ),
    replaceByFee: replaceByFeeRoute(
      spend: spend,
      fees: fees,
      goToWalletHome: goToWalletHome,
    ),
  );
}
