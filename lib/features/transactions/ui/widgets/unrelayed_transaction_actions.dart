import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/cbf_recovery_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'unrelayed_transaction_panel.dart';

class UnrelayedTransactionActions extends StatelessWidget {
  final String walletId;
  final String txid;
  final VoidCallback onRetried;
  final VoidCallback onCanceled;

  const UnrelayedTransactionActions({
    super.key,
    required this.walletId,
    required this.txid,
    required this.onRetried,
    required this.onCanceled,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<CbfRecoveryCubit>(),
    child: BlocBuilder<CbfRecoveryCubit, CbfRecoveryState>(
      builder: (context, state) => UnrelayedTransactionPanel(
        busy: state.isBusy,
        failure: state.failure,
        onRetry: () async {
          final recovered = await context.read<CbfRecoveryCubit>().retry(
            walletId,
            txid,
          );
          if (recovered && context.mounted) {
            onRetried();
          }
        },
        onCancel: () async {
          final canceled = await context.read<CbfRecoveryCubit>().cancel(
            walletId,
            txid,
          );
          if (canceled && context.mounted) {
            onCanceled();
          }
        },
      ),
    ),
  );
}
