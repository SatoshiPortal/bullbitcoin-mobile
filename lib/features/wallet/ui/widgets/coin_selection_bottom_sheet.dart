import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShapesX, BullText, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class WalletCoinSelectionBottomSheet extends StatefulWidget {
  final BitcoinUnit bitcoinUnit;
  final double? exchangeRate;
  final String fiatCurrency;
  final List<WalletUtxo> utxos;
  final List<WalletUtxo> initialSelectedUtxos;
  final int amountToSendSat;
  final ValueChanged<List<WalletUtxo>> onDone;

  const WalletCoinSelectionBottomSheet({
    super.key,
    required this.bitcoinUnit,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.utxos,
    required this.initialSelectedUtxos,
    required this.amountToSendSat,
    required this.onDone,
  });

  @override
  State<WalletCoinSelectionBottomSheet> createState() =>
      _WalletCoinSelectionBottomSheetState();
}

class _WalletCoinSelectionBottomSheetState
    extends State<WalletCoinSelectionBottomSheet> {
  late List<WalletUtxo> _selectedUtxos;

  @override
  void initState() {
    super.initState();
    // Only keep pre-selected coins that are actually selectable (present in
    // [utxos]). Callers hide frozen coins (D7), so a coin selected earlier and
    // frozen since must not linger in the selection — it can't be shown or
    // deselected here and would otherwise inflate the total / "sufficient" check.
    final selectedOutpoints = widget.initialSelectedUtxos
        .map((u) => u.outpoint)
        .toSet();
    _selectedUtxos = widget.utxos
        .where((u) => selectedOutpoints.contains(u.outpoint))
        .toList();
  }

  void _onUtxoTapped(WalletUtxo utxo) {
    setState(() {
      final selectedIndex = _selectedUtxos.indexWhere(
        (u) => u.outpoint == utxo.outpoint,
      );
      if (selectedIndex >= 0) {
        _selectedUtxos.removeAt(selectedIndex);
      } else {
        _selectedUtxos.add(utxo);
      }
    });
  }

  void _onDonePressed() {
    widget.onDone(_selectedUtxos);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedUtxoTotalSat = _selectedUtxos.fold(
      0,
      (previousValue, element) => previousValue + element.amountSat.toInt(),
    );
    final selectedUtxoTotal = widget.bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedUtxoTotalSat))
        : FormatAmount.sats(selectedUtxoTotalSat);
    final amountToSend = widget.bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(widget.amountToSendSat))
        : FormatAmount.sats(widget.amountToSendSat);

    final isAmountSufficient = selectedUtxoTotalSat >= widget.amountToSendSat;

    final rate = widget.exchangeRate;
    final selectedFiatEquivalent = rate != null && rate > 0
        ? FormatAmount.fiat(
            ConvertAmount.satsToFiat(selectedUtxoTotalSat, rate),
            widget.fiatCurrency,
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: .min,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Semantics(
                  header: true,
                  child: BullText(
                    context.loc.selectAmountTitle,
                    textAlign: TextAlign.center,
                    style: context.bullType.subtitle
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.loc.closeDialogButton,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                iconSize: 24,
                icon: Icon(Icons.close, color: context.appColors.secondary),
                onPressed: context.pop,
              ),
            ],
          ),
          const Gap(32),
          BullText(
            selectedUtxoTotal,
            style: context.bullType.headline.copyWith(
              color: context.appColors.secondary,
            ),
          ),
          if (selectedFiatEquivalent != null) ...[
            const Gap(4),
            BullText(
              '~$selectedFiatEquivalent',
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.appColors.onSurfaceVariant),
            ),
          ],
          const Gap(8),
          BullText(
            context.loc.amountRequestedLabel(amountToSend),
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.onSurfaceVariant),
          ),
          if (!isAmountSufficient) ...[
            const Gap(8),
            BullText(
              context.loc.sendSelectedUtxosInsufficient,
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: context.appColors.error),
            ),
          ],
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = widget.utxos[index];
              return _CoinSelectTile(
                utxo: utxo,
                selected: _selectedUtxos.any(
                  (u) => u.outpoint == utxo.outpoint,
                ),
                onTap: () => _onUtxoTapped(utxo),
                exchangeRate: widget.exchangeRate,
                bitcoinUnit: widget.bitcoinUnit,
                fiatCurrency: widget.fiatCurrency,
              );
            },
            separatorBuilder: (_, _) => const Gap(24),
            itemCount: widget.utxos.length,
            shrinkWrap: true,
          ),
          const Gap(24),
          BullButton.secondary(
            label: context.loc.doneButton,
            onPressed: isAmountSufficient ? _onDonePressed : null,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class _CoinSelectTile extends StatelessWidget {
  final WalletUtxo utxo;
  final bool selected;
  final VoidCallback onTap;
  final BitcoinUnit bitcoinUnit;
  final double? exchangeRate;
  final String fiatCurrency;

  const _CoinSelectTile({
    required this.utxo,
    required this.selected,
    required this.onTap,
    required this.bitcoinUnit,
    required this.exchangeRate,
    required this.fiatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final utxoValue = bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(utxo.amountSat.toInt()))
        : FormatAmount.sats(utxo.amountSat.toInt());

    final rate = exchangeRate;
    final fiatEquivalent = rate != null && rate > 0
        ? FormatAmount.fiat(
            ConvertAmount.satsToFiat(utxo.amountSat.toInt(), rate),
            fiatCurrency,
          )
        : null;

    final address = utxo.address;
    final addressType = utxo.addressKeyChain == WalletAddressKeyChain.external
        ? context.loc.coinsKeychainReceive
        : context.loc.coinsKeychainChange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          border: Border.all(color: context.appColors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                    tileColor: context.appColors.transparent,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        BullText(
                          '$utxoValue ',
                          style: context.bullType.headline.copyWith(
                            color: context.appColors.onSurface,
                            fontWeight: .w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: RadioGroup<bool>(
                      groupValue: selected,
                      onChanged: (_) => onTap(),
                      child: Radio<bool>(
                        value: true,
                        activeColor: context.appColors.secondary,
                      ),
                    ),
                  ),
                  if (fiatEquivalent != null)
                    BullText(
                      '~$fiatEquivalent',
                      style: context.bullType.caption.copyWith(
                        color: context.appColors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),

                  Divider(color: context.appColors.secondaryFixedDim),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BullText(
                        context.loc.addressLabel,
                        style: context.bullType.caption.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: AddressViewer(
                          address,
                          style: context.bullType.label,
                          color: context.appColors.onSurface,
                        ),
                      ),
                      BullText(
                        context.loc.typeLabel,
                        style: context.bullType.caption.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                      BullText(
                        addressType,
                        style: context.bullType.label.copyWith(
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
