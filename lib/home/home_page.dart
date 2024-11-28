import 'dart:async';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/listeners.dart';
import 'package:bb_mobile/home/transactions.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: HomeLoadingCubit(),
      child: const HomeWalletLoadingListeners(
        child: _Screen(),
      ),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  int _currentPage = 0;

  void _onChanged(int page) {
    _currentPage = page;
    setState(() {});
  }

  static const double _oneCardH = 110.0;
  static const double _twoCardH = 210.0;
  static const double _threeCardH = 310.0;

  double _calculateHeight(int cardsLen) {
    if (cardsLen == 1) return _oneCardH;
    if (cardsLen == 2) return _twoCardH;
    if (cardsLen == 3) return _threeCardH;

    final isLastPage = _currentPage == (cardsLen / 3).floor();
    final cardsOnPage = isLastPage ? cardsLen % 3 : 3;

    if (cardsOnPage == 1) return _oneCardH;
    if (cardsOnPage == 2) return _twoCardH;
    if (cardsOnPage == 3) return _threeCardH;

    return _threeCardH;
  }

  static AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      shadowColor: context.colour.primary.withOpacity(0.2),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: const HomeTopBar2(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final _ = context.select((HomeCubit x) => x.state.updated);
    final loading = context.select(
      (HomeCubit x) => x.state.loadingWallets,
    );
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());

    final walletBlocs = context.select(
      (HomeCubit x) => x.state.walletBlocsFromNetwork(network),
    );

    // final hasWallets = context.select((HomeCubit x) => x.state.hasWallets());
    final hasMainWallets = context.select(
      (HomeCubit x) => x.state.hasMainWallets(),
    );

    // final walletBlocsLen =
    //     context.select((HomeCubit x) => x.state.lenWalletsFromNetwork(network));

    if (!loading && (walletBlocs.isEmpty || !hasMainWallets)) {
      final isTestnet = network == BBNetwork.Testnet;

      Widget widget = Scaffold(
        appBar: !isTestnet ? null : _buildAppBar(context),
        body: HomeNoWalletsWithCreation(fullRed: !isTestnet),
      );
      if (!isTestnet) {
        widget = AnnotatedRegion(
          value: SystemUiOverlayStyle(statusBarColor: context.colour.primary),
          child: widget,
        );
      }

      return widget;
    }

    final warningsSize =
        context.select((HomeCubit x) => x.state.homeWarnings(network)).length *
            40.0;

    final h = _calculateHeight(walletBlocs.length);

    scheduleMicrotask(() async {
      await Future.delayed(50.ms);

      if (!context.mounted) return;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: context.colour.primaryContainer,
        ),
      );
    });

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          const TopCenter(
            child: HomeWarnings(),
          ),
          PositionedDirectional(
            top: warningsSize,
            start: 0,
            end: 0,
            child: SizedBox(
              height: 310,
              child: CardsList(
                onChanged: _onChanged,
              ),
            ),
          ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: h + warningsSize,
              ),
              Expanded(
                child: ColoredBox(
                  color: context.colour.primaryContainer,
                  child: const HomeTransactions(),
                ),
              ),
              const Gap(128),
            ],
          ),
          BottomCenter(
            child: Container(
              height: 128,
              margin: const EdgeInsets.only(top: 16),
              child: const HomeBottomBar2(walletBloc: null),
            ),
          ),
        ],
      ),
    );
  }
}

class CardsList extends StatelessWidget {
  const CardsList({
    super.key,
    required this.onChanged,
  });

  final Function(int) onChanged;

  static List<CardColumn> buildCardColumns(List<WalletBloc> wallets) {
    final List<CardColumn> columns = [];
    final isOne = wallets.length == 1;
    for (var i = 0; i < wallets.length; i += 3) {
      final walletTop = wallets[i];
      final walletBottom = i + 1 < wallets.length ? wallets[i + 1] : null;
      final walletLast = i + 2 < wallets.length ? wallets[i + 2] : null;

      columns.add(
        CardColumn(
          walletTop: walletTop,
          walletBottom: walletBottom,
          walletLast: walletLast,
          onlyOne: isOne,
          showSwap: i == 0,
        ),
      );
    }
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.select((HomeCubit x) => x.state.updated);

    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final walletBlocs = context
        .select((HomeCubit x) => x.state.walletBlocsFromNetwork(network));
    final columns = buildCardColumns(walletBlocs);

    return PageView(
      scrollDirection: Axis.vertical,
      onPageChanged: onChanged,
      children: columns,
    );
  }
}

class CardColumn extends StatelessWidget {
  const CardColumn({
    super.key,
    required this.walletTop,
    this.walletBottom,
    this.walletLast,
    this.onlyOne = false,
    this.showSwap = false,
  });

  final WalletBloc walletTop;
  final WalletBloc? walletBottom;
  final WalletBloc? walletLast;
  final bool onlyOne;
  final bool showSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 26,
        vertical: 4,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              BlocProvider.value(
                value: walletTop,
                child: const CardItem(),
              ),
              if (walletBottom != null)
                BlocProvider.value(
                  value: walletBottom!,
                  child: const CardItem(),
                ),
              if (walletLast != null)
                BlocProvider.value(
                  value: walletLast!,
                  child: const CardItem(),
                )
              else if (!onlyOne)
                const EmptyCard(),
            ],
          ),
          if (showSwap)
            Positioned(
              right: 22, // left: // 126, // 76 // 120
              top: 83, //87 // 84
              child: SizedBox(
                height: 32,
                width: 40,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/swap-page');
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: NewColours.lightGray),
                    backgroundColor: context.colour.primaryContainer,
                    surfaceTintColor:
                        context.colour.primaryContainer.withOpacity(0.5),
                    elevation: 2,
                    splashFactory: NoSplash.splashFactory,
                    enableFeedback: false,
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: context.colour.onPrimaryContainer,
                    size: 24,
                  ),
                ),
              ),
              // child: Center(child: BBButton.big(label: 'Swap', onPressed: () {})),
            ),
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

    return SizedBox(
      width: double.infinity,
      height: 100,
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
                right: 16.0,
                left: 24,
                bottom: 3,
              ),
              child: Stack(
                children: [
                  /*
                  // Uncomment to get settings button (3 dots) on top right
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
                  */
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(8),
                      BBText.titleLarge(
                        name ?? fingerprint,
                        onSurface: true,
                        fontSize: 20,
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
                              unit,
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
                              '~$fiatAmt',
                              onSurface: true,
                              fontSize: 12,
                            ),
                            const Gap(4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: BBText.bodySmall(
                                fiatCurrency.shortName.toUpperCase(),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension O on Object? {
  bool notNull() => this != null;
}

///
/// Color of the tag represents color of our wallet that holds the tx.
/// Text of the tag represents the external network
///
/// Eg.,
/// Orange Lightning send: Secure wallet paying an LN invoice (Submarine)
/// Yellow Lightning receive: Lightning receive to Instant wallet (Reverse)
/// Orange Liquid receive: Chain swap received from liquid network to our Secure wallet
/// Orange Liquid send: Chain swap sent from from our Secure wallet to a liquid address
///
class WalletTag extends StatelessWidget {
  const WalletTag({
    super.key,
    required this.tx,
  });

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final watchOnly =
        context.read<HomeCubit>().state.walletIsWatchOnlyFromTx(tx);

    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final watchonlyColor =
        darkMode ? context.colour.surface : context.colour.onPrimaryContainer;

    final (name, color) = tx.buildTagDetails();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: watchOnly ? watchonlyColor : color,
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
    final currency =
        context.select((CurrencyCubit e) => e.state.defaultFiatCurrency);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            alignment: Alignment.bottomCenter,
            margin: const EdgeInsets.only(
              left: 32,
              // top: 28,
            ),
            height: 40,
            width: 40,
            child: Image.asset(
              'assets/bb-logo-small.png',
              height: 40,
              width: 40,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Image.asset(
                          'assets/textlogo.png',
                          height: 20,
                          width: 108,
                        ),
                      ),
                      const Gap(4),
                      const BBText.bodySmall(
                        'BETA',
                        isBold: true,
                        compact: true,
                      ),
                    ],
                  ),
                  if (currency != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BBText.bodySmall(
                          '${currency.price} ${currency.shortName.toUpperCase()}',
                        ),
                      ],
                    )
                  else ...[
                    const BBText.bodySmall(''),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            key: UIKeys.homeSettingsButton,
            color: context.colour.onPrimaryContainer,
            padding: const EdgeInsets.only(bottom: 12),
            visualDensity: VisualDensity.compact,
            iconSize: 30,
            icon: const Icon(
              FontAwesomeIcons.gear,
              shadows: [],
            ),
            onPressed: () {
              context.push('/settings');
            },
          ),
          IconButton(
            iconSize: 30,
            color: context.colour.onPrimaryContainer,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(bottom: 12),
            icon: const Icon(
              FontAwesomeIcons.user,
              shadows: [],
            ),
            onPressed: () {
              // context.push('/swap-page');
            },
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class HomeBottomBar2 extends StatefulWidget {
  const HomeBottomBar2({super.key, required this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  State<HomeBottomBar2> createState() => _HomeBottomBar2State();
}

class _HomeBottomBar2State extends State<HomeBottomBar2> {
  WalletBloc? wb;
  @override
  void initState() {
    if (widget.walletBloc == null) {
      final network = context.read<NetworkCubit>().state.getBBNetwork();
      final walletBlocs =
          context.read<HomeCubit>().state.walletBlocsFromNetwork(network);
      if (walletBlocs.length == 1) wb = walletBlocs.first;
    }
    super.initState();
  }

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
                      child: BBButton.big(
                        label: 'Receive',
                        onPressed: () {
                          context.push(
                            '/receive',
                            extra: widget.walletBloc ?? wb,
                          );
                        },
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBButton.big(
                        label: 'Send',
                        onPressed: () {
                          context.push(
                            '/send',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BBButton.big(
                        label: 'Buy',
                        onPressed: () {
                          context.push('/market');
                        },
                        disabled: true,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: BBButton.big(
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
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final bgColour =
        darkMode ? context.colour.primaryContainer : NewColours.offWhite;

    return SizedBox(
      height: 40,
      width: 55,
      child: ElevatedButton(
        onPressed: () {
          context.push('/send', extra: 'scan');
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: NewColours.lightGray),
          backgroundColor: bgColour,
          surfaceTintColor: bgColour.withOpacity(0.5),
          elevation: 2,
          splashFactory: NoSplash.splashFactory,
          enableFeedback: false,
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          Icons.qr_code_2,
          color: context.colour.onPrimaryContainer,
          size: 32,
        ),
      ),
    );
  }
}

// class HomeLoadingTxsIndicator extends StatefulWidget {
//   const HomeLoadingTxsIndicator({super.key});

//   @override
//   State<HomeLoadingTxsIndicator> createState() =>
//       _HomeLoadingTxsIndicatorState();
// }

// class _HomeLoadingTxsIndicatorState extends State<HomeLoadingTxsIndicator> {
//   bool loading = false;
//   Map<String, bool> loadingMap = {};

//   @override
//   Widget build(BuildContext context) {
//     final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
//     final walletBlocs = context
//         .select((HomeCubit x) => x.state.walletBlocsFromNetwork(network));

//     if (walletBlocs.isEmpty) return const SizedBox.shrink();

//     return MultiBlocListener(
//       listeners: [
//         for (final walletBloc in walletBlocs)
//           BlocListener<WalletBloc, WalletState>(
//             bloc: walletBloc,
//             listenWhen: (previous, current) =>
//                 previous.loading() != current.loading(),
//             listener: (context, state) {
//               if (state.loading())
//                 loadingMap[state.wallet!.id] = true;
//               else
//                 loadingMap[state.wallet!.id] = false;

//               if (loadingMap.values.contains(true))
//                 setState(() {
//                   loading = true;
//                 });
//               else
//                 setState(() {
//                   loading = false;
//                 });
//             },
//           ),
//       ],
//       child: _Loading(loading: loading),
//     );
//   }
// }

class HomeLoadingTxsIndicator extends StatelessWidget {
  const HomeLoadingTxsIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeLoadingCubit, Map<String, bool>>(
      buildWhen: (previous, current) => previous.values != current.values,
      builder: (context, state) {
        final isLoading = state.values.contains(true);
        return _Loading(loading: isLoading);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return !loading
        ? const SizedBox(height: 16)
        : SizedBox(
            height: 16,
            child: const BBLoadingRow().animate().fadeIn(),
          );
  }
}

class HomeNoWallets extends StatelessWidget {
  const HomeNoWallets({super.key, this.fullRed = true});

  final bool fullRed;

  @override
  Widget build(BuildContext context) {
    if (!fullRed) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBButton.big(
              label: 'Create new wallet',
              onPressed: () {
                context.push('/create-wallet-main');
              },
            ),
            const Gap(16),
            BBButton.text(
              label: 'Recover wallet backup',
              centered: true,
              onPressed: () {
                context.push('/import-main');
              },
            ),
          ],
        ),
      );
    }

    final font = GoogleFonts.bebasNeue();
    final w = MediaQuery.of(context).size.width;

    return ColoredBox(
      color: context.colour.primary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 148,
              width: 184,
              child: Image.asset('assets/bb-logo-white.png'),
            ),
            const Gap(24),
            Text(
              'BULL BITCOIN',
              style: font.copyWith(
                fontSize: 80,
                color: context.colour.primaryContainer,
                height: 0.8,
              ),
            ),
            Text(
              'OWN YOUR MONEY',
              style: font.copyWith(
                fontSize: 59,
                height: 0.8,
              ),
            ),
            const Gap(8),
            SizedBox(
              width: w * 0.8,
              child: const BBText.body(
                'Sovereign non-custodial Bitcoin wallet and Bitcoin-only exchange service. ',
                onSurface: true,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(128),
            Center(
              child: BBButton.big(
                label: 'Create new wallet',
                onPressed: () {
                  context.push('/create-wallet-main');
                },
              ),
            ),
            BBButton.text(
              label: 'Recover wallet backup',
              centered: true,
              onSurface: true,
              isBlue: false,
              fontSize: 11,
              onPressed: () {
                context.push('/import-main');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeNoWalletsWithCreation extends StatelessWidget {
  const HomeNoWalletsWithCreation({super.key, this.fullRed = true});

  final bool fullRed;

  @override
  Widget build(BuildContext context1) {
    final createWallet = CreateWalletCubit(
      walletSensCreate: locator<WalletSensitiveCreate>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      networkCubit: locator<NetworkCubit>(),
      walletCreate: locator<WalletCreate>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
      lwkSensitiveCreate: locator<LWKSensitiveCreate>(),
      mainWallet: true,
    );

    if (!fullRed) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBButton.big(
              label: 'Create new wallet',
              onPressed: () {
                context1.push('/create-wallet-main');
              },
            ),
            const Gap(16),
            BBButton.text(
              label: 'Recover wallet backup',
              centered: true,
              onPressed: () {
                context1.push('/import-main');
              },
            ),
          ],
        ),
      );
    }

    final font = GoogleFonts.bebasNeue();
    final w = MediaQuery.of(context1).size.width;

    return BlocProvider.value(
      value: createWallet,
      child: HomeNoWalletsView(font: font, w: w),
    );
  }
}

class HomeNoWalletsView extends StatelessWidget {
  const HomeNoWalletsView({
    super.key,
    required this.font,
    required this.w,
  });

  final TextStyle font;
  final double w;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateWalletCubit, CreateWalletState>(
      listenWhen: (previous, current) => previous.saved != current.saved,
      listener: (context3, state) async {
        if (state.saved) {
          if (state.savedWallets == null) return;
          //if (state.mainWallet)
          await locator<WalletsStorageRepository>().sortWallets();
          locator<HomeCubit>().getWalletsFromStorage();
          if (!context.mounted) return;
          context3.go('/home');
        }
      },
      child: ColoredBox(
        color: context.colour.primary,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 148,
                width: 184,
                child: Image.asset('assets/bb-logo-white.png'),
              ),
              const Gap(24),
              Text(
                'BULL BITCOIN',
                style: font.copyWith(
                  fontSize: 80,
                  color: context.colour.primaryContainer,
                  height: 0.8,
                ),
              ),
              Text(
                'OWN YOUR MONEY',
                style: font.copyWith(
                  fontSize: 59,
                  height: 0.8,
                ),
              ),
              const Gap(8),
              SizedBox(
                width: w * 0.8,
                child: const BBText.body(
                  'Sovereign non-custodial Bitcoin wallet and Bitcoin-only exchange service. ',
                  onSurface: true,
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(128),
              Center(
                child: BBButton.big(
                  label: 'Create new wallet',
                  onPressed: () {
                    context.read<CreateWalletCubit>().confirmClicked();
                    // context.push('/create-wallet-main');
                  },
                ),
              ),
              BBButton.text(
                label: 'Recover wallet backup',
                centered: true,
                onSurface: true,
                isBlue: false,
                fontSize: 11,
                onPressed: () {
                  context.push('/import-main');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeWarnings extends StatelessWidget {
  const HomeWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = context.select((HomeCubit e) => e.state.updated);
    final network = context.select((NetworkCubit e) => e.state.getBBNetwork());
    final warnings =
        context.select((HomeCubit e) => e.state.homeWarnings(network));

    return Column(
      children: [
        for (final w in warnings)
          WarningBanner(
            onTap: () {
              context.push('/wallet-settings/open-backup', extra: w.walletBloc);
            },
            info: w.info,
          ),
      ],
    );
  }
}
