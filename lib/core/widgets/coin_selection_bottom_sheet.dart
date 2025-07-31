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

class CommonCoinSelectionBottomSheet extends StatelessWidget {
  final BitcoinUnit bitcoinUnit;
  final double exchangeRate;
  final String fiatCurrency;
  final List<WalletUtxo> utxos;
  final List<WalletUtxo> selectedUtxos;
  final int amountToSendSat;
  final Function(WalletUtxo) onUtxoSelected;

  const CommonCoinSelectionBottomSheet({
    super.key,
    required this.bitcoinUnit,
    required this.exchangeRate,
    required this.fiatCurrency,
    required this.utxos,
    required this.selectedUtxos,
    required this.amountToSendSat,
    required this.onUtxoSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedUtxoTotalSat = selectedUtxos.fold(
      0,
      (previousValue, element) => previousValue + element.amountSat.toInt(),
    );
    final selectedUtxoTotal =
        bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedUtxoTotalSat))
            : FormatAmount.sats(selectedUtxoTotalSat);
    final amountToSend =
        bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(amountToSendSat))
            : FormatAmount.sats(amountToSendSat);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  "Select amount",
                  style: context.font.headlineMedium,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: const Icon(Icons.close),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          BBText(selectedUtxoTotal, style: context.font.displaySmall),
          const Gap(8),
          BBText(
            'Amount requested: $amountToSend',
            style: context.font.bodySmall,
          ),
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = utxos[index];
              return CommonCoinSelectTile(
                utxo: utxo,
                selected: selectedUtxos.contains(utxo),
                onTap: () => onUtxoSelected(utxo),
                exchangeRate: exchangeRate,
                bitcoinUnit: bitcoinUnit,
                fiatCurrency: fiatCurrency,
              );
            },
            separatorBuilder: (_, _) => const Gap(24),
            itemCount: utxos.length,
            shrinkWrap: true,
          ),
          const Gap(24),
          BBButton.big(
            label: "Done",
            onPressed:
                selectedUtxoTotalSat >= amountToSendSat
                    ? () => context.pop()
                    : () {},
            disabled: selectedUtxoTotalSat < amountToSendSat,
            bgColor:
                selectedUtxoTotalSat >= amountToSendSat
                    ? context.colour.secondary
                    : context.colour.outlineVariant,
            textColor:
                selectedUtxoTotalSat >= amountToSendSat
                    ? context.colour.onSecondary
                    : context.colour.outline,
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
    final utxoValue =
        bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(utxo.amountSat.toInt()))
            : FormatAmount.sats(utxo.amountSat.toInt());

    final fiatEquivalent = FormatAmount.fiat(
      ConvertAmount.satsToFiat(utxo.amountSat.toInt(), exchangeRate),
      fiatCurrency,
    );

    final address = utxo.address;
    final addressType =
        utxo.addressKeyChain == WalletAddressKeyChain.external
            ? 'Receive'
            : 'Change';
    final label = utxo.labels.join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.colour.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        BBText(
                          '$utxoValue ',
                          style: context.font.displaySmall?.copyWith(
                            color: context.colour.outlineVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    subtitle: BBText(
                      label,
                      style: context.font.labelMedium?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                    trailing: Radio<bool>(
                      value: true,
                      groupValue: selected,
                      onChanged: (_) => onTap(),
                      activeColor: context.colour.secondary,
                    ),
                  ),
                  BBText(
                    '~$fiatEquivalent',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Divider(color: context.colour.secondaryFixedDim),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BBText(
                        'Address: ',
                        style: context.font.labelMedium?.copyWith(
                          color: context.colour.surfaceContainer,
                        ),
                      ),
                      Expanded(
                        child: BBText(
                          StringFormatting.truncateMiddle(address),
                          style: context.font.labelLarge?.copyWith(
                            color: context.colour.secondary,
                          ),
                        ),
                      ),
                      BBText(
                        'Type: ',
                        style: context.font.labelMedium?.copyWith(
                          color: context.colour.surfaceContainer,
                        ),
                      ),
                      BBText(
                        addressType,
                        style: context.font.labelLarge?.copyWith(
                          color: context.colour.secondary,
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
