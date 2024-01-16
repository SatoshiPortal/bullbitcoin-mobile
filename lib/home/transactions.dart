import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/home2.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<HomeCubit>(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _TopAppBar(),
          automaticallyImplyLeading: false,
        ),
        body: const _TxList(),
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Transaction History',
      onBack: () => context.pop(),
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList();

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final txs = context.select((HomeCubit cubit) => cubit.state.allTxs(network));

    if (txs.isEmpty)
      return TopLeft(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
          ),
          child: const BBText.titleLarge('No Transactions yet').animate(delay: 300.ms).fadeIn(),
        ),
      );

    return ListView.builder(
      itemCount: txs.length,
      itemBuilder: (context, index) {
        return HomeTxItem2(tx: txs[index]);
      },
    );
  }
}
