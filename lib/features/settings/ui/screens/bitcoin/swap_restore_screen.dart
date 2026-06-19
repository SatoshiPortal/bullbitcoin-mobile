import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapRestoreScreen extends StatelessWidget {
  const SwapRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullTopBar(
              title: context.loc.swapRestoreTitle,
              onBack: () => context.pop(),
            ),
            const Expanded(child: _SwapRestoreBody()),
          ],
        ),
      ),
    );
  }
}

class _SwapRestoreBody extends StatelessWidget {
  const _SwapRestoreBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SwapRestoreCubit>().state;

    switch (state.status) {
      case SwapRestoreStatus.initial:
      case SwapRestoreStatus.loading:
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 4,
          itemBuilder: (_, _) => const BullShimmerLine(height: 44),
        );
      case SwapRestoreStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BullText(
              state.error ?? context.loc.swapRestoreFailed,
              style: context.font.bodyMedium,
              color: context.bull.textMuted,
              textAlign: .center,
            ),
          ),
        );
      case SwapRestoreStatus.success:
        if (state.swaps.isEmpty) {
          return Center(
            child: BullText(
              context.loc.swapRestoreNoSwaps,
              style: context.font.bodyMedium,
              color: context.bull.textMuted,
            ),
          );
        }
        final recoverable = state.swaps
            .where((s) => s.swap.recoverable && !s.existsLocally)
            .toList();
        final others = state.swaps
            .where((s) => !(s.swap.recoverable && !s.existsLocally))
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: BullText(
                context.loc.swapRestoreActionable(state.actionableCount),
                style: context.font.bodySmall,
                color: context.bull.textMuted,
              ),
            ),
            if (recoverable.isNotEmpty) ...[
              _SectionHeader(label: context.loc.swapRestoreRecoverableSection),
              for (final s in recoverable) _SwapRow(restorable: s),
            ],
            if (others.isNotEmpty) ...[
              if (recoverable.isNotEmpty)
                _SectionHeader(label: context.loc.swapRestoreAllSection),
              for (final s in others) _SwapRow(restorable: s),
            ],
          ],
        );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: BullText(
        label.toUpperCase(),
        style: context.font.labelSmall,
        color: context.bull.textMuted,
      ),
    );
  }
}

class _SwapRow extends StatelessWidget {
  const _SwapRow({required this.restorable});

  final RestorableSwap restorable;

  String _kindLabel(BuildContext context) {
    switch (restorable.swap.kind) {
      case RestoredSwapKind.lightningSend:
        return context.loc.swapRestoreKindLightningSend;
      case RestoredSwapKind.lightningReceive:
        return context.loc.swapRestoreKindLightningReceive;
      case RestoredSwapKind.crossChain:
        return context.loc.swapRestoreKindCrossChain;
    }
  }

  // Recoverable swaps read as "Pending" (funds locked, not yet claimed/refunded);
  // everything else shows its real, terminal status.
  String _statusLabel(BuildContext context) =>
      restorable.swap.recoverable
      ? context.loc.coreSwapsStatusPending
      : restorable.swap.status.displayName(context);

  Color _statusColor(BuildContext context) {
    if (restorable.swap.recoverable) return context.bull.warning;
    switch (restorable.swap.status) {
      case SwapStatus.completed:
        return context.bull.success;
      case SwapStatus.failed:
        return context.bull.error;
      default:
        return context.bull.textMuted;
    }
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final id = restorable.swap.id;
    final shortId = id.length > 12 ? '${id.substring(0, 12)}…' : id;
    // Only swaps with locked, unresolved funds that aren't already stored can be
    // rescued; resolved/expired-unfunded swaps are display-only.
    final canRescue = restorable.swap.recoverable && !restorable.existsLocally;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                BullText(
                  _kindLabel(context),
                  style: context.font.bodyMedium,
                  color: context.bull.text,
                ),
                BullText(
                  shortId,
                  style: context.font.labelSmall,
                  color: context.bull.textMuted,
                ),
                const Gap(2),
                BullText(
                  '${FormatAmount.sats(restorable.swap.amountSat)} · '
                  '${_formatDate(restorable.swap.createdAt)}',
                  style: context.font.labelSmall,
                  color: context.bull.textMuted,
                ),
              ],
            ),
          ),
          const Gap(8),
          BullBadge(
            label: _statusLabel(context),
            background: _statusColor(context).withValues(alpha: 0.15),
            foreground: _statusColor(context),
          ),
          if (canRescue) ...[
            const Gap(4),
            BullIcon(
              BullIcons.chevronRight,
              color: context.bull.textMuted,
              size: 22,
            ),
          ],
        ],
      ),
    );

    if (!canRescue) return row;
    return GestureDetector(
      // Make the whole row tappable, not just its painted children.
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushNamed(
        SettingsRoute.swapRescue.name,
        extra: restorable,
      ),
      child: row,
    );
  }
}
