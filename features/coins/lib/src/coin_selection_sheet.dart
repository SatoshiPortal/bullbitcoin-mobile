import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

typedef CoinSelectionEntry = ({
  Outpoint outpoint,
  Sats amount,
  String address,
  String addressType,
});

typedef CoinSelectionLabels = ({
  String title,
  String close,
  String Function(String amount) requested,
  String insufficient,
  String address,
  String type,
  String done,
});

/// The caller supplies currently eligible coins and owns the address renderer.
/// This sheet never authorizes spending; the spend path checks eligibility again.
class CoinSelectionSheet extends StatefulWidget {
  final BitcoinUnit bitcoinUnit;
  final double? exchangeRate;
  final String fiatCurrency;
  final List<CoinSelectionEntry> coins;
  final Set<Outpoint> initialSelection;
  final Sats requestedAmount;
  final CoinSelectionLabels labels;
  final ValueChanged<Set<Outpoint>> onDone;
  final ValueChanged<Outpoint>? onToggle;
  final bool? doneEnabled;
  final bool? showInsufficient;
  final Widget? Function(CoinSelectionEntry)? statusBuilder;
  final Widget? Function(CoinSelectionEntry)? labelsBuilder;
  final bool Function(CoinSelectionEntry)? showAddressType;

  /// Renders the displayed address, including any accessible actions it offers.
  final Widget Function(String address, TextStyle style, Color color)
  addressBuilder;

  const CoinSelectionSheet({
    super.key,
    required this.bitcoinUnit,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.coins,
    required this.initialSelection,
    required this.requestedAmount,
    required this.labels,
    required this.onDone,
    required this.addressBuilder,
    this.onToggle,
    this.doneEnabled,
    this.showInsufficient,
    this.statusBuilder,
    this.labelsBuilder,
    this.showAddressType,
  });

  @override
  State<CoinSelectionSheet> createState() => _CoinSelectionSheetState();
}

class _CoinSelectionSheetState extends State<CoinSelectionSheet> {
  late Set<Outpoint> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final coin in widget.coins)
        if (widget.initialSelection.contains(coin.outpoint)) coin.outpoint,
    };
  }

  @override
  void didUpdateWidget(CoinSelectionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final eligible = {for (final coin in widget.coins) coin.outpoint};
    _selected.removeWhere((outpoint) => !eligible.contains(outpoint));
  }

  void _toggle(Outpoint outpoint) {
    final onToggle = widget.onToggle;
    if (onToggle != null) {
      onToggle(outpoint);
      return;
    }
    setState(() {
      if (!_selected.remove(outpoint)) _selected.add(outpoint);
    });
  }

  String _formatBitcoin(BigInt amount) => switch (widget.bitcoinUnit) {
    BitcoinUnit.btc => FormatAmount.btc(
      ConvertAmount.satsToBtc(amount.toInt()),
    ),
    BitcoinUnit.sats => FormatAmount.sats(amount.toInt()),
  };

  String? _formatFiat(BigInt amount) {
    final rate = widget.exchangeRate;
    if (rate == null || rate <= 0) return null;
    return FormatAmount.fiat(
      ConvertAmount.satsToFiat(amount.toInt(), rate),
      widget.fiatCurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final selected = widget.onToggle == null
        ? _selected
        : widget.initialSelection;
    final coins = {for (final coin in widget.coins) coin.outpoint: coin}.values
        .toList();
    final total = coins
        .where((coin) => selected.contains(coin.outpoint))
        .fold(BigInt.zero, (sum, coin) => sum + coin.amount.value);
    final hasEnough = total >= widget.requestedAmount.value;
    final totalFiat = _formatFiat(total);
    final type = context.bullType;
    final colors = context.bull;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Semantics(
                  header: true,
                  child: BullText(
                    labels.title,
                    textAlign: TextAlign.center,
                    style: type.subtitle.copyWith(color: colors.secondary),
                  ),
                ),
              ),
              BullInlineIconButton(
                tooltip: labels.close,
                icon: const BullIcon(BullIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(32),
          BullText(
            _formatBitcoin(total),
            style: type.headline.copyWith(color: colors.secondary),
          ),
          if (totalFiat != null) ...[
            const Gap(4),
            BullText(
              '~$totalFiat',
              style: type.body.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const Gap(8),
          BullText(
            labels.requested(_formatBitcoin(widget.requestedAmount.value)),
            style: type.label.copyWith(color: colors.onSurfaceVariant),
          ),
          if (widget.showInsufficient ?? !hasEnough) ...[
            const Gap(8),
            BullText(
              labels.insufficient,
              style: type.label.copyWith(color: colors.error),
            ),
          ],
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: coins.length,
            shrinkWrap: true,
            separatorBuilder: (_, _) => const Gap(24),
            itemBuilder: (_, index) {
              final coin = coins[index];
              final amount = _formatBitcoin(coin.amount.value);
              final fiat = _formatFiat(coin.amount.value);
              final isSelected = selected.contains(coin.outpoint);
              final status = widget.statusBuilder?.call(coin);
              final coinLabels = widget.labelsBuilder?.call(coin);
              return BullBorderedTile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      key: ValueKey(coin.outpoint),
                      container: true,
                      label: '$amount, ${coin.address}',
                      checked: isSelected,
                      button: true,
                      onTap: () => _toggle(coin.outpoint),
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          onTap: () => _toggle(coin.outpoint),
                          behavior: HitTestBehavior.opaque,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                BullText(amount, style: type.headline),
                                BullCheckbox(
                                  checked: isSelected,
                                  onChanged: null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (fiat != null)
                      BullText(
                        '~$fiat',
                        style: type.caption.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    if (status != null) ...[const Gap(4), status],
                    const Gap(12),
                    Container(height: 1, color: colors.secondaryFixedDim),
                    Row(
                      children: [
                        BullText(labels.address, style: type.caption),
                        const Gap(4),
                        Expanded(
                          child: widget.addressBuilder(
                            coin.address,
                            type.label,
                            colors.onSurface,
                          ),
                        ),
                        if (widget.showAddressType?.call(coin) ?? true) ...[
                          const Gap(8),
                          BullText(labels.type, style: type.caption),
                          const Gap(4),
                          BullText(coin.addressType, style: type.label),
                        ],
                      ],
                    ),
                    if (coinLabels != null) ...[const Gap(8), coinLabels],
                  ],
                ),
              );
            },
          ),
          const Gap(24),
          BullButton.secondary(
            label: labels.done,
            onPressed: (widget.doneEnabled ?? hasEnough)
                ? () {
                    final navigator = Navigator.of(context);
                    widget.onDone(Set.unmodifiable(selected));
                    if (navigator.mounted) navigator.pop();
                  }
                : null,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
