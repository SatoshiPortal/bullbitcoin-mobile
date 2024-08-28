import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
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
  });

  final SwapTx swapTx;
  final bool isReceive;
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
      homeCubit: context.read<HomeCubit>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      networkCubit: context.read<NetworkCubit>(),
    );
    _swapCubit.setSwapTx(widget.swapTx);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _swapCubit),
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
