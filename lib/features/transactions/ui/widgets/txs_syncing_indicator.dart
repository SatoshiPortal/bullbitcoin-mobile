import 'package:bb_mobile/features/transactions/blocs/transactions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TxsSyncingIndicator extends StatelessWidget {
  const TxsSyncingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select(
      (TransactionsCubit cubit) => cubit.state.isSyncing,
    );

    return SizedBox(
      height: 4,
      child:
          isSyncing ? const LinearProgressIndicator() : const SizedBox.shrink(),
    );
  }
}
