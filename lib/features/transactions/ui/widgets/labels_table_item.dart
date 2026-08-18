import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class LabelsTableItem extends StatelessWidget {
  const LabelsTableItem({super.key, required this.title, required this.labels});

  final String title;
  final List<Label> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            flex: 2,
            child: BullText(
              title,
              style: context.bullText.bodyMedium?.copyWith(
                color: context.bull.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: .centerRight,
              child: LabelsWidget(
                labels: labels,
                onDelete: (label) async {
                  final result = await context
                      .read<TransactionDetailsCubit>()
                      .deleteTransactionNote(label);
                  if (result case Err(:final failure)) {
                    if (context.mounted) {
                      SnackBarUtils.showSnackBar(
                        context,
                        failure.toTranslated(context),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
