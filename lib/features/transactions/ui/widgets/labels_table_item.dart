import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            child: BBText(
              title,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
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
                      .deleteTransactionNote(label);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
