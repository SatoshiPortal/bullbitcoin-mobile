import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class TxsSyncingIndicator extends StatelessWidget {
  const TxsSyncingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select(
      (TransactionsCubit cubit) => cubit.state.isSyncing,
    );

    return BullFadingLinearProgress(
      trigger: isSyncing,
      height: 3,
      backgroundColor: context.bull.secondary,
      foregroundColor: context.bull.primary,
    );
  }
}
