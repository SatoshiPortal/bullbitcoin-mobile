import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
      width: double.infinity,
      height: 40,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: context.colour.primaryContainer,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.73),
                color,
              ],
            ),
          ),
          child: InkWell(
            onTap: () {
              final walletBloc = context.read<WalletBloc>();
              context.push('/wallet', extra: walletBloc);
            },
            child: Padding(
              padding: const EdgeInsets.only(
                top: 3,
                right: 8.0,
                left: 8,
                bottom: 3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(8),
                  BBText.titleLarge(
                    name ?? fingerprint,
                    onSurface: true,
                    fontSize: 8,
                    compact: true,
                  ),
                  const Gap(4),
                  Opacity(
                    opacity: 0.7,
                    child: BBText.bodySmall(
                      walletStr ?? '',
                      onSurface: true,
                      isBold: true,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BBText.titleLarge(
                        balance,
                        onSurface: true,
                        isBold: true,
                        fontSize: 24,
                        compact: true,
                      ),
                      const Gap(4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: BBText.title(
                          balanceUnit,
                          onSurface: true,
                          isBold: true,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (fiatCurrency != null) ...[
                    Row(
                      children: [
                        BBText.bodySmall(
                          '~' + (fiatAmt ?? ''),
                          onSurface: true,
                          fontSize: 12,
                        ),
                        const Gap(4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: BBText.bodySmall(
                            fiatCurrency!.shortName.toUpperCase(),
                            onSurface: true,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Gap(4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
