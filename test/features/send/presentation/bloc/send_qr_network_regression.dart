import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scanning/public/qr_scanning.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Settings extends Mock implements GetSettingsUsecase {}

/// Exercises the stable camera text boundary across scanner API changes.
void registerSendQrNetworkRegression({
  required SendCubit Function(DetectBitcoinStringUsecase) buildCubit,
  required void Function() verifyNoProgression,
}) {
  group('QR active network regression', () {
    setUpAll(BullSdk.init);
    tearDownAll(BullSdk.dispose);

    const mainnet = 'bc1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3h8ffkz';
    const testnet = 'tb1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3apj6d3';
    const regtest = 'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c';

    Future<SendCubit> mount(
      WidgetTester tester,
      Environment environment, {
      required bool autoContinue,
      Future<SettingsEntity> Function()? readSettings,
    }) async {
      final settings = _Settings();
      when(() => settings.execute()).thenAnswer(
        (_) async => readSettings != null
            ? await readSettings()
            : SettingsEntity(
                environment: environment,
                bitcoinUnit: BitcoinUnit.sats,
                currencyCode: 'CAD',
              ),
      );
      final cubit = buildCubit(DetectBitcoinStringUsecase(settings: settings));
      addTearDown(cubit.close);
      const cameraChannel = MethodChannel('plugins.flutter.io/camera');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cameraChannel,
        (call) async => call.method == 'availableCameras' ? [] : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          cameraChannel,
          null,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<SendCubit>.value(
              value: cubit,
              child: Scaffold(
                body: AddressField(multipleRecipients: !autoContinue),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    Future<QrScannerWidget> openCamera(WidgetTester tester) async {
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      return tester.widget<QrScannerWidget>(find.byType(QrScannerWidget));
    }

    Future<void> scan(
      WidgetTester tester,
      QrScannerWidget camera,
      SendCubit cubit,
      String raw,
    ) async {
      await tester.runAsync(() async {
        final resolved = cubit.stream.firstWhere(
          (state) =>
              state.scannedRawPaymentRequest == raw &&
              (state.failure != null || state.paymentRequest != null),
        );
        camera.onScanned(raw);
        await resolved.timeout(const Duration(seconds: 10));
        await pumpEventQueue();
      });
      await tester.pumpAndSettle();
    }

    for (final (environment, foreign) in [
      (Environment.mainnet, testnet),
      (Environment.mainnet, 'tex1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38gxc8f'),
      (Environment.regtest, 'tex1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38gxc8f'),
      (Environment.mainnet, 'bitcoin:$testnet?amount=0.000025&label=fixture'),
      (Environment.testnet, mainnet),
      (Environment.testnet, 'bitcoin:$mainnet?amount=0.000025'),
      (Environment.regtest, mainnet),
      (Environment.regtest, testnet),
      (Environment.mainnet, regtest),
      (Environment.testnet, regtest),
      (Environment.mainnet, 'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc'),
    ]) {
      for (final autoContinue in [false, true]) {
        testWidgets(
          '$environment refuses $foreign with autoContinue=$autoContinue',
          (tester) async {
            final cubit = await mount(
              tester,
              environment,
              autoContinue: autoContinue,
            );
            final camera = await openCamera(tester);
            final valid = switch (environment) {
              Environment.mainnet => mainnet,
              Environment.testnet => testnet,
              Environment.regtest => regtest,
            };
            await tester.runAsync(() => cubit.onChangedText(valid));
            await tester.pumpAndSettle();
            expect(cubit.state.paymentRequest, isNotNull);
            expect(cubit.state.failure, isNull);
            verifyNoProgression();

            await scan(tester, camera, cubit, foreign);

            expect(
              cubit.state.failure,
              isA<SendInvalidPaymentRequestFailure>(),
            );
            expect(cubit.state.paymentRequest, isNull);
            expect(cubit.state.scannedRawPaymentRequest, foreign);
            expect(cubit.state.recipientDrafts.single.isValid, isFalse);
            expect(cubit.state.selectedWallet, isNull);
            expect(cubit.state.loadingBestWallet, isFalse);
            expect(cubit.state.step, SendStep.address);
            verifyNoProgression();
          },
        );
      }
    }

    for (final (environment, address) in [
      (Environment.mainnet, mainnet),
      (Environment.testnet, testnet),
      (Environment.regtest, regtest),
    ]) {
      testWidgets('$environment preserves scanned BIP21 like typed input', (
        tester,
      ) async {
        final cubit = await mount(tester, environment, autoContinue: false);
        final camera = await openCamera(tester);
        final raw = 'bitcoin:$address?amount=0.000025&label=fixture&message=qr';
        await tester.runAsync(() => cubit.onChangedText(raw));
        final typed = cubit.state.paymentRequest;
        expect(typed, isA<Bip21PaymentRequest>());
        await tester.runAsync(() => cubit.onChangedText(''));
        await tester.pumpAndSettle();

        await scan(tester, camera, cubit, raw);

        expect(cubit.state.failure, isNull);
        expect(cubit.state.paymentRequest, typed);
        expect(cubit.state.paymentRequest?.amountSat, 2500);
        expect(cubit.state.scannedRawPaymentRequest, raw);
        expect(cubit.state.recipientDrafts.single.isValid, isTrue);
        expect(cubit.state.step, SendStep.address);
        verifyNoProgression();
      });
    }

    testWidgets(
      'Continue joins a pending scan instead of its cached recipient',
      (tester) async {
        Completer<SettingsEntity>? pendingSettings;
        late final Completer<void> detectionStarted;
        const settings = SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        );
        final cubit = await mount(
          tester,
          Environment.mainnet,
          autoContinue: false,
          readSettings: () async {
            final pending = pendingSettings;
            if (pending == null) return settings;
            if (!detectionStarted.isCompleted) detectionStarted.complete();
            return pending.future;
          },
        );
        final camera = await openCamera(tester);
        await tester.runAsync(() => cubit.onChangedText(mainnet));
        await tester.pumpAndSettle();
        expect(cubit.state.paymentRequest, isNotNull);
        await tester.runAsync(() async {
          detectionStarted = Completer<void>();
          final pending = Completer<SettingsEntity>();
          pendingSettings = pending;
          addTearDown(() {
            if (!pending.isCompleted) pending.complete(settings);
          });
          camera.onScanned(testnet);
          await Future.any([
            detectionStarted.future,
            Future<void>.delayed(const Duration(milliseconds: 300)),
          ]);
          expect(detectionStarted.isCompleted, isTrue);
          expect(cubit.state.paymentRequest, isNull);
          expect(cubit.state.copiedRawPaymentRequest, testnet);
          final continuation = cubit.continueOnAddressConfirmed();
          await pumpEventQueue();
          verifyNoProgression();
          pending.complete(settings);
          await continuation;
          await pumpEventQueue();
        });
        await tester.pumpAndSettle();
        expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
        expect(cubit.state.paymentRequest, isNull);
        expect(cubit.state.step, SendStep.address);
        verifyNoProgression();
      },
    );
    testWidgets(
      'malformed raw scan reports a failure without an uncaught value',
      (tester) async {
        final cubit = await mount(
          tester,
          Environment.mainnet,
          autoContinue: true,
        );
        final camera = await openCamera(tester);
        final uncaught = <Object>[];
        await tester.runAsync(() async {
          await runZonedGuarded(() async {
            camera.onScanned('bitcoin:');
            await pumpEventQueue(times: 50);
          }, (error, _) => uncaught.add(error));
        });
        await tester.pumpAndSettle();
        expect(uncaught, isEmpty);
        expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
        expect(cubit.state.paymentRequest, isNull);
        expect(cubit.state.step, SendStep.address);
        verifyNoProgression();
      },
    );
  });
}
