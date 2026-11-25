import '../../fixtures/legacy_access.dart';

import 'package:exchange/setup.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:bull_ui/app_theme.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../../settings/fake_webview_platform.dart';

class _Settings extends Mock implements Preferences {}

class _Keys extends Mock implements ExchangeCredentials {}

class _Cubit extends Mock implements ExchangeCubit {}

typedef _Authenticate = Future<Result<void, ExchangeFailure>> Function({
  required bool Function() isCurrent,
});

class _Platform extends FakeWebViewPlatform {
  _Delegate? delegate;
  _Controller? controller;
  Object Function(String)? evaluate;
  final cookies = _Cookies(const PlatformWebViewCookieManagerCreationParams());
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => cookies;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params, evaluate);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
  int clears = 0;
  List<WebViewCookie> cookies = const [
    WebViewCookie(name: 'bb_session', value: '', domain: 'example.invalid'),
  ];
  @override
  Future<List<WebViewCookie>> getCookies(Uri url) async => cookies;
  @override
  Future<bool> clearCookies() async {
    clears++;
    return true;
  }
}

class _Controller extends FakePlatformWebViewController {
  final Object Function(String)? _evaluate;
  _Controller(super.params, this._evaluate);
  @override
  Future<Object> runJavaScriptReturningResult(String javascript) async =>
      _evaluate?.call(javascript) ?? '';

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setUserAgent(String? userAgent) async {}
}

class _Delegate extends FakePlatformNavigationDelegate {
  UrlChangeCallback? changed;
  _Delegate(super.params);
  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {
    changed = onUrlChange;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    Future<Result<void, ExchangeFailure>> fallback({
      required bool Function() isCurrent,
    }) async => const Ok(null);
    registerFallbackValue(fallback);
  });
  for (final scenario in [
    'deferred',
    'acknowledge',
    'retry',
    'inactive',
    'no-session',
  ]) {
    testWidgets('authentication WebView: $scenario', (tester) async {
      var generations = 0;
      var exits = 0;
      final platform = _Platform();
      if (scenario == 'no-session') platform.cookies.cookies = [];
      WebViewPlatform.instance = platform;
      final settings = _Settings();
      final keys = _Keys();
      final cubit = _Cubit();
      SharedPreferences.setMockInitialValues({});
      when(() => keys.readActiveApiKey(isTestnet: true))
          .thenAnswer((_) async => const Ok(null));
      final access = legacyAccessForTesting(
        apiKeyRepository: keys,
        readEnvironment: () async => true,
        platformAllowed: () async => true,
        disconnectNotifications: () async {},
        clearCookies: () async {},
      );
      final _ = await access.enable();
      when(settings.readActiveEnvironment)
          .thenAnswer((_) async => const Ok(Environment.testnet));
      when(() => cubit.state).thenReturn(const ExchangeState());
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      // The screen authenticates through its cubit, which runs the use case.
      when(
        () => cubit.completeAuthentication(
          any(),
          isCurrent: any(named: 'isCurrent'),
        ),
      ).thenAnswer(
        (invocation) =>
            (invocation.positionalArguments.single as _Authenticate)(
              isCurrent:
                  invocation.namedArguments[#isCurrent] as bool Function(),
            ),
      );
      platform.evaluate = (_) {
        generations++;
        return jsonEncode(
          scenario == 'deferred'
              ? {'error': 'request refused'}
              : scenario == 'inactive'
              ? {
                  'id': 'id',
                  'key': 'synthetic',
                  'name': 'name',
                  'userId': 'user',
                  'isActive': false,
                  'createdAt': 0,
                  'updatedAt': 0,
                }
              : {},
        );
      };
      final capability = Exchange.open(
        mainnetEndpoint: Uri.https('mainnet.example.invalid'),
        testnetEndpoint: Uri.https('testnet.example.invalid'),
        readSession: () async => fail('unexpected Exchange network request'),
        access: access,
        sessionPreferences: settings,
        basicAuth: ExchangeCredentials.openBasicAuth(
          InMemoryExchangeCredentialStorage(),
        ),
        webAuthEndpoints: (
          mainnet: Uri.parse(ExchangeDefaults.bbAuthUrl),
          testnet: Uri.parse(ExchangeDefaults.bbAuthTestUrl),
        ),
      );
      locator.registerSingleton<Exchange>(
        capability,
        dispose: (value) => value.close(),
      );
      addTearDown(locator.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ExchangeCubit>.value(
            value: cubit,
            child: ExchangeAuthScreen(
              onExit: () => exits++,
              host: exchangeAuthHost(() => capability),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final callback = platform.delegate?.changed;
      expect(callback, isNotNull);
      callback?.call(
        const UrlChange(url: 'https://accounts.bullbitcoin.com/login'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (scenario == 'deferred' || scenario == 'no-session') {
        expect(find.byType(AlertDialog), findsNothing);
      } else {
        expect(find.byType(AlertDialog), findsOneWidget);
        final loc = AppLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              scenario == 'retry'
                  ? loc.retry
                  : loc.exchangeAuthLoginFailedOkButton,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(generations, scenario == 'no-session' ? 0 : 1);
      expect(platform.cookies.clears, 0);
      expect(exits, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(platform.controller?.reloadCount, scenario == 'retry' ? 1 : 0);
      if (scenario == 'no-session') {
        verifyNever(
          () => cubit.completeAuthentication(
            any(),
            isCurrent: any(named: 'isCurrent'),
          ),
        );
      } else {
        verify(
          () => cubit.completeAuthentication(
            any(),
            isCurrent: any(named: 'isCurrent'),
          ),
        ).called(1);
      }
      verify(() => keys.readActiveApiKey(isTestnet: true)).called(1);
      verifyNoMoreInteractions(keys);
    });
  }
}
