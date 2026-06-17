import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A single coin (UTXO) row. Domain-aware composite that lives in the feature
/// (it knows [WalletUtxo]); it is built entirely out of `bull_ui` primitives.
///
/// Layout (§14):
/// - L1: amount (tabular) + keychain badge.
/// - L2: fiat (when available).
/// - L3: truncated address + copy · conf pill.
/// - L4: Frozen pill + label chips.
/// A frozen tile is dimmed with an info-blue left accent; a selected tile gets a
/// red left accent and a tinted background. In selection mode a [BullCheckbox]
/// is shown; otherwise the row reveals a Freeze/Unfreeze swipe action.
class UtxoTile extends StatelessWidget {
  const UtxoTile({
    super.key,
    required this.utxo,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
    required this.onSwipeAction,
    required this.onCopied,
  });

  final WalletUtxo utxo;
  final bool selecting;
  final bool selected;

  /// Tap when not selecting → enter selection seeded with this coin; tap while
  /// selecting → toggle.
  final VoidCallback onTap;

  /// Long-press → enter selection.
  final VoidCallback onLongPress;

  /// Toggle this coin's checkbox (selection mode only).
  final VoidCallback onToggle;

  /// Swipe action committed (freeze if unfrozen, unfreeze if frozen).
  final VoidCallback onSwipeAction;

  /// Address was copied to the clipboard.
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;

    final bitcoinUnit =
        context.select((SettingsCubit c) => c.state.bitcoinUnit) ??
        BitcoinUnit.btc;
    final hideAmounts =
        context.select((SettingsCubit c) => c.state.hideAmounts) ?? true;
    final fiat = context.select(
      (BitcoinPriceBloc b) => b.state.calculateFiatPrice(utxo.amountSat.toInt()),
    );

    final amount = bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(utxo.amountSat.toInt()))
        : FormatAmount.sats(utxo.amountSat.toInt());

    final accent = selected
        ? colors.primary
        : utxo.isFrozen
        ? colors.info
        : colors.transparent;

    final tile = Container(
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.09)
            : colors.cardBackground,
        border: Border(
          left: BorderSide(color: accent, width: 3),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Opacity(
        opacity: utxo.isFrozen && !selected ? 0.62 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: BullCheckbox(
                    checked: selected,
                    disabled: utxo.isFrozen,
                    onChanged: (_) => onToggle(),
                  ),
                ),
                const SizedBox(width: 11),
              ] else if (utxo.isFrozen) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: BullIcon(
                    BullIcons.acUnit,
                    size: 20,
                    color: colors.info,
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line1(context, amount, hideAmounts),
                    if (fiat != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hideAmounts ? '••••' : fiat,
                        style: context.bullText.labelLarge?.copyWith(
                          fontSize: 12,
                          color: colors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    _line3(context),
                    const SizedBox(height: 8),
                    _line4(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tappable = GestureDetector(
      onTap: selecting ? onToggle : onTap,
      onLongPress: selecting ? null : onLongPress,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );

    return BullSwipeAction(
      enabled: !selecting,
      actionLabel: utxo.isFrozen
          ? context.loc.coinsUnfreeze
          : context.loc.coinsFreeze,
      actionIcon: utxo.isFrozen ? BullIcons.lockOpen : BullIcons.acUnit,
      actionColor: utxo.isFrozen ? colors.textMuted : colors.info,
      actionForeground: colors.onPrimary,
      onAction: onSwipeAction,
      child: tappable,
    );
  }

  Widget _line1(BuildContext context, String amount, bool hideAmounts) {
    final colors = context.bull;
    return Row(
      children: [
        Expanded(
          child: Text(
            hideAmounts ? '••••••' : amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.bullText.titleMedium?.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: colors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _keychainBadge(context),
      ],
    );
  }

  Widget _keychainBadge(BuildContext context) {
    final colors = context.bull;
    final isReceive =
        utxo.addressKeyChain == WalletAddressKeyChain.external;
    // Receive = bitcoin-orange text on orange@14%; Change = muted on muted@16%.
    final accent = isReceive ? colors.bitcoinOrange : colors.textMuted;
    return BullBadge(
      label: isReceive
          ? context.loc.coinsKeychainReceive
          : context.loc.coinsKeychainChange,
      uppercase: true,
      radius: BullRadius.xxs,
      background: accent.withValues(alpha: isReceive ? 0.14 : 0.16),
      foreground: accent,
    );
  }

  Widget _line3(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: BullAddressText(address: utxo.address, onCopied: onCopied),
        ),
        const SizedBox(width: 8),
        _confPill(context),
      ],
    );
  }

  Widget _confPill(BuildContext context) {
    final colors = context.bull;
    final pending = utxo.confirmations == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BullIcon(
          pending ? BullIcons.schedule : BullIcons.checkCircle,
          size: 13,
          color: pending ? colors.warning : colors.success,
        ),
        const SizedBox(width: 4),
        Text(
          pending
              ? context.loc.coinsPending
              : context.loc.coinsConfsCount(utxo.confirmations),
          style: context.bullText.labelLarge?.copyWith(
            fontSize: 11,
            fontWeight: pending ? FontWeight.w500 : FontWeight.w400,
            color: pending ? colors.warning : colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _line4(BuildContext context) {
    final colors = context.bull;
    final labels = <String>[
      ...utxo.labels.map((l) => l.label),
      ...utxo.addressLabels.map((l) => l.label),
      ...utxo.txLabels.map((l) => l.label),
    ].where((l) => l.isNotEmpty).toList();

    if (!utxo.isFrozen && labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (utxo.isFrozen)
          BullPill(
            label: context.loc.coinsFrozen,
            icon: BullIcons.acUnit,
            iconSize: 11,
            background: colors.info.withValues(alpha: 0.14),
            foreground: colors.info,
          ),
        for (final label in labels) BullLabelChip(label: label),
      ],
    );
  }
}
