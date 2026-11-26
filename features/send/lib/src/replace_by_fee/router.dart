import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart'
    show Network, NetworkEnv, UnsupportedNetworkException;
import 'package:spend/spend.dart';
import 'package:send/src/send_localizations.dart';
import 'package:material_ui/material_ui.dart'
    show BuildContext, Scaffold, Center, Text;
import 'package:send/src/replace_by_fee/domain/replacement_target.dart';
import 'package:send/src/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:send/src/replace_by_fee/presentation/cubit.dart';
import 'package:send/src/replace_by_fee/presentation/state.dart';
import 'package:send/src/replace_by_fee/ui/home_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReplaceByFeeRoute {
  replaceByFeeFlow('/replace-by-fee-flow');

  final String path;

  const ReplaceByFeeRoute(this.path);
}

abstract final class ReplaceByFee {
  static void openForTransaction(
    BuildContext context, {
    required String walletId,
    required String txId,
    required Network network,
    required int feeSat,
    required int vsize,
  }) {
    if (network.env == NetworkEnv.signet) {
      throw const UnsupportedNetworkException();
    }
    context.pushNamed(
      ReplaceByFeeRoute.replaceByFeeFlow.name,
      extra: (
        walletId: walletId,
        txId: txId,
        network: network,
        feeSat: feeSat,
        vsize: vsize,
      ),
    );
  }
}

GoRoute replaceByFeeRoute({
  required Spend spend,
  required Fees fees,
  required void Function(BuildContext) goToWalletHome,
}) => GoRoute(
  name: ReplaceByFeeRoute.replaceByFeeFlow.name,
  path: ReplaceByFeeRoute.replaceByFeeFlow.path,
  builder: (context, state) {
    final tx = state.extra;
    if (tx is! ReplacementTarget) {
      return Scaffold(
        body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
      );
    }

    return BlocProvider(
      create: (_) => ReplaceByFeeCubit(
        originalTransaction: tx,
        bumpFeeUsecase: BumpFeeUsecase(spend: spend, fees: fees),
      ),
      child: BlocListener<ReplaceByFeeCubit, ReplaceByFeeState>(
        listenWhen: (previous, state) =>
            previous.txid == null && state.txid != null,
        listener: (context, state) => goToWalletHome(context),
        child: ReplaceByFeeHomePage(tx: tx),
      ),
    );
  },
);
