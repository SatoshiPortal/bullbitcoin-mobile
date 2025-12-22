import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CommonCoinSelectionBottomSheet extends StatefulWidget {
  final BitcoinUnit bitcoinUnit;
  final double exchangeRate;
  final String fiatCurrency;
  final List<WalletUtxo> utxos;
  final List<WalletUtxo> initialSelectedUtxos;
  final int amountToSendSat;
  final Function(List<WalletUtxo>) onDone;

  const CommonCoinSelectionBottomSheet({
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
  State<CommonCoinSelectionBottomSheet> createState() =>
      _CommonCoinSelectionBottomSheetState();
}

class _CommonCoinSelectionBottomSheetState
    extends State<CommonCoinSelectionBottomSheet> {
  late List<WalletUtxo> _selectedUtxos;

  @override
  void initState() {
    super.initState();
    _selectedUtxos = List.of(widget.initialSelectedUtxos);
  }

  void _onUtxoTapped(WalletUtxo utxo) {
    setState(() {
      if (_selectedUtxos.contains(utxo)) {
        _selectedUtxos.remove(utxo);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  "Select amount",
                  style: context.font.headlineMedium?.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: Icon(Icons.close, color: context.appColors.secondary),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          BBText(
            selectedUtxoTotal,
            style: context.font.displaySmall?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
          const Gap(8),
          BBText(
            'Amount requested: $amountToSend',
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = widget.utxos[index];
              return CommonCoinSelectTile(
                utxo: utxo,
                selected: _selectedUtxos.contains(utxo),
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
          BBButton.big(
            label: "Done",
            onPressed: selectedUtxoTotalSat >= widget.amountToSendSat
                ? _onDonePressed
                : () {},
            disabled: selectedUtxoTotalSat < widget.amountToSendSat,
            bgColor: selectedUtxoTotalSat >= widget.amountToSendSat
                ? context.appColors.secondary
                : context.appColors.outlineVariant,
            textColor: selectedUtxoTotalSat >= widget.amountToSendSat
                ? context.appColors.onSecondary
                : context.appColors.outline,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class CommonCoinSelectTile extends StatelessWidget {
  final WalletUtxo utxo;
  final bool selected;
  final VoidCallback onTap;
  final BitcoinUnit bitcoinUnit;
  final double exchangeRate;
  final String fiatCurrency;

  const CommonCoinSelectTile({
    super.key,
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

    final fiatEquivalent = FormatAmount.fiat(
      ConvertAmount.satsToFiat(utxo.amountSat.toInt(), exchangeRate),
      fiatCurrency,
    );

    final address = utxo.address;
    final addressType = utxo.addressKeyChain == WalletAddressKeyChain.external
        ? 'Receive'
        : 'Change';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: context.appColors.transparent,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        BBText(
                          '$utxoValue ',
                          style: context.font.displaySmall?.copyWith(
                            color: context.appColors.secondary,
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
                  BBText(
                    '~$fiatEquivalent',
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Divider(color: context.appColors.secondaryFixedDim),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BBText(
                        'Address: ',
                        style: context.font.labelMedium?.copyWith(
                          color: context.appColors.secondary,
                        ),
                      ),
                      Expanded(
                        child: BBText(
                          StringFormatting.truncateMiddle(address),
                          style: context.font.labelLarge?.copyWith(
                            color: context.appColors.secondary,
                          ),
                        ),
                      ),
                      BBText(
                        'Type: ',
                        style: context.font.labelMedium?.copyWith(
                          color: context.appColors.secondary,
                        ),
                      ),
                      BBText(
                        addressType,
                        style: context.font.labelLarge?.copyWith(
                          color: context.appColors.secondary,
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
