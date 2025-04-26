import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class CoinSelectTile extends StatelessWidget {
  final TransactionOutput utxo;
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
        ? FormatAmount.btc(ConvertAmount.satsToBtc(utxo.value!.toInt()))
        : FormatAmount.sats(utxo.value!.toInt());

    final fiatEquivalent = FormatAmount.fiat(
      ConvertAmount.satsToFiat(
        utxo.value!.toInt(),
        exchangeRate,
      ),
      fiatCurrency,
    ); // You can format this better

    final address = utxo.walletAddress?.address;
    final addressType =
        utxo.walletAddress?.keyChain == WalletAddressKeyChain.external
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
          border: Border.all(
            color: context.colour.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
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
                        BBText(
                          '~$fiatEquivalent',
                          style: context.font.labelSmall?.copyWith(
                            color: context.colour.outlineVariant,
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
                  if (address != null) ...[
                    const SizedBox(height: 24),
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
                            style: context.font.labelLarge
                                ?.copyWith(color: context.colour.secondary),
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
                          style: context.font.labelLarge
                              ?.copyWith(color: context.colour.secondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
