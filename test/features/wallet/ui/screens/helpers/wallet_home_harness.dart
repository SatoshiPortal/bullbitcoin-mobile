import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class TestWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _PriceBloc extends MockBloc<BitcoinPriceEvent, BitcoinPriceState>
    implements BitcoinPriceBloc {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _Chart extends MockCubit<PriceChartState> implements PriceChartCubit {}

class _Announcements extends MockCubit<AnnouncementsState>
    implements AnnouncementsCubit {}

class WalletHomeHarness {
  late TestWalletBloc wallet;
  late StreamController<WalletState> states;
  late Completer<void> refresh;
  late GoRouter router;
  final boundaryKey = GlobalKey();

  WalletHomeHarness() {
    wallet = TestWalletBloc();
    states = StreamController<WalletState>.broadcast();
    when(() => wallet.refresh()).thenAnswer((_) => refresh.future);
  }

  Future<void> dispose() async {
    if (!refresh.isCompleted) refresh.complete();
    await states.close();
    router.dispose();
    await wallet.close();
  }

  Future<void> mount(WidgetTester tester, WalletState initial) async {
    refresh = Completer<void>();
    if (Platform.environment['WALLET_REFRESH_CAPTURE_DIR'] != null) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('Golos Text')
          ..addFont(rootBundle.load('assets/fonts/GolosText.ttf'));
        await font.load();
      });
    }
    whenListen(wallet, states.stream, initialState: initial);
    final price = _PriceBloc();
    whenListen(
      price,
      const Stream<BitcoinPriceState>.empty(),
      initialState: const BitcoinPriceState(
        currency: 'USD',
        bitcoinPrice: 60000,
      ),
    );
    final settings = _Settings();
    whenListen(
      settings,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    final chart = _Chart();
    whenListen(
      chart,
      const Stream<PriceChartState>.empty(),
      initialState: const PriceChartState(),
    );
    final announcements = _Announcements();
    whenListen(
      announcements,
      const Stream<AnnouncementsState>.empty(),
      initialState: const AnnouncementsState(),
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: WalletHomeScreen()),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletBloc>.value(value: wallet),
          BlocProvider<BitcoinPriceBloc>.value(value: price),
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<PriceChartCubit>.value(value: chart),
          BlocProvider<AnnouncementsCubit>.value(value: announcements),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['WALLET_REFRESH_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}
