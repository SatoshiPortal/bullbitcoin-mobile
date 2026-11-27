import 'package:bull_exchange/src/autobuy/presentation/autobuy_bloc.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_event.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullDialog,
        BullShimmerLine,
        BullSpacing,
        BullSwitch,
        Gap,
        BullTypographyX;
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The home card's AutoBuy switch, built from [AutoBuySwitchState]: on opens
/// the activation flow, off asks and deactivates.
class AutoBuyHomeCard extends StatelessWidget {
  const AutoBuyHomeCard({super.key, required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AutoBuySwitchBloc>().state;
    final problem = switch (state) {
      SwitchShown(problem: SwitchWriteRefused(:final refusal)) =>
        refusal.toTranslated(context),
      SwitchShown(problem: SwitchWriteFailed()) =>
        context.loc.autoBuyUpdateError,
      SwitchDeactivating(confirm: ConfirmUnverified()) =>
        context.loc.exchangeStepUnverified,
      SwitchShown() || SwitchDeactivating() || SwitchSessionEnded() => null,
    };
    final label = state.active
        ? context.loc.autoBuyDeactivate
        : context.loc.autoBuyActivate;
    final Widget control = switch (state) {
      SwitchDeactivating(confirm: ConfirmUnverified()) => BullButton.secondary(
        label: context.loc.exchangeStepCheckAgain,
        size: BullButtonSize.small,
        compact: true,
        onPressed: () =>
            context.read<AutoBuySwitchBloc>().add(const SwitchRetryPressed()),
      ),
      SwitchDeactivating() => const BullShimmerLine(
        width: 48,
        height: 24,
        padding: EdgeInsets.zero,
      ),
      SwitchShown(:final active, :final restricted) => MergeSemantics(
        child: Semantics(
          label: label,
          child: BullSwitch(
            value: active,
            onChanged: restricted
                ? null
                : (value) => value ? onActivate() : _confirmDeactivate(context),
          ),
        ),
      ),
      SwitchSessionEnded(:final active) => MergeSemantics(
        child: Semantics(
          label: label,
          child: BullSwitch(value: active, onChanged: null),
        ),
      ),
    };
    return ListTile(
      title: Row(
        children: [
          Expanded(child: ExcludeSemantics(child: Text(label))),
          control,
        ],
      ),
      subtitle: problem == null
          ? null
          : Text(problem, style: TextStyle(color: context.appColors.error)),
    );
  }

  void _confirmDeactivate(BuildContext context) {
    final bloc = context.read<AutoBuySwitchBloc>();
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
                  bloc.add(const SwitchDeactivatePressed());
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
