import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/swap_page_progress.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ChainSwapProgressPage extends StatefulWidget {
  const ChainSwapProgressPage({
    super.key,
    required this.swapTx,
    required this.isReceive,
    this.sendCubit,
  });

  final SwapTx swapTx;
  final bool isReceive;
  final SendCubit? sendCubit;
  @override
  State<ChainSwapProgressPage> createState() => _ChainSwapProgressPageState();
}

class _ChainSwapProgressPageState extends State<ChainSwapProgressPage> {
  late CreateSwapCubit _swapCubit;

  @override
  void initState() {
    _swapCubit = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      // homeCubit: context.read<HomeBloc>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      // networkCubit: context.read<NetworkBloc>(),
      networkRepository: locator<NetworkRepository>(),
    );
    _swapCubit.setSwapTx(widget.swapTx);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _swapCubit),
        if (widget.sendCubit != null)
          BlocProvider.value(value: widget.sendCubit!),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: BBAppBar(
            text: 'Swap in progress',
            onBack: () {
              context.pop();
            },
          ),
          automaticallyImplyLeading: false,
        ),
        body: ChainSwapProgressWidget(isReceive: widget.isReceive),
      ),
    );
  }
}
