import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/home/transactions.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomePage2 extends StatelessWidget {
  const HomePage2({super.key});

  @override
  Widget build(BuildContext context) {
    final homeCubit = locator<HomeCubit>();
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: homeCubit),
        BlocProvider.value(value: homeCubit.createWalletCubit),
      ],
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          shadowColor: context.colour.primary.withOpacity(0.2),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const HomeTopBar2(),
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final walletScreen = HomePage.setupHomeWallets(context);
    if (walletScreen != null) return walletScreen;
    final homeWallets = HomePage.selectHomeBlocs(context);

    final walletCubits = homeWallets.walletCubits;

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: CardsList(walletBlocs: walletCubits),
        ),
        const Expanded(
          flex: 5,
          child: HomeTransactions(),
        ),
        Container(
          height: 128,
          child: HomeBottomBar2(
            walletBloc: walletCubits.length == 1 ? walletCubits[0] : null,
          ),
        ),
      ],
    );
  }
}

class CardsList extends StatelessWidget {
  const CardsList({super.key, required this.walletBlocs});

  final List<WalletBloc> walletBlocs;

  static List<CardColumn> buildCardColumns(List<WalletBloc> wallets) {
    final List<CardColumn> columns = [];
    for (var i = 0; i < wallets.length; i += 2) {
      final walletTop = wallets[i];
      final walletBottom = i + 1 < wallets.length ? wallets[i + 1] : null;
      columns.add(CardColumn(walletTop: walletTop, walletBottom: walletBottom));
    }
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    final columns = buildCardColumns(walletBlocs);

    return PageView(
      scrollDirection: Axis.vertical,
      children: columns,
    );
  }
}

class CardColumn extends StatelessWidget {
  const CardColumn({super.key, required this.walletTop, this.walletBottom});

  final WalletBloc walletTop;
  final WalletBloc? walletBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BlocProvider.value(
            value: walletTop,
            child: const CardItem(),
          ),
          // const Gap(8),
          if (walletBottom != null)
            BlocProvider.value(
              value: walletBottom!,
              child: const CardItem(),
            )
          else
            const EmptyCard(),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: SizedBox(
        width: double.infinity,
        child: Card(
          color: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}

class CardItem extends StatelessWidget {
  const CardItem({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc x) => x.state.wallet);
    if (wallet == null) return const SizedBox.shrink();

    final (color, _) = WalletCardDetails.cardDetails(context, wallet);

    final name = context.select((WalletBloc x) => x.state.wallet?.name);
    final fingerprint = context.select((WalletBloc x) => x.state.wallet?.sourceFingerprint ?? '');
    final walletStr = context.select((WalletBloc x) => x.state.wallet?.getWalletTypeShortString());

    final sats = context.select((WalletBloc x) => x.state.balanceSats());

    final balance =
        context.select((CurrencyCubit x) => x.state.getAmountInUnits(sats, removeText: true));
    final unit = context.select((CurrencyCubit x) => x.state.getUnitString());

    final fiatCurrency = context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final fiatAmt = context.select((NetworkCubit x) => x.state.calculatePrice(sats, fiatCurrency));

    // return const SizedBox(
    //   height: 125,
    //   width: double.infinity,
    //   child: Card(
    //     color: Colors.amber,
    //     elevation: 2,
    //   ),
    // );

    return Expanded(
      child: SizedBox(
        width: double.infinity,
        child: Card(
          clipBehavior: Clip.antiAliasWithSaveLayer,
          color: context.colour.background,
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
                  top: 8,
                  right: 16.0,
                  left: 24,
                  bottom: 8,
                ),
                child: Stack(
                  children: [
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
                      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BBText.titleLarge(
                          name ?? fingerprint,
                          onSurface: true,
                        ),
                        Opacity(
                          opacity: 0.7,
                          child: BBText.bodySmall(
                            walletStr ?? '',
                            onSurface: true,
                            isBold: true,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                            if (fiatCurrency != null) ...[
                              const Gap(16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  BBText.body(
                                    '~' + fiatAmt,
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
                          ],
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WalletTag extends StatelessWidget {
  const WalletTag({super.key, required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final (color, _) = WalletCardDetails.cardDetails(context, wallet);

    final name = wallet.name ?? wallet.sourceFingerprint;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: BBText.bodySmall(
        name,
        onSurface: true,
        isBold: true,
      ),
    );
  }
}

class HomeTopBar2 extends StatelessWidget {
  const HomeTopBar2({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final totalSats = context.select((HomeCubit x) => x.state.totalBalanceSats(network));

    final fiatCurrency = context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final fiatAmt =
        context.select((NetworkCubit x) => x.state.calculatePrice(totalSats, fiatCurrency));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          alignment: Alignment.bottomCenter,
          margin: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/bb-logo2.png',
            height: 50,
            width: 50,
          ),
        ),
        const Gap(4),
        GestureDetector(
          onLongPress: () {
            context.push('/logs');
          },
          child: Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Image.asset(
                    'assets/textlogo.png',
                    height: 20,
                    width: 108,
                  ),
                ),
                if (fiatCurrency != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BBText.headline(
                        fiatAmt,
                        fontSize: 18,
                      ),
                      const Gap(4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: BBText.bodySmall(
                          fiatCurrency.shortName.toUpperCase(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          key: UIKeys.homeImportButton,
          color: context.colour.onBackground,
          icon: const Icon(
            FontAwesomeIcons.circlePlus,
            shadows: [],
          ),
          onPressed: () {
            context.push('/import');
          },
        ),
        IconButton(
          key: UIKeys.homeSettingsButton,
          color: context.colour.onBackground,
          icon: const Icon(
            FontAwesomeIcons.gear,
            shadows: [],
          ),
          onPressed: () {
            context.push('/settings');
          },
        ),
        IconButton(
          // key: UIKeys.homeSettingsButton,
          color: context.colour.onBackground,
          icon: const Icon(
            FontAwesomeIcons.userLarge,
            shadows: [],
          ),
          onPressed: () {
            context.push('/market');
          },
        ),
        const Gap(16),
      ],
    );
  }
}

class HomeBottomBar2 extends StatelessWidget {
  const HomeBottomBar2({super.key, required this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: 24,
        top: 8,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BBButton.bigNoIcon(
                        label: 'Receive',
                        onPressed: () {
                          context.push('/receive', extra: walletBloc);
                        },
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBButton.bigNoIcon(
                        label: 'Send',
                        onPressed: () {
                          context.push('/send', extra: walletBloc);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BBButton.bigNoIcon(
                        label: 'Buy',
                        onPressed: () {
                          context.push('/market');
                        },
                        disabled: true,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBButton.bigNoIcon(
                        label: 'Sell',
                        onPressed: () {
                          context.push('/market');
                        },
                        disabled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Center(
            child: ScanButton(),
          ),
        ],
      ),
    );
  }
}

class ScanButton extends StatelessWidget {
  const ScanButton({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: 55,
      child: ElevatedButton(
        onPressed: () {
          context.push('/send', extra: walletBloc);
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: NewColours.lightGray),
          backgroundColor: NewColours.offWhite,
          surfaceTintColor: NewColours.offWhite.withOpacity(0.5),
          elevation: 2,
          splashFactory: NoSplash.splashFactory,
          // foregroundColor: Colors.red,

          enableFeedback: false,
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          FontAwesomeIcons.barcode,
          color: context.colour.onBackground,
          size: 24,
        ),
      ),
    );
  }
}

class HomeLoadingTxsIndicator extends StatefulWidget {
  const HomeLoadingTxsIndicator({super.key});

  @override
  State<HomeLoadingTxsIndicator> createState() => _HomeLoadingTxsIndicatorState();
}

class _HomeLoadingTxsIndicatorState extends State<HomeLoadingTxsIndicator> {
  bool loading = false;
  Map<String, bool> loadingMap = {};

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final walletBlocs = context.select((HomeCubit x) => x.state.walletBlocsFromNetwork(network));

    return MultiBlocListener(
      listeners: [
        for (final walletBloc in walletBlocs)
          BlocListener<WalletBloc, WalletState>(
            bloc: walletBloc,
            listenWhen: (previous, current) => previous.loading() != current.loading(),
            listener: (context, state) {
              if (state.loadingTxs)
                loadingMap[state.wallet!.id] = true;
              else
                loadingMap[state.wallet!.id] = false;

              if (loadingMap.values.contains(true))
                setState(() {
                  loading = true;
                });
              else
                setState(() {
                  loading = false;
                });
            },
          ),
      ],
      child: loading
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: const BBLoadingRow().animate().fadeIn(),
                ),
              ),
            ),
    );
  }
}
