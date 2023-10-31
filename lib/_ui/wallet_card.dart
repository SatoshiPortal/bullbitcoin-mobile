import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
// import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeCard extends StatelessWidget {
  const HomeCard({super.key, this.hideSettings = false, required this.onTap});

  final bool hideSettings;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc x) => x.state.wallet);
    if (wallet == null) return const SizedBox.shrink();

    final (_, info) = WalletCardDetails.cardDetails(context, wallet);
    final keyName = 'home_card_$info';

    return InkWell(
      radius: 32,
      onTap: () {
        onTap();
      },
      child: Material(
        key: Key(keyName),
        elevation: 4,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: AspectRatio(
          aspectRatio: 2 / 1,
          child: WalletCardDetails(hideSettings: hideSettings),
        ),
      ),
    );
  }
}

class WalletCardDetails extends StatelessWidget {
  const WalletCardDetails({super.key, this.hideSettings = false});

  final bool hideSettings;

  static (Color, String) cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = wallet.network == BBNetwork.Testnet;
    final isWatchOnly = wallet.watchOnly();

    if (isWatchOnly && !isTestnet) return (context.colour.onBackground, 'mainnet_watchonly');
    if (isWatchOnly && isTestnet) return (context.colour.onBackground, 'testnet_watchonly');

    if (isTestnet) return (context.colour.surface, 'testnet');
    return (context.colour.primary, 'mainnet');
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc x) => x.state.wallet);
    if (wallet == null) return const SizedBox.shrink();

    final (color, _) = cardDetails(context, wallet);

    final name = context.select((WalletBloc x) => x.state.wallet?.name);
    final fingerprint = context.select((WalletBloc x) => x.state.wallet?.sourceFingerprint ?? '');
    final walletStr = context.select((WalletBloc x) => x.state.wallet?.getWalletTypeShortString());

    final sats = context.select((WalletBloc x) => x.state.balanceSats());

    final balance =
        context.select((SettingsCubit x) => x.state.getAmountInUnits(sats, removeText: true));
    final unit = context.select((SettingsCubit x) => x.state.getUnitString());

    final currency = context.select((SettingsCubit x) => x.state.currency);
    final fiatAmt = context.select((SettingsCubit x) => x.state.calculatePrice(sats));

    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          right: 16.0,
          left: 32,
          bottom: 32,
        ),
        child: Stack(
          children: [
            TopLeft(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: BBText.titleLarge(
                  name ?? fingerprint,
                  onSurface: true,
                ),
              ),
            ),
            if (!hideSettings)
              TopRight(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    onPressed: () {
                      context.push('/wallet-settings');
                    },
                    color: context.colour.onPrimary,
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsis,
                    ),
                  ),
                ),
              ),
            BottomLeft(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BBText.titleLarge(
                        balance,
                        onSurface: true,
                        isBold: true,
                      ),
                      const Gap(4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: BBText.title(
                          unit,
                          onSurface: true,
                          isBold: true,
                        ),
                      ),
                    ],
                  ),
                  if (currency != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BBText.body(
                          fiatAmt,
                          onSurface: true,
                          isBold: true,
                        ),
                        const Gap(4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: BBText.bodySmall(
                            currency.shortName.toUpperCase(),
                            onSurface: true,
                            isBold: true,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Opacity(
                          opacity: 0.7,
                          child: BBText.bodySmall(
                            walletStr ?? '',
                            onSurface: true,
                            isBold: true,
                          ),
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
