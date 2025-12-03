import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class CoinSelectTile extends StatelessWidget {
  final WalletUtxo utxo;
  final bool selected;
  final VoidCallback onTap;
  final BitcoinUnit bitcoinUnit;
  final double exchangeRate;
  final String fiatCurrency;

  const CoinSelectTile({
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
    ); // You can format this better

    final address = utxo.address;
    final addressType = utxo.addressKeyChain == WalletAddressKeyChain.external
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
                            color: context.appColors.outlineVariant,
                            fontWeight: .w500,
                          ),
                        ),
                      ],
                    ),
                    subtitle: BBText(
                      label,
                      style: context.font.labelMedium?.copyWith(
                        color: context.appColors.outline,
                      ),
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
                  // const SizedBox(height: 4),
                  BBText(
                    '~$fiatEquivalent',
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.outlineVariant,
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
                          color: context.appColors.surfaceContainer,
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
                          color: context.appColors.surfaceContainer,
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
