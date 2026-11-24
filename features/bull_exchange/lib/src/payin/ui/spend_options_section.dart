import 'dart:async';

import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/payin/payin_coin_selection.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAdvancedOptionsLink,
        BullBottomSheet,
        BullButton,
        BullDetailsTableItem,
        BullShapesX,
        BullSwitch,
        BullText,
        BullTypographyX,
        Gap;
import 'package:fees/fees.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, FormatAmount;

/// The copy of the spend options: sell and pay each ship their own strings.
typedef SpendOptionsLabels = ({
  String feePriority,
  String fastest,
  String networkFees,
  String advancedSettings,
  String advancedOptions,
  String replaceByFee,
  String selectCoins,
  String done,
  String feesUnavailable,
});

/// The spend options of a sell or pay review, as before C5a: the fee
/// priority (shared fee sheet, presets and custom), the network fee of the
/// payin at that fee, the payjoin switch when the order offers payjoin, and
/// the advanced options (replace-by-fee, coins picked by hand). A failed
/// fee estimate says so and offers Retry; nothing is assumed.
class SpendOptionsSection extends StatelessWidget {
  const SpendOptionsSection({
    super.key,
    required this.spend,
    required this.changes,
    required this.current,
    required this.labels,
    required this.payjoinOffered,
    required this.amountSat,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.onEvent,
  });

  final SpendOptionsState spend;

  /// Later states of the options, for the sheets opened from here.
  final Stream<SpendOptionsState> changes;
  final SpendOptionsState Function() current;
  final SpendOptionsLabels labels;
  final bool payjoinOffered;
  final int amountSat;
  final double? exchangeRate;
  final String fiatCurrency;
  final void Function(SpendOptionsEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    return switch (spend) {
      SpendOptionsNone() || SpendOptionsFixed() => const SizedBox.shrink(),
      SpendFeesLoading() => BullDetailsTableItem(
        label: labels.feePriority,
        displayWidget: const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      SpendFeesUnavailable() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              labels.feesUnavailable,
              textAlign: TextAlign.center,
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
            ),
            const Gap(8),
            BullButton.secondary(
              label: context.loc.retry,
              onPressed: () => onEvent(const SpendRetryPressed()),
            ),
          ],
        ),
      ),
      final SpendOptionsReady ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullDetailsTableItem(
            label: labels.feePriority,
            displayValue: feeSelectionRowLabel(
              context,
              ui: FeeUi.standard,
              selection: ready.selection,
              customFee: ready.customFee,
              fastestLabel: labels.fastest,
            ),
            onValueTap: () => unawaited(_openFees(context, ready)),
          ),
          BullDetailsTableItem(
            label: labels.networkFees,
            displayValue: switch (ready.previews
                .slotFor(ready.selection)
                .feeSat) {
              final sats? => FormatAmount.sats(sats),
              null => '…',
            },
          ),
          if (payjoinOffered)
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.payjoinUseToggle,
                    style: context.bullType.body,
                  ),
                ),
                BullSwitch(
                  value: ready.payjoin,
                  onChanged: (enabled) =>
                      onEvent(SpendPayjoinChanged(enabled: enabled)),
                ),
              ],
            ),
          const Gap(8),
          BullAdvancedOptionsLink(
            label: labels.advancedSettings,
            onPressed: () => unawaited(
              BullBottomSheet.show<void>(
                context: context,
                child: _AdvancedOptionsSheet(
                  changes: changes,
                  current: current,
                  labels: labels,
                  amountSat: amountSat,
                  exchangeRate: exchangeRate,
                  fiatCurrency: fiatCurrency,
                  onEvent: onEvent,
                ),
              ),
            ),
          ),
        ],
      ),
    };
  }

  Future<void> _openFees(BuildContext context, SpendOptionsReady ready) async {
    final port = SpendFeeModalPort(
      changes: changes,
      current: current,
      send: onEvent,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
    );
    final picked = await BullBottomSheet.show<String>(
      context: context,
      child: FeeOptionsModal(
        ui: FeeUi.standard,
        viewState: port,
        actions: port,
        defaultAbsoluteCustomFee: false,
        customFeeColors: FeeModalCustomFeeColors(
          tile: context.appColors.surface,
          shadow: context.appColors.border,
          unselectedIcon: context.appColors.textMuted,
        ),
      ),
    );
    if (picked != null) {
      onEvent(SpendFeePicked(FeeSelectionName.fromString(picked)));
    } else {
      // Typing is the selection and closing applies it (or rolls back a
      // value under the relay floor).
      onEvent(const SpendCustomFeeFinalized());
    }
  }
}

/// The shared fee sheet over the spend options: it reads their snapshot and
/// its actions become spend-options events.
final class SpendFeeModalPort
    implements FeeModalStatePort, FeeModalActionsPort {
  SpendFeeModalPort({
    required this._changes,
    required this._current,
    required this._send,
    required this._exchangeRate,
    required this._fiatCurrency,
  });

  final Stream<SpendOptionsState> _changes;
  final SpendOptionsState Function() _current;
  final void Function(SpendOptionsEvent event) _send;
  final double? _exchangeRate;
  final String _fiatCurrency;

  FeeModalSnapshot _of(SpendOptionsState state) => switch (state) {
    final SpendOptionsReady ready => FeeModalSnapshot(
      feePresets: ready.fees,
      customFee: ready.customFee,
      selectedFeeOption: ready.selection,
      feePreviewCache: ready.previews,
      exchangeRate: _exchangeRate,
      fiatCurrencyCode: _fiatCurrency,
      txSize: ready.txSize,
    ),
    SpendOptionsNone() ||
    SpendOptionsFixed() ||
    SpendFeesLoading() ||
    SpendFeesUnavailable() => FeeModalSnapshot(
      feePresets: null,
      customFee: null,
      selectedFeeOption: FeeSelection.fastest,
      feePreviewCache: BitcoinFeePreviewCache.empty,
      exchangeRate: _exchangeRate,
      fiatCurrencyCode: _fiatCurrency,
      txSize: 140,
    ),
  };

  @override
  FeeModalSnapshot get snapshot => _of(_current());

  @override
  Stream<FeeModalSnapshot> get snapshots => _changes.map(_of);

  @override
  void requestPresetPreviews() => _send(const SpendPresetPreviewsRequested());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      _send(SpendCustomPreviewRequested(fee));

  @override
  void armCustomFee(NetworkFee fee) => _send(SpendCustomFeeArmed(fee));

  @override
  void disarmCustomFee() => _send(const SpendCustomFeeDisarmed());

  @override
  void finalizeArmedCustomFee() => _send(const SpendCustomFeeFinalized());

  @override
  void selectFeeOption(FeeSelection selection) =>
      _send(SpendFeePicked(selection));
}

class _AdvancedOptionsSheet extends StatelessWidget {
  const _AdvancedOptionsSheet({
    required this.changes,
    required this.current,
    required this.labels,
    required this.amountSat,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.onEvent,
  });

  final Stream<SpendOptionsState> changes;
  final SpendOptionsState Function() current;
  final SpendOptionsLabels labels;
  final int amountSat;
  final double? exchangeRate;
  final String fiatCurrency;
  final void Function(SpendOptionsEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpendOptionsState>(
      stream: changes,
      initialData: current(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        final rbf = state is SpendOptionsReady && state.replaceByFee;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.bullShapes.sheet),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: BullText(
                      labels.advancedOptions,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      iconSize: 24,
                      tooltip: context.loc.closeDialogButton,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const Gap(32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: BullText(
                      labels.replaceByFee,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: rbf,
                    onChanged: state is SpendOptionsReady
                        ? (enabled) =>
                              onEvent(SpendRbfChanged(enabled: enabled))
                        : null,
                  ),
                ],
              ),
              const Gap(24),
              ListTile(
                title: BullText(
                  labels.selectCoins,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: state is SpendOptionsReady
                    ? () {
                        onEvent(const SpendCoinsRequested());
                        unawaited(
                          BullBottomSheet.show<void>(
                            context: context,
                            child: _CoinsSheet(
                              changes: changes,
                              current: current,
                              amountSat: amountSat,
                              exchangeRate: exchangeRate,
                              fiatCurrency: fiatCurrency,
                              onEvent: onEvent,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              const Gap(24),
              BullButton.secondary(
                label: labels.done,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The wallet's spendable coins (frozen ones hidden) to pick by hand; while
/// they load a spinner, a failed read says so with Retry.
class _CoinsSheet extends StatelessWidget {
  const _CoinsSheet({
    required this.changes,
    required this.current,
    required this.amountSat,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.onEvent,
  });

  final Stream<SpendOptionsState> changes;
  final SpendOptionsState Function() current;
  final int amountSat;
  final double? exchangeRate;
  final String fiatCurrency;
  final void Function(SpendOptionsEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpendOptionsState>(
      stream: changes,
      initialData: current(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state is! SpendOptionsReady) return const SizedBox.shrink();
        return switch (state.coins) {
          SpendCoinsLoaded(:final coins) => payinCoinSelection(
            context: context,
            bitcoinUnit: BitcoinUnit.sats,
            exchangeRate: exchangeRate,
            fiatCurrency: fiatCurrency,
            utxos: coins,
            initialSelectedUtxos: state.selected,
            amountToSendSat: amountSat,
            onDone: (picked) => onEvent(SpendCoinsPicked(picked)),
          ),
          SpendCoinsUnavailable() => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.loc.exchangePayinCoinsUnavailable,
                  textAlign: TextAlign.center,
                  style: context.bullType.body.copyWith(
                    color: context.appColors.error,
                  ),
                ),
                const Gap(16),
                BullButton.secondary(
                  label: context.loc.retry,
                  onPressed: () => onEvent(const SpendCoinsRequested()),
                ),
              ],
            ),
          ),
          SpendCoinsNotLoaded() || SpendCoinsLoading() => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        };
      },
    );
  }
}
