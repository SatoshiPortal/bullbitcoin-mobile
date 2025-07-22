import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TxsSyncingIndicator extends StatelessWidget {
  const TxsSyncingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select(
      (TransactionsCubit cubit) => cubit.state.isSyncing,
    );

    return FadingLinearProgress(
      trigger: isSyncing,
      height: 3,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Theme.of(context).colorScheme.primary,
    );
  }
}
