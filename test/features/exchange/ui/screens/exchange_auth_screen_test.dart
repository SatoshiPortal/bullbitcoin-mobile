import 'dart:convert';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/data/exchange_auth_repository_impl.dart';
import 'package:bb_mobile/features/exchange/data/exchange_web_auth_datasource.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../../../settings/fake_webview_platform.dart';

class _Settings extends Mock implements GetExchangeWebSettingsUsecase {}

class _Keys extends Mock implements ExchangeApiKeyRepository {}

class _Cubit extends Mock implements ExchangeCubit {}

class _Platform extends FakeWebViewPlatform {
  _Delegate? delegate;
  _Controller? controller;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
}

class _Controller extends FakePlatformWebViewController {
  _Controller(super.params);
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
  for (final scenario in ['deferred', 'acknowledge', 'retry', 'inactive']) {
    testWidgets('authentication WebView: $scenario', (tester) async {
      var generations = 0;
      var cookieClears = 0;
      var exits = 0;
      final platform = _Platform();
      WebViewPlatform.instance = platform;
      final settings = _Settings();
      final keys = _Keys();
      final cubit = _Cubit();
      when(settings.execute).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.btc,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(() => cubit.state).thenReturn(const ExchangeState());
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      locator.registerSingleton<GetExchangeWebSettingsUsecase>(settings);
      locator.registerFactoryParam<
        CompleteExchangeAuthenticationUsecase,
        Future<Object> Function(String),
        ({bool isTestnet, bool Function() isOpen})
      >(
        (_, session) => CompleteExchangeAuthenticationUsecase(
          authRepository: ExchangeAuthRepositoryImpl(
            datasource: ExchangeWebAuthDatasource(
              isTestnet: session.isTestnet,
              isOpen: session.isOpen,
              evaluateJavaScript: (_) async {
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
              },
            ),
          ),
          apiKeyRepository: keys,
          isTestnet: session.isTestnet,
        ),
      );
      registerFallbackValue(
        locator<CompleteExchangeAuthenticationUsecase>(
          param1: (String _) async => '',
          param2: (isTestnet: true, isOpen: () => true),
        ),
      );
      when(() => cubit.completeAuthentication(any())).thenAnswer((
        invocation,
      ) async {
        final operation =
            invocation.positionalArguments.first
                as CompleteExchangeAuthenticationUsecase;
        return switch (await operation.execute()) {
          Err(:final failure) => failure,
          Ok() => null,
        };
      });
      const channel = MethodChannel('webview_cookie_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'clearCookies') {
          cookieClears++;
          return null;
        }
        return [
          {'name': 'bb_session', 'value': 'synthetic-session'},
        ];
      });
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await locator.reset();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ExchangeCubit>.value(
            value: cubit,
            child: ExchangeAuthScreen(onExit: () => exits++),
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
      if (scenario == 'deferred') {
        expect(find.byType(AlertDialog), findsNothing);
      } else {
        expect(find.byType(AlertDialog), findsOneWidget);
        final buttons = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        );
        await tester.tap(scenario == 'retry' ? buttons.last : buttons.first);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(generations, 1);
      expect(cookieClears, 0);
      expect(exits, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(platform.controller?.reloadCount, scenario == 'retry' ? 1 : 0);
      verifyZeroInteractions(keys);
    });
  }
}
