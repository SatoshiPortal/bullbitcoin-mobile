import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:bull_ui/bull_ui.dart';

/// The Sort & Filter bottom sheet (§14). Edits a working copy of [CoinsFilter]
/// and returns it via [onApply]; [onReset] restores defaults (keeping the
/// current sort). Presented through [BullBottomSheet.show].
class CoinsSortFilterSheet extends StatefulWidget {
  const CoinsSortFilterSheet({
    super.key,
    required this.filter,
    required this.allLabels,
    required this.onApply,
    required this.onReset,
  });

  final CoinsFilter filter;
  final Set<String> allLabels;
  final ValueChanged<CoinsFilter> onApply;
  final VoidCallback onReset;

  @override
  State<CoinsSortFilterSheet> createState() => _CoinsSortFilterSheetState();
}

class _CoinsSortFilterSheetState extends State<CoinsSortFilterSheet> {
  late CoinsSort _sort = widget.filter.sort;
  late KeychainFilter _keychain = widget.filter.keychain;
  late FrozenFilter _frozen = widget.filter.frozen;
  late final Set<String> _labels = {...widget.filter.labels};

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(BullRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.coinsSortFilter,
            style: context.bullText.titleLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 16),

          _sortGrid(context),
          const SizedBox(height: 20),

          _sectionLabel(context, loc.coinsKeychain),
          BullSegmented(
            items: {
              loc.coinsKeychainAll,
              loc.coinsKeychainReceive,
              loc.coinsKeychainChange,
            },
            initialValue: switch (_keychain) {
              KeychainFilter.all => loc.coinsKeychainAll,
              KeychainFilter.receive => loc.coinsKeychainReceive,
              KeychainFilter.change => loc.coinsKeychainChange,
            },
            onSelected: (v) {
              setState(() {
                if (v == loc.coinsKeychainReceive) {
                  _keychain = KeychainFilter.receive;
                } else if (v == loc.coinsKeychainChange) {
                  _keychain = KeychainFilter.change;
                } else {
                  _keychain = KeychainFilter.all;
                }
              });
            },
          ),
          const SizedBox(height: 20),

          _sectionLabel(context, loc.coinsFrozenStatus),
          BullSegmented(
            items: {
              loc.coinsFrozenStatusAll,
              loc.coinsFrozenStatusUnfrozen,
              loc.coinsFrozenStatusFrozen,
            },
            initialValue: switch (_frozen) {
              FrozenFilter.all => loc.coinsFrozenStatusAll,
              FrozenFilter.unfrozen => loc.coinsFrozenStatusUnfrozen,
              FrozenFilter.frozen => loc.coinsFrozenStatusFrozen,
            },
            onSelected: (v) {
              setState(() {
                if (v == loc.coinsFrozenStatusUnfrozen) {
                  _frozen = FrozenFilter.unfrozen;
                } else if (v == loc.coinsFrozenStatusFrozen) {
                  _frozen = FrozenFilter.frozen;
                } else {
                  _frozen = FrozenFilter.all;
                }
              });
            },
          ),

          if (widget.allLabels.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel(context, loc.coinsLabels),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in widget.allLabels)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (!_labels.remove(label)) _labels.add(label);
                    }),
                    child: _toggleChip(context, label, _labels.contains(label)),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: BullButton.big(
                  label: loc.coinsReset,
                  onPressed: () {
                    widget.onReset();
                  },
                  bgColor: colors.transparent,
                  textColor: colors.primary,
                  outlined: true,
                  borderColor: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BullButton.big(
                  label: loc.coinsApply,
                  onPressed: () {
                    widget.onApply(
                      CoinsFilter(
                        sort: _sort,
                        keychain: _keychain,
                        frozen: _frozen,
                        labels: _labels,
                      ),
                    );
                  },
                  bgColor: colors.primary,
                  textColor: colors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: context.bullText.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: context.bull.textMuted,
        ),
      ),
    );
  }

  Widget _sortGrid(BuildContext context) {
    final loc = context.loc;
    final options = <(CoinsSort, String)>[
      (CoinsSort.amountDesc, loc.coinsSortAmountDesc),
      (CoinsSort.amountAsc, loc.coinsSortAmountAsc),
      (CoinsSort.dateNewest, loc.coinsSortDateNew),
      (CoinsSort.dateOldest, loc.coinsSortDateOld),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _sortButton(
                    context,
                    options[row * 2 + col].$1,
                    options[row * 2 + col].$2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _sortButton(BuildContext context, CoinsSort sort, String label) {
    final colors = context.bull;
    final active = _sort == sort;
    return GestureDetector(
      onTap: () => setState(() => _sort = sort),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.08)
              : colors.transparent,
          borderRadius: BorderRadius.circular(BullRadius.xs),
          border: Border.all(
            color: active ? colors.primary : colors.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.bullText.labelMedium?.copyWith(
            color: active ? colors.primary : colors.text,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _toggleChip(BuildContext context, String label, bool active) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active ? colors.primary.withValues(alpha: 0.08) : colors.surface,
        borderRadius: BorderRadius.circular(BullRadius.xxs),
        border: Border.all(
          color: active ? colors.primary : colors.outlineVariant,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullIcon(
            BullIcons.sell,
            size: 12,
            color: active ? colors.primary : colors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.bullText.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: active ? colors.primary : colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
