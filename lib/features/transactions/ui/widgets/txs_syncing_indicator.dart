import 'package:bb_mobile/features/transactions/bloc/transactions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class TxsSyncingIndicator extends StatelessWidget {
  const TxsSyncingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select(
      (TransactionsCubit cubit) => cubit.state.isSyncing,
    );

    if (isSyncing) {
      return const LinearProgressIndicator();
    } else {
      return const Gap(4);
    }
  }
}
