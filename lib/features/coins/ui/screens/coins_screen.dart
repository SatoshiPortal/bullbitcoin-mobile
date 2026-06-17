import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/coins_state.dart';
import 'package:bb_mobile/features/coins/ui/widgets/coins_selection_bar.dart';
import 'package:bb_mobile/features/coins/ui/widgets/coins_summary_bar.dart';
import 'package:bb_mobile/features/coins/ui/widgets/coins_sort_filter_sheet.dart';
import 'package:bb_mobile/features/coins/ui/widgets/freeze_confirm_dialog.dart';
import 'package:bb_mobile/features/coins/ui/widgets/utxo_tile.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Coins (UTXO) screen — list view with summary, sort/filter, multi-select
/// and freeze/unfreeze. Built entirely on `package:bull_ui/bull_ui.dart`.
class CoinsScreen extends StatelessWidget {
  const CoinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CoinsCubit, CoinsState>(
      listenWhen: (prev, curr) =>
          prev.error != curr.error && curr.error != null,
      listener: (context, state) {
        final error = state.error;
        if (error != null) {
          BullSnackBar.show(context, message: error.toTranslated(context));
          context.read<CoinsCubit>().clearError();
        }
      },
      builder: (context, state) {
        final selectionActive =
            state.selecting && state.selectedOutpoints.isNotEmpty;
        return BullScaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopChrome(state: state),
                if (state.status != CoinsStatus.loading)
                  CoinsSummaryBar(
                    coinsCount: state.utxos.length,
                    totalSat: state.totalSat,
                    frozenSat: state.frozenSat,
                    spendableSat: state.spendableSat,
                    hasFrozen: state.hasFrozen,
                  ),
                if (!state.selecting && state.status == CoinsStatus.ready)
                  _SubHeader(state: state),
                Expanded(child: _Body(state: state)),
                if (!state.selecting && state.status == CoinsStatus.ready)
                  const _FooterHint(),
              ],
            ),
          ),
          bottomNavigationBar: selectionActive
              ? CoinsSelectionBar(
                  selectedCount: state.selectedOutpoints.length,
                  selectedTotalSat: state.selectedUtxos.fold(
                    BigInt.zero,
                    (sum, u) => sum + u.amountSat,
                  ),
                  anyUnfrozen: state.anySelectedUnfrozen,
                  anyFrozen: state.anySelectedFrozen,
                  onFreeze: () => _confirmFreeze(context, state),
                  onUnfreeze: () => _unfreeze(
                    context,
                    state.selectedUtxos
                        .where((u) => u.isFrozen)
                        .map(utxoOutpointKey)
                        .toList(),
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _confirmFreeze(BuildContext context, CoinsState state) async {
    final selected = state.selectedUtxos.where((u) => !u.isFrozen).toList();
    final outpoints = selected.map(utxoOutpointKey).toList();
    if (outpoints.isEmpty) return;
    final selectedFrozenSum = selected.fold(
      BigInt.zero,
      (sum, u) => sum + u.amountSat,
    );
    final makesSpendableZero =
        state.spendableSat - selectedFrozenSum <= BigInt.zero;

    await BullDialog.show<void>(
      context: context,
      builder: (dialogContext) => FreezeConfirmDialog(
        count: outpoints.length,
        makesSpendableZero: makesSpendableZero,
        onCancel: dialogContext.pop,
        onConfirm: () {
          dialogContext.pop();
          _freeze(context, outpoints);
        },
      ),
    );
  }

  Future<void> _freeze(BuildContext context, List<String> outpoints) async {
    final cubit = context.read<CoinsCubit>();
    await cubit.freeze(outpoints);
    if (!context.mounted) return;
    if (cubit.state.error == null) {
      BullSnackBar.show(
        context,
        message: context.loc.coinsFrozenToast(outpoints.length),
        leadingIcon: BullIcons.acUnit,
      );
    }
  }

  Future<void> _unfreeze(BuildContext context, List<String> outpoints) async {
    final cubit = context.read<CoinsCubit>();
    if (outpoints.isEmpty) return;
    await cubit.unfreeze(outpoints);
    if (!context.mounted) return;
    if (cubit.state.error == null) {
      BullSnackBar.show(
        context,
        message: context.loc.coinsUnfrozenToast(outpoints.length),
        leadingIcon: BullIcons.lockOpen,
        actionLabel: context.loc.coinsUndo,
        onAction: () => cubit.freeze(outpoints),
      );
    }
  }
}

/// Top bar — swaps to a selection bar while selecting.
class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    if (state.selecting) {
      return _SelectionTopBar(state: state);
    }
    return BullTopBar(
      title: context.loc.coinsTitle,
      onBack: context.pop,
      onAction: state.status == CoinsStatus.ready
          ? () => openSortFilterSheet(context, state)
          : null,
      actionIcon: BullIcons.tune,
      actionBadge: state.filter.hasActiveFilter,
    );
  }
}

/// Shared helper to present the sort/filter sheet.
void openSortFilterSheet(BuildContext context, CoinsState state) {
  final cubit = context.read<CoinsCubit>();
  BullBottomSheet.show<void>(
    context: context,
    child: CoinsSortFilterSheet(
      filter: state.filter,
      allLabels: state.allLabels,
      onApply: (filter) {
        cubit.applyFilter(filter);
        context.pop();
      },
      onReset: () {
        cubit.clearFilters();
        context.pop();
      },
    ),
  );
}

class _SelectionTopBar extends StatelessWidget {
  const _SelectionTopBar({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final cubit = context.read<CoinsCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: cubit.exitSelect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BullIcon(BullIcons.close, size: 24, color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.loc.coinsSelectedCount(state.selectedOutpoints.length),
              style: context.bullText.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          GestureDetector(
            onTap: cubit.selectAllUnfrozen,
            child: Text(
              context.loc.coinsSelectAll,
              style: context.bullText.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-header: Sort & Filter button + result count + Sync + active chips.
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    final cubit = context.read<CoinsCubit>();
    final filter = state.filter;
    final filtered = filter.hasActiveFilter;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openSortFilterSheet(context, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: filtered
                        ? colors.primary.withValues(alpha: 0.08)
                        : colors.transparent,
                    borderRadius: BorderRadius.circular(BullRadius.full),
                    border: Border.all(
                      color: filtered ? colors.primary : colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BullIcon(
                        BullIcons.tune,
                        size: 15,
                        color: filtered ? colors.primary : colors.text,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loc.coinsSortFilter,
                        style: context.bullText.labelMedium?.copyWith(
                          color: filtered ? colors.primary : colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (filter.activeFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        BullBadge(
                          label: '${filter.activeFilterCount}',
                          background: colors.primary,
                          foreground: colors.onPrimary,
                          radius: BullRadius.full,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  filtered
                      ? loc.coinsShownOf(
                          state.visible.length,
                          state.utxos.length,
                        )
                      : loc.coinsUnspentOutputsCount(state.utxos.length),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.bullText.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BullSyncButton(
                label: loc.coinsSync,
                syncing: state.syncing,
                onPressed: () => context.read<WalletBloc>().add(
                  const WalletRefreshed(force: true),
                ),
              ),
            ],
          ),
          if (filtered) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._activeChips(context, state, cubit),
                GestureDetector(
                  onTap: cubit.clearFilters,
                  child: Text(
                    loc.coinsClearAll,
                    style: context.bullText.labelMedium?.copyWith(
                      color: colors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _activeChips(
    BuildContext context,
    CoinsState state,
    CoinsCubit cubit,
  ) {
    final loc = context.loc;
    final filter = state.filter;
    final chips = <Widget>[];

    if (filter.keychain != KeychainFilter.all) {
      chips.add(
        BullFilterChip(
          label: filter.keychain == KeychainFilter.receive
              ? loc.coinsKeychainReceive
              : loc.coinsKeychainChange,
          onRemove: () => cubit.applyFilter(
            filter.copyWith(keychain: KeychainFilter.all),
          ),
        ),
      );
    }
    if (filter.frozen != FrozenFilter.all) {
      chips.add(
        BullFilterChip(
          label: filter.frozen == FrozenFilter.frozen
              ? loc.coinsFrozenStatusFrozen
              : loc.coinsFrozenStatusUnfrozen,
          onRemove: () =>
              cubit.applyFilter(filter.copyWith(frozen: FrozenFilter.all)),
        ),
      );
    }
    for (final label in filter.labels) {
      chips.add(
        BullFilterChip(
          label: label,
          onRemove: () => cubit.applyFilter(
            filter.copyWith(labels: {...filter.labels}..remove(label)),
          ),
        ),
      );
    }
    return chips;
  }
}

/// The list / state region.
class _Body extends StatelessWidget {
  const _Body({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case CoinsStatus.loading:
        return const _LoadingSkeleton();
      case CoinsStatus.error:
        return _ErrorState(state: state);
      case CoinsStatus.empty:
        return const _EmptyState();
      case CoinsStatus.ready:
        if (state.isFilteredEmpty) return const _FilteredEmptyState();
        return _UtxoList(state: state);
    }
  }
}

class _UtxoList extends StatelessWidget {
  const _UtxoList({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CoinsCubit>();
    final visible = state.visible;

    return BullRefreshIndicator(
      onRefresh: () async {
        context.read<WalletBloc>().add(const WalletRefreshed(force: true));
        await cubit.refresh();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final utxo = visible[index];
          final key = utxoOutpointKey(utxo);
          return UtxoTile(
            key: ValueKey(key),
            utxo: utxo,
            selecting: state.selecting,
            selected: state.selectedOutpoints.contains(key),
            onTap: () => cubit.enterSelect(seedOutpoint: key),
            onLongPress: () => cubit.enterSelect(seedOutpoint: key),
            onToggle: () => cubit.toggle(key),
            onSwipeAction: () => _onSwipe(context, utxo.isFrozen, key),
            onCopied: () => BullSnackBar.show(
              context,
              message: context.loc.addressCardCopiedMessage,
              leadingIcon: BullIcons.contentCopy,
            ),
          );
        },
      ),
    );
  }

  Future<void> _onSwipe(
    BuildContext context,
    bool isFrozen,
    String key,
  ) async {
    final cubit = context.read<CoinsCubit>();
    if (isFrozen) {
      await cubit.unfreeze([key]);
      if (!context.mounted || cubit.state.error != null) return;
      BullSnackBar.show(
        context,
        message: context.loc.coinsUnfrozenToast(1),
        leadingIcon: BullIcons.lockOpen,
        actionLabel: context.loc.coinsUndo,
        onAction: () => cubit.freeze([key]),
      );
    } else {
      await cubit.freeze([key]);
      if (!context.mounted || cubit.state.error != null) return;
      BullSnackBar.show(
        context,
        message: context.loc.coinsFrozenToast(1),
        leadingIcon: BullIcons.acUnit,
      );
    }
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullShimmerLine(
                  width: 140,
                  height: 15,
                  padding: EdgeInsets.zero,
                ),
                SizedBox(height: 8),
                BullShimmerLine(
                  width: 90,
                  height: 11,
                  padding: EdgeInsets.zero,
                ),
                SizedBox(height: 8),
                BullShimmerLine(
                  width: 200,
                  height: 11,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: BullIcon(
                BullIcons.accountBalanceWallet,
                size: 34,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.loc.coinsEmptyTitle,
              textAlign: TextAlign.center,
              style: context.bullText.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.coinsEmptyBody,
              textAlign: TextAlign.center,
              style: context.bullText.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final cubit = context.read<CoinsCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullIcon(
              BullIcons.filterAltOff,
              size: 40,
              color: colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              context.loc.coinsFilteredEmptyTitle,
              textAlign: TextAlign.center,
              style: context.bullText.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 16),
            BullButton.small(
              label: context.loc.coinsClearFilters,
              onPressed: cubit.clearFilters,
              bgColor: colors.transparent,
              textColor: colors.primary,
              outlined: true,
              borderColor: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.state});

  final CoinsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final cubit = context.read<CoinsCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error?.toTranslated(context) ??
                  context.loc.coinsErrorUnexpected,
              textAlign: TextAlign.center,
              style: context.bullText.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            BullButton.small(
              label: context.loc.coinsErrorRetry,
              onPressed: cubit.refresh,
              bgColor: colors.primary,
              textColor: colors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullIcon(BullIcons.swipe, size: 15, color: colors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.loc.coinsSwipeHint,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bullText.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
