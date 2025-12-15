import 'package:bb_mobile/core_deprecated/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core_deprecated/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/cubit.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:bb_mobile/features/replace_by_fee/ui/home_page.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReplaceByFeeRoute {
  replaceByFeeFlow('/replace-by-fee-flow');

  final String path;

  const ReplaceByFeeRoute(this.path);
}

class ReplaceByFeeRouter {
  static final route = GoRoute(
    name: ReplaceByFeeRoute.replaceByFeeFlow.name,
    path: ReplaceByFeeRoute.replaceByFeeFlow.path,
    builder: (context, state) {
      final tx = state.extra! as WalletTransaction;

      return BlocProvider(
        create:
            (_) => ReplaceByFeeCubit(
              originalTransaction: tx,
              bumpFeeUsecase: locator<BumpFeeUsecase>(),
              broadcastBitcoinTransactionUsecase:
                  locator<BroadcastBitcoinTransactionUsecase>(),
              getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
            ),
        child: BlocListener<ReplaceByFeeCubit, ReplaceByFeeState>(
          listenWhen:
              (previous, state) => previous.txid == null && state.txid != null,
          listener:
              (context, state) => context.goNamed(WalletRoute.walletHome.name),
          child: ReplaceByFeeHomePage(tx: tx),
        ),
      );
    },
  );
}
