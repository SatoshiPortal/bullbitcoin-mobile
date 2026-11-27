import 'dart:async';

import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/ark_dashboard_entry.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart' show WalletCard;
import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:settings/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _Wallet extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _Inventory extends Mock implements WalletInventory {}

final class _Cache extends InMemorySharedPreferencesAsync {
  _Cache() : super.empty();

  final reads = <(String, Completer<String?>)>[];

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    final pending = Completer<String?>();
    reads.add((key, pending));
    return pending.future;
  }
}

void main() {
  testWidgets(
    'a late remembered balance cannot cross Ark hosts at equal scope',
    (tester) async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      final cache = _Cache();
      SharedPreferencesAsyncPlatform.instance = cache;
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance =
            previous ?? InMemorySharedPreferencesAsync.empty();
      });
      ArkForegroundHost host(int port) {
        final services = GetIt.asNewInstance();
        final host = ArkForegroundHost(
          services,
          arkUrl: Uri.parse('http://127.0.0.1:$port'),
          primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
          initializeNew: false,
          boardFunding: () => throw StateError('Home must not open funding'),
          inventory: _Inventory(),
        );
        addTearDown(() async {
          await host.close();
          await services.reset();
        });
        return host;
      }

      final a = host(7070);
      final b = host(7071);
      final wallet = _Wallet();
      final settings = _Settings();
      addTearDown(wallet.close);
      addTearDown(settings.close);
      whenListen(
        wallet,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(),
      );
      whenListen(
        settings,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      Future<void> pump(ArkForegroundHost host) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          home: MultiBlocProvider(
            providers: [
              BlocProvider<WalletBloc>.value(value: wallet),
              BlocProvider<SettingsCubit>.value(value: settings),
              BitcoinPriceFixture.prices(),
            ],
            child: Scaffold(body: ArkDashboardEntry(host: host, refresh: 0)),
          ),
        ),
      );
      await pump(a);
      expect(cache.reads, hasLength(1));
      await pump(b);
      cache.reads.first.$2.complete('900');
      await tester.pump();
      expect(
        find.byType(WalletCard),
        findsNothing,
        reason: 'Host A is retired',
      );
      expect(cache.reads, hasLength(2));
      expect(cache.reads.first.$1, cache.reads.last.$1);
      cache.reads.last.$2.complete('21');
      await tester.pump();
      expect(tester.widget<WalletCard>(find.byType(WalletCard)).balanceSat, 21);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
