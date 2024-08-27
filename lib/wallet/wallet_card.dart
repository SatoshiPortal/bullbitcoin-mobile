import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
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
    final isTestnet = wallet.isTestnet();
    final isInstant = wallet.isInstant();
    final isWatchOnly = wallet.watchOnly();

    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final watchonlyColor =
        darkMode ? context.colour.surface : context.colour.onPrimaryContainer;

    if (isWatchOnly && !isTestnet) return (watchonlyColor, 'mainnet_watchonly');
    if (isWatchOnly && isTestnet) return (watchonlyColor, 'testnet_watchonly');

    if (isInstant) return (CardColours.yellow, 'instant');

    // if (isTestnet) return (context.colour.surface, 'testnet');
    // return (context.colour.primary, 'mainnet');

    if (isTestnet) return (CardColours.orange, 'testnet');
    return (CardColours.orange, 'mainnet');
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc x) => x.state.wallet);
    if (wallet == null) return const SizedBox.shrink();

    final (color, _) = cardDetails(context, wallet);

    final name = context.select((WalletBloc x) => x.state.wallet?.name);
    final fingerprint = context
        .select((WalletBloc x) => x.state.wallet?.sourceFingerprint ?? '');
    final walletStr =
        context.select((WalletBloc x) => x.state.wallet?.getWalletTypeStr());

    final sats = context.select((WalletBloc x) => x.state.balanceSats());

    final balance = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(sats, removeText: true),
    );
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: wallet.isLiquid()),
    );

    final fiatCurrency =
        context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final fiatAmt = context
        .select((NetworkCubit x) => x.state.calculatePrice(sats, fiatCurrency));

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
          left: 24,
          bottom: 8,
        ),
        child: Stack(
          children: [
            if (!hideSettings)
              TopRight(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    onPressed: () {
                      final walletBloc = context.read<WalletBloc>();
                      context.push('/wallet-settings', extra: walletBloc);
                    },
                    color: context.colour.onPrimary,
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsis,
                    ),
                  ),
                ),
              ),
            // TopLeft(
            //   child: Padding(
            //     padding: const EdgeInsets.only(
            //       top: 8,
            //     ),
            //     child: BBText.titleLarge(
            //       name ?? fingerprint,
            //       onSurface: true,
            //     ),
            //   ),
            // ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BBText.titleLarge(
                  name ?? fingerprint,
                  onSurface: true,
                ),
                Column(
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
                    if (fiatCurrency != null)
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
                              fiatCurrency.shortName.toUpperCase(),
                              onSurface: true,
                              isBold: true,
                            ),
                          ),
                        ],
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
          ],
        ),
      ),
    );
  }
}
