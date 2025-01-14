import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

// TODO: Add onTap prop
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.wallet,
    required this.balance,
    required this.balanceUnit,
    this.walletStr,
    this.fiatCurrency,
    this.fiatAmt,
  });

  final Wallet wallet;
  final String? walletStr;
  final String balance;
  final String balanceUnit;
  final Currency? fiatCurrency;
  final String? fiatAmt;

  @override
  Widget build(BuildContext context) {
    final (color, _) = WalletCardDetails.cardDetails(context, wallet);

    final name = wallet.name;
    final fingerprint = wallet.sourceFingerprint;

    return SizedBox(
      width: MediaQuery.of(context).size.width - 48, // TODO: Better way?
      height: 70,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: context.colour.primaryContainer,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.73),
                color,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 4,
              right: 6.0,
              left: 12.0,
              bottom: 4,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(8),
                    BBText.title(
                      name ?? fingerprint,
                      onSurface: true,
                      compact: true,
                    ),
                    const Gap(14),
                    if (walletStr != null) const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText.titleLarge(
                          balance,
                          onSurface: true,
                          isBold: true,
                          compact: true,
                        ),
                        const Gap(4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: BBText.title(
                            balanceUnit,
                            onSurface: true,
                            isBold: true,
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_down_outlined,
                  color: context.colour.onPrimaryContainer,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
