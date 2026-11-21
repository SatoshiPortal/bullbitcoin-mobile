import 'package:bull_ui/bull_ui.dart';
import 'package:fees/fees.dart' show FeeSource;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/l10n/fees_localizations.dart';
import '../fees_l10n.dart';
import '../presentation/fee_source_cubit.dart';
import '../presentation/fee_source_settings_failure_l10n.dart';

class FeeSourceScreen extends StatelessWidget {
  const FeeSourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = feesCopy(Localizations.localeOf(context).toLanguageTag());
    return BlocBuilder<FeeSourceCubit, FeeSourceState>(
      builder: (context, state) {
        final cubit = context.read<FeeSourceCubit>();
        final busy = state is FeeSourceLoading;
        return BullScaffold(
          body: SafeArea(
            child: Column(
              children: [
                BullTopBar(
                  title: copy.settingsTitle,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                BullFadingLinearProgress(trigger: busy),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(BullSpacing.md),
                    children: [
                      if (state.source case final selected?)
                        for (final source in FeeSource.values) ...[
                          _FeeSourceRow(
                            copy: copy,
                            source: source,
                            selected: selected == source,
                            onTap: busy ? null : () => cubit.select(source),
                          ),
                          const Gap(BullSpacing.sm),
                        ],
                      if (state case FeeSourceFailed(:final failure))
                        BullErrorState(
                          message: failure.toTranslated(context),
                          retryLabel: copy.retry,
                          onRetry: cubit.retry,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeeSourceRow extends StatelessWidget {
  final FeesLocalizations copy;
  final FeeSource source;
  final bool selected;
  final VoidCallback? onTap;

  const _FeeSourceRow({
    required this.copy,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, description, icon) = switch (source) {
      FeeSource.electrum => (
        copy.electrumLabel,
        copy.electrumDescription,
        BullIcons.accountTree,
      ),
      FeeSource.mempool => (
        copy.mempoolLabel,
        copy.mempoolDescription,
        BullIcons.showChart,
      ),
    };
    final colors = context.bull;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      hint: description,
      button: true,
      enabled: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      child: BullBorderedTile(
        onTap: onTap,
        backgroundColor: selected ? colors.surfaceContainer : null,
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Row(
          children: [
            BullIcon(icon, color: selected ? colors.primary : colors.onSurface),
            const Gap(BullSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BullText(label, role: BullTextRole.subtitle),
                  const Gap(BullSpacing.xxs),
                  BullText(
                    description,
                    role: BullTextRole.label,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
            const Gap(BullSpacing.sm),
            SizedBox(
              width: BullSpacing.lg,
              child: selected
                  ? BullIcon(BullIcons.check, color: colors.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
