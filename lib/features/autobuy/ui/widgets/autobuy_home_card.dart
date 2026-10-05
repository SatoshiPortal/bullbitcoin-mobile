import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDialog, BullSnackBar, BullSpacing, BullSwitch, Gap;

class AutoBuyHomeCard extends StatelessWidget {
  final bool isActive;
  final bool isRestricted;
  final VoidCallback onActivate;
  final Future<void> Function() onStatusChanged;

  const AutoBuyHomeCard({
    required this.isActive,
    required this.isRestricted,
    required this.onActivate,
    required this.onStatusChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AutoBuyCubit, AutoBuyState>(
      listenWhen: (previous, current) =>
          (!previous.statusChangeSucceeded && current.statusChangeSucceeded) ||
          (previous.failure == null && current.failure != null),
      listener: (context, state) async {
        if (state.statusChangeSucceeded) {
          await onStatusChanged();
        } else if (state.failure case final failure?) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: BlocBuilder<AutoBuyCubit, AutoBuyState>(
        buildWhen: (previous, current) => previous.isSaving != current.isSaving,
        builder: (context, state) {
          return ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isActive
                        ? context.loc.autoBuyDeactivate
                        : context.loc.autoBuyActivate,
                  ),
                ),
                if (state.isSaving)
                  const LoadingLineContent(
                    width: 48,
                    height: 24,
                    padding: EdgeInsets.zero,
                  )
                else
                  BullSwitch(
                    value: isActive,
                    onChanged: isRestricted
                        ? null
                        : (value) => _onToggle(context, value),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onToggle(BuildContext context, bool value) {
    if (value) {
      onActivate();
      return;
    }
    _showCancelDialog(context);
  }

  void _showCancelDialog(BuildContext context) {
    final cubit = context.read<AutoBuyCubit>();
    BullDialog.show<void>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.loc.autoBuyCancelTitle, style: context.font.titleMedium),
          const Gap(BullSpacing.sm),
          Text(
            context.loc.autoBuyCancelMessage,
            style: context.font.bodyMedium,
          ),
          const Gap(BullSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.loc.cancel),
              ),
              const Gap(BullSpacing.xs),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  cubit.setEnabled(false);
                },
                child: Text(context.loc.autoBuyDeactivateConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
