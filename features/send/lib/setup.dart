import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:spend/spend.dart';

import 'src/broadcast_signed_tx/router.dart';
import 'src/replace_by_fee/router.dart';
import 'src/consolidation/ui/consolidation_router.dart';

export 'generated/l10n/send_localizations.dart' show SendLocalizations;

typedef SendRoutes = ({
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
  }) => (
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
