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
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/bottom_wallet_actions.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/state.dart';
import 'package:bb_mobile/home/home2.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
// import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:bb_mobile/wallet/wallet_txs.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static List<WalletBloc> createWalletBlocs(List<Wallet> wallets) {
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
          walletUpdate: locator<WalletUpdate>(),
          networkCubit: locator<NetworkCubit>(),
        ),
    ];
    return walletCubits;
  }

  static Widget? setupHomeWallets(BuildContext context) {
    final wallets = context.select((HomeCubit x) => x.state.wallets ?? []);
    final loading = context.select((HomeCubit x) => x.state.loadingWallets);
    if (loading) return Container();

    final currentWalletBlocs = context.select((HomeCubit x) => x.state.walletBlocs ?? []);
    if (wallets.length != currentWalletBlocs.length) {
      final walletBlocs = createWalletBlocs(wallets);
      context.read<HomeCubit>().updateWalletBlocs(walletBlocs);
    }

    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final walletsFromNetwork =
        context.select((HomeCubit x) => x.state.walletBlocsFromNetwork(network));
    if (walletsFromNetwork.isEmpty) return const HomeNoWallets().animate().fadeIn();

    return null;
  }

  static ({WalletBloc? selectedWallet, List<WalletBloc> walletCubits}) selectHomeBlocs(
    BuildContext context,
  ) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    // final wallets = context.select((HomeCubit x) => x.state.walletsFromNetwork(network));
    final walletCubits = context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));

    final selectedWallet = context.select((HomeCubit x) => x.state.selectedWalletCubit);
    if (selectedWallet == null && walletCubits.isNotEmpty)
      context.read<HomeCubit>().walletSelected(walletCubits[walletCubits.length - 1]);

    return (selectedWallet: selectedWallet, walletCubits: walletCubits);
  }

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

class _Screen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final homeLayout = context.select((SettingsCubit _) => _.state.homeLayout);

    if (homeLayout == 1) return const HomePage2();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        shadowColor: context.colour.primary.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const HomeTopBar(pageIdx: 0),
      ),
      body: const HomeWallets(),
    );
  }
}

class HomeWallets extends StatelessWidget {
  const HomeWallets({super.key});

  @override
  Widget build(BuildContext context) {
    // final wallets = context.select((HomeCubit x) => x.state.wallets ?? []);

    // final loading = context.select((HomeCubit x) => x.state.loadingWallets);

    // if (loading) return Container();

    // final currentWalletBlocs = context.select((HomeCubit x) => x.state.walletBlocs ?? []);

    // if (wallets.length != currentWalletBlocs.length) {
    //   final walletBlocs = createWalletBlocs(wallets);
    //   context.read<HomeCubit>().updateWalletBlocs(walletBlocs);
    // }

    // final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    // final walletsFromNetwork =
    //     context.select((HomeCubit x) => x.state.walletBlocsFromNetwork(network));
    // if (walletsFromNetwork.isEmpty) return const HomeNoWallets().animate().fadeIn();

    final walletScreen = HomePage.setupHomeWallets(context);
    if (walletScreen != null) return walletScreen;

    return const WalletScreen()
        .animate(
          delay: const Duration(
            milliseconds: 300,
          ),
        )
        .fadeIn();
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    // // final wallets = context.select((HomeCubit x) => x.state.walletsFromNetwork(network));
    // // final walletCubits = context.select((HomeCubit _) => _.state.walletBlocs ?? []);
    // final walletCubits = context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    // // final walletCubits = wallets.map((e) => )

    // final selectedWallet = context.select((HomeCubit x) => x.state.selectedWalletCubit);

    // if (selectedWallet == null && walletCubits.isNotEmpty)
    //   context.read<HomeCubit>().walletSelected(walletCubits[walletCubits.length - 1]);

    final homeWallets = HomePage.selectHomeBlocs(context);

    return _HomeLayout1(
      selectedWallet: homeWallets.selectedWallet,
      walletCubits: homeWallets.walletCubits,
    );
  }
}

class _HomeLayout1 extends StatelessWidget {
  const _HomeLayout1({
    required this.selectedWallet,
    required this.walletCubits,
  });

  final WalletBloc? selectedWallet;
  final List<WalletBloc> walletCubits;

  @override
  Widget build(BuildContext context) {
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
                          value: selectedWallet!,
                          child: const BackupAlertBanner(),
                        ),
                      ],
                      const HomeHeaderCards(),
                      if (selectedWallet != null) ...[
                        BlocProvider.value(
                          value: selectedWallet!,
                          child: const WalletTxList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: HomeActionButtons(
                  walletBloc: walletCubits.length == 1 ? walletCubits[0] : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeHeaderCards extends StatefulWidget {
  const HomeHeaderCards({super.key});

  @override
  State<HomeHeaderCards> createState() => _HomeHeaderCardsState();
}

class _HomeHeaderCardsState extends State<HomeHeaderCards> {
  final CarouselController _carouselController = CarouselController();

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final walletCubits = context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletIdx = context.select((HomeCubit _) => _.state.getSelectedWalletIdx());

    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (previous, current) => previous.moveToIdx != current.moveToIdx,
      listener: (context, state) {
        final moveToIdx = state.moveToIdx;
        if (moveToIdx == null) return;
        _carouselController.animateToPage(
          moveToIdx,
          curve: Curves.easeInOut,
          duration: 600.milliseconds,
        );
        final selected = walletCubits[moveToIdx];
        context.read<HomeCubit>().walletSelected(selected);
      },
      child: CarouselSlider(
        carouselController: _carouselController,
        options: CarouselOptions(
          initialPage: selectedWalletIdx ?? (walletCubits.length - 1),
          enlargeStrategy: CenterPageEnlargeStrategy.zoom,
          reverse: true,
          enableInfiniteScroll: false,
          aspectRatio: 2.1,
          onPageChanged: (i, s) {
            context.read<HomeCubit>().walletSelected(walletCubits[i]);
          },
        ),
        items: [
          for (final w in walletCubits) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: BlocProvider.value(
                value: w,
                child: Builder(
                  builder: (context) {
                    return HomeCard(
                      onTap: () {
                        final walletBloc = context.read<WalletBloc>();
                        context.push('/wallet', extra: walletBloc);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ],
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
        GestureDetector(
          onLongPress: () {
            context.push('/logs');
          },
          child: Container(
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
        ),
        const Spacer(),
        IconButton(
          key: UIKeys.homeImportButton,
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
        IconButton(
          // key: UIKeys.homeSettingsButton,
          color: pageIdx == 0 ? context.colour.onBackground : context.colour.onPrimary,
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
