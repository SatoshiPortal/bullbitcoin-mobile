import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/presentation/swap_failure_l10n.dart';
import 'package:bb_mobile/features/swap/presentation/swap_settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapSettingsPage extends StatelessWidget {
  const SwapSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SwapSettingsCubit, SwapSettingsState>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        if (state.failure case final failure?) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: BullScaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              BullTopBar(
                title: context.loc.swapSettingsTitle,
                onBack: () => context.pop(),
              ),
              const Expanded(child: _SwapSettingsBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapSettingsBody extends StatelessWidget {
  const _SwapSettingsBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SwapSettingsCubit>().state;
    final cubit = context.read<SwapSettingsCubit>();
    final canEdit = state.loaded && !state.saving;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: BullText(
                context.loc.swapSettingsExchangeFallbackLabel,
                style: context.font.bodyLarge,
                color: context.bull.text,
              ),
            ),
            BullSwitch(
              value: state.exchangeFallbackEnabled,
              onChanged: canEdit ? cubit.setExchangeFallbackEnabled : null,
            ),
          ],
        ),
        const Gap(8),
        BullText(
          context.loc.swapSettingsExchangeFallbackDescription,
          style: context.font.bodySmall,
          color: context.bull.textMuted,
        ),
        if (state.loaded && state.devModeEnabled) ...[
          const Gap(32),
          BullText(
            context.loc.swapSettingsRouteOverrideTitle,
            style: context.font.titleSmall,
            color: context.bull.text,
          ),
          const Gap(12),
          _RouteOverrideSelector(
            key: ValueKey((state.routeOverride, state.failure)),
            value: state.routeOverride,
            onSelected: cubit.setRouteOverride,
          ),
        ],
      ],
    );
  }
}

class _RouteOverrideSelector extends StatelessWidget {
  const _RouteOverrideSelector({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final SwapRouteOverride value;
  final ValueChanged<SwapRouteOverride> onSelected;

  String _label(BuildContext context, SwapRouteOverride override) =>
      switch (override) {
        SwapRouteOverride.auto => context.loc.swapSettingsRouteOverrideAuto,
        SwapRouteOverride.boltzOnly =>
          context.loc.swapSettingsRouteOverrideBoltzOnly,
        SwapRouteOverride.exchangeOnly =>
          context.loc.swapSettingsRouteOverrideExchangeOnly,
      };

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final override in SwapRouteOverride.values)
        _label(context, override): override,
    };
    return BullSegmented(
      items: labels.keys.toSet(),
      initialValue: _label(context, value),
      onSelected: (label) {
        final override = labels[label];
        if (override != null && override != value) onSelected(override);
      },
    );
  }
}
