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
      SwitchOff(problem: SwitchWriteRefused(:final refusal)) ||
      SwitchOn(
        problem: SwitchWriteRefused(:final refusal),
      ) => refusal.toTranslated(context),
      SwitchOff(problem: SwitchWriteFailed()) ||
      SwitchOn(problem: SwitchWriteFailed()) => context.loc.autoBuyUpdateError,
      SwitchDeactivating(confirm: ConfirmUnverified()) =>
        context.loc.exchangeStepUnverified,
      SwitchOff(problem: null) ||
      SwitchOn(problem: null) ||
      SwitchDeactivating() ||
      SwitchSessionEnded() => null,
    };
    final label = switch (state) {
      SwitchOff() => context.loc.autoBuyActivate,
      SwitchOn() ||
      SwitchDeactivating() ||
      SwitchSessionEnded() => context.loc.autoBuyDeactivate,
    };
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
      SwitchOff(:final restricted) => MergeSemantics(
        child: Semantics(
          label: label,
          child: BullSwitch(
            value: false,
            onChanged: restricted ? null : (value) => _changed(context, value),
          ),
        ),
      ),
      SwitchOn(:final restricted) => MergeSemantics(
        child: Semantics(
          label: label,
          child: BullSwitch(
            value: true,
            onChanged: restricted ? null : (value) => _changed(context, value),
          ),
        ),
      ),
      SwitchSessionEnded() => MergeSemantics(
        child: Semantics(
          label: label,
          child: const BullSwitch(value: true, onChanged: null),
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

  void _changed(BuildContext context, bool value) =>
      value ? onActivate() : _confirmDeactivate(context);

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
