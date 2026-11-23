import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullButtonSize;
import 'package:bull_exchange/src/autobuy/presentation/autobuy_cubit.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullDialog,
        BullShimmerLine,
        BullSnackBar,
        BullSpacing,
        BullSwitch,
        Gap,
        BullTypographyX;

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
                  const BullShimmerLine(
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
          Text(
            context.loc.autoBuyCancelTitle,
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          const Gap(BullSpacing.sm),
          Text(context.loc.autoBuyCancelMessage, style: context.bullType.body),
          const Gap(BullSpacing.lg),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: BullSpacing.xs,
            overflowSpacing: BullSpacing.xs,
            children: [
              BullButton.secondary(
                label: context.loc.cancel,
                onPressed: () => Navigator.of(dialogContext).pop(),
                size: BullButtonSize.small,
                compact: true,
              ),
              BullButton.primary(
                label: context.loc.autoBuyDeactivateConfirm,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  cubit.setEnabled(false);
                },
                size: BullButtonSize.small,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
