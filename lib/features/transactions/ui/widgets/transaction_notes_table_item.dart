import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/labels_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionNotesTableItem extends StatelessWidget {
  const TransactionNotesTableItem({super.key, required this.labels});

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
            child: BBText(
              context.loc.transactionNotesLabel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.surfaceContainer,
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
                  await context
                      .read<TransactionDetailsCubit>()
                      .deleteTransactionNote(label.label);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
