import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/bottom_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/receive_popup.dart';
// ignore: library_prefixes
import 'package:bb_mobile/send/send_page.dart' as SendPage;
// import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeCubit = locator<HomeCubit>();
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: homeCubit),
        BlocProvider.value(value: homeCubit.createWalletCubit),
      ],
      child: _Screen(),
    );
  }
}

class _Screen extends HookWidget {
  static const _pages = [
    HomeWallets(),
    MarketHome(),
  ];
  @override
  Widget build(BuildContext context) {
    final pageIdx = useState(0);

    return Scaffold(
      appBar: AppBar(
        shadowColor: context.colour.primary.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: HomeTopBar(pageIdx: pageIdx.value),
      ),
      body: _pages.elementAt(pageIdx.value),
      bottomNavigationBar: BottomBar(
        pageChanged: (idx) {
          pageIdx.value = idx;
        },
        pageIdx: pageIdx.value,
      ),
    );
  }
}

class MarketHome extends StatelessWidget {
  const MarketHome({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: context.colour.onBackground,
      child: CenterLeft(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: const BBText.headline(
            'BITCOIN\nEXCHANGE\nCOMING\nSOON!',
            onSurface: true,
          ).animate(delay: const Duration(milliseconds: 400)).fadeIn(),
        ),
      ),
    );
  }
}

class HomeWallets extends StatelessWidget {
  const HomeWallets({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.select((SettingsCubit x) => x.state.getBBNetwork());

    final wallets = context.select((HomeCubit x) => x.state.walletsFromNetwork(network));

    final hasWallets = wallets.isNotEmpty;
    final loading = context.select((HomeCubit x) => x.state.loadingWallets);

    if (loading) return Container();

    if (!hasWallets) return const HomeNoWallets().animate().fadeIn();

    final walletCubits = [
      for (final w in wallets)
        WalletBloc(
          saveDir: w.getWalletStorageString(),
          settingsCubit: locator<SettingsCubit>(),
          walletSync: locator<WalletSync>(),
          secureStorage: locator<SecureStorage>(),
          hiveStorage: locator<HiveStorage>(),
          walletCreate: locator<WalletCreate>(),
          walletRepository: locator<WalletRepository>(),
          walletTransaction: locator<WalletTx>(),
          walletBalance: locator<WalletBalance>(),
          walletAddress: locator<WalletAddress>(),
        ),
    ];

    return WalletScreen(
      walletCubits: walletCubits,
    )
        .animate(
          delay: const Duration(
            milliseconds: 300,
          ),
        )
        .fadeIn();
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.walletCubits});

  final List<WalletBloc> walletCubits;

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select((HomeCubit x) => x.state.selectedWalletCubit);

    if (selectedWallet == null && walletCubits.isNotEmpty)
      context.read<HomeCubit>().walletSelected(walletCubits[walletCubits.length - 1]);

    return SafeArea(
      bottom: false,
      child: GlowingOverscrollIndicator(
        axisDirection: AxisDirection.down,
        color: context.colour.primary,
        child: RefreshIndicator(
          onRefresh: () async {
            selectedWallet?.add(SyncWallet());
            return;
          },
          color: context.colour.primary,
          backgroundColor: context.colour.primary,
          edgeOffset: -500,
          child: Stack(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height - 100,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(16),
                      if (selectedWallet != null) ...[
                        BlocProvider.value(
                          value: selectedWallet,
                          child: const BackupAlertBanner(),
                        ),
                      ],
                      HomeHeaderCards(walletCubits: walletCubits),
                      if (selectedWallet != null) ...[
                        BlocProvider.value(
                          value: selectedWallet,
                          child: const HomeTxList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: HomeActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackupAlertBanner extends StatelessWidget {
  const BackupAlertBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final _ = context.select((WalletBloc x) => x.state.wallet);
    final backupTested = context.select((WalletBloc x) => x.state.wallet?.backupTested ?? false);

    if (backupTested) return Container();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 32,
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const BBText.body('Make sure to backup your wallet.'),
                InkWell(
                  onTap: () {
                    context.push('/wallet-settings/test-backup');
                  },
                  child: const BBText.bodySmall(
                    'Click here to test backup.',
                    isBlue: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class HomeHeaderCards extends StatefulWidget {
  const HomeHeaderCards({super.key, required this.walletCubits});

  final List<WalletBloc> walletCubits;

  @override
  State<HomeHeaderCards> createState() => _HomeHeaderCardsState();
}

class _HomeHeaderCardsState extends State<HomeHeaderCards> {
  final CarouselController _carouselController = CarouselController();

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (previous, current) => previous.moveToIdx != current.moveToIdx,
      listener: (context, state) {
        final moveToIdx = state.moveToIdx;
        if (moveToIdx == null) return;
        _carouselController.animateToPage(0);
        final selected = widget.walletCubits[0];
        context.read<HomeCubit>().walletSelected(selected);
      },
      child: CarouselSlider(
        carouselController: _carouselController,
        options: CarouselOptions(
          initialPage: widget.walletCubits.length - 1,
          enlargeStrategy: CenterPageEnlargeStrategy.zoom,
          reverse: true,
          enableInfiniteScroll: false,
          aspectRatio: 2.1,
          onPageChanged: (i, s) {
            context.read<HomeCubit>().walletSelected(widget.walletCubits[i]);
          },
        ),
        items: [
          for (final w in widget.walletCubits) ...[
            Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: BlocProvider.value(
                    value: w,
                    child: const HomeCard(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class HomeTxList extends StatelessWidget {
  const HomeTxList({super.key});

  @override
  Widget build(BuildContext context) {
    final syncing = context.select((WalletBloc x) => x.state.syncing);
    final loading = context.select((WalletBloc x) => x.state.loadingTxs);
    final loadingBal = context.select((WalletBloc x) => x.state.loadingBalance);

    final confirmedTXs = context.select((WalletBloc x) => x.state.wallet?.getConfirmedTxs() ?? []);
    final pendingTXs = context.select((WalletBloc x) => x.state.wallet?.getPendingTxs() ?? []);

    if ((loading || syncing || loadingBal) && confirmedTXs.isEmpty && pendingTXs.isEmpty) {
      return TopCenter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
          ),
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

    if (confirmedTXs.isEmpty && pendingTXs.isEmpty) {
      return TopLeft(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
            vertical: 24,
          ),
          child: const BBText.titleLarge('No Transaction yet').animate(delay: 300.ms).fadeIn(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (syncing || loading || loadingBal)
            SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: const BBLoadingRow().animate().fadeIn(),
              ),
            )
          else
            const Gap(32),
          if (pendingTXs.isNotEmpty) ...[
            const BBText.title(
              '    Pending Transactions',
            ),
            ...pendingTXs.map((tx) => HomeTxItem(tx: tx)),
            const Gap(32),
          ],
          if (confirmedTXs.isNotEmpty) ...[
            const BBText.title(
              '    Confirmed Transactions',
            ),
            ...confirmedTXs.map((tx) => HomeTxItem(tx: tx)),
            const Gap(100),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}

class HomeTxItem extends StatelessWidget {
  const HomeTxItem({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final label = tx.label ?? '';

    final amount = context
        .select((SettingsCubit x) => x.state.getAmountInUnits(tx.getAmount(sentAsTotal: true)));

    final isReceive = tx.isReceived();

    final amt = '${isReceive ? '+' : '-'} ${amount.replaceAll("-", "")}';

    return InkWell(
      onTap: () {
        context.push('/tx', extra: tx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8 + 16,
          vertical: 4 + 16,
        ),
        child: Row(
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(
                  isReceive ? 1 : -1,
                ),
              child: const FaIcon(
                FontAwesomeIcons.arrowRight,
              ),
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(
                  amt,
                  isBold: true,
                ),
                if (tx.getBroadcastDateTime() != null)
                  BBText.body(
                    timeago.format(tx.getBroadcastDateTime()!),
                  )
                else
                  BBText.body(
                    (tx.timestamp == null || tx.timestamp == 0)
                        ? 'Pending'
                        : timeago.format(tx.getDateTime()),
                  ),
              ],
            ),
            if (label.isNotEmpty) ...[
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: BBText.bodySmall(
                  label,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final hasWallets = context.select((HomeCubit x) => x.state.hasWallets());

    if (!hasWallets) return const SizedBox.shrink();

    final buttonWidth = (MediaQuery.of(context).size.width / 2) - 40;

    // const buttonWidth = double.maxFinite;
    //128.0;

    final color = context.colour.background;

    return Container(
      padding: const EdgeInsets.only(
        bottom: 16,
        top: 48,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color,
            color,
            color,
            color,
            color,
            color,
            color.withOpacity(0.9),
            color.withOpacity(0.5),
            color.withOpacity(0.0),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: buttonWidth,
            child: BBButton.smallRed(
              onPressed: () async {
                final wallet = context.read<HomeCubit>().state.selectedWalletCubit!;

                await SendPage.SendPopup.openSendPopUp(context, wallet);
              },
              label: 'Send',
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: buttonWidth,
            child: BBButton.smallRed(
              onPressed: () async {
                final wallet = context.read<HomeCubit>().state.selectedWalletCubit!;

                await ReceivePopUp.openPopUp(context, wallet);
              },
              label: 'Receive',
            ),
          ),
        ],
      ),
    );
  }
}

class HomeCard extends StatelessWidget {
  const HomeCard({super.key});

  (Color, String) cardDetails(BuildContext context, Wallet wallet) {
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

    final name = context.select((WalletBloc x) => x.state.wallet?.name);
    final fingerprint = context.select((WalletBloc x) => x.state.wallet?.sourceFingerprint ?? '');
    final walletStr = context.select((WalletBloc x) => x.state.wallet?.getWalletTypeShortString());

    final sats = context.select((WalletBloc x) => x.state.balanceSats());

    final balance =
        context.select((SettingsCubit x) => x.state.getAmountInUnits(sats, removeText: true));
    final unit = context.select((SettingsCubit x) => x.state.getUnitString());

    final currency = context.select((SettingsCubit x) => x.state.currency);
    final fiatAmt = context.select((SettingsCubit x) => x.state.calculatePrice(sats));

    final (color, info) = cardDetails(context, wallet);

    final keyName = 'home_card_$info';

    return Material(
      key: Key(keyName),
      elevation: 4,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      color: color,
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
        child: AspectRatio(
          aspectRatio: 2 / 1,
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
                    ],
                  ),
                ),
                BottomRight(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Opacity(
                      opacity: 0.7,
                      child: BBText.bodySmall(
                        walletStr ?? '',
                        onSurface: true,
                        isBold: true,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeNoWallets extends StatelessWidget {
  const HomeNoWallets({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBButton.bigRed(
            onPressed: () {
              context.push('/import');
            },
            label: 'New wallet',
          ),
        ],
      ),
    );
  }
}

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.pageIdx});

  final int pageIdx;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(left: 24, bottom: 10),
          child: pageIdx == 0
              ? Image.asset(
                  'assets/textlogo.png',
                  height: 27,
                  width: 147,
                )
              : const BBText.headline(
                  'BULL BITCOIN',
                  isRed: true,
                  isBold: true,
                ),
        ),
        const Spacer(),
        IconButton(
          color: pageIdx == 0 ? context.colour.onBackground : context.colour.onPrimary,
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
          color: pageIdx == 0 ? context.colour.onBackground : context.colour.onPrimary,
          icon: const Icon(
            FontAwesomeIcons.gear,
            shadows: [],
          ),
          onPressed: () {
            context.push('/settings');
          },
        ),
        const Gap(16),
      ],
    );
  }
}
