import 'dart:io';
import 'dart:ui' as ui;

import 'package:ark/ark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;

import 'ark_shell_visual_fixtures.dart';
import 'ark_flow_visual_fixtures.dart';

import '../../../features/ark/test/ark_account_screen_test.dart' as wallet;
import '../../../features/ark/test/ark_board_screen_test.dart' as board;
import '../../../features/ark/test/ark_exits_screen_test.dart' as exits;
import '../../../features/ark/test/ark_information_widget_test.dart'
    as information;
import '../../../features/ark/test/ark_payment_cubit_test.dart' as payment;
import '../../../features/ark/test/ark_receive_flow_test.dart' as receive;
import '../../../features/ark/test/ark_settings_flow_test.dart' as settings;
import '../../../features/ark/test/ark_vtxos_screen_test.dart' as vtxos;
import '../../../features/ark/test/fake_ark_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
    await (FontLoader(
      'Bebas Neue',
    )..addFont(rootBundle.load('assets/fonts/BebasNeue-Regular.ttf'))).load();
  });
  for (final theme in AppThemeType.values) {
    testWidgets('render Ark audit ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final output = Platform.environment['ARK_UI_OUTPUT'];
      Future<void> capture(
        String name,
        Widget screen, {
        Future<void> Function(WidgetTester)? arrange,
      }) async {
        stdout.writeln('Ark audit: $name ${theme.name}');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.themeData(theme),
            supportedLocales: ArkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ArkLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: RepaintBoundary(
              key: boundary,
              child: BullAmountScope(
                snapshot: const BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: false,
                  isReady: true,
                ),
                writeUnit: (_) async => false,
                child: screen,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (arrange != null) {
          await arrange(tester);
          await tester.pump();
        }
        expect(tester.takeException(), isNull, reason: name);
        final context = boundary.currentContext;
        if (context == null) throw StateError('Missing boundary for $name');
        final render = context.findRenderObject();
        if (render is! RenderRepaintBoundary) {
          throw StateError('Invalid boundary for $name');
        }
        if (output == null) {
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('goldens/$name-${theme.name}.png'),
          );
        } else {
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            if (data == null) throw StateError('Missing PNG for $name');
            final file = File('$output/$name-${theme.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      final shell = await ArkShellVisualFixtures.setUp();
      addTearDown(() => shell.tearDown().timeout(const Duration(seconds: 10)));
      await capture('Main', shell.settings());
      await capture('SendArkHome', shell.home());
      await capture(
        'ArkInfoFeeReserve',
        ArkInformationScreen(
          snapshot: ArkSnapshot(
            account: information.config().id,
            revision: 2,
            observedAt: DateTime.utc(2026, 11, 18),
            confirmedReserve: Sats.zero,
            reserveAddress: 'bcrt1qpublicfeereservefixtureforhostrenderonly',
          ),
          config: information.config(),
        ),
      );
      final client = wallet.Client()..snapshot = Ok(wallet.observation());
      final cubit = wallet.controller(client);
      await capture('SendArkWallet', wallet.screen(cubit, []));
      final unknown = wallet.controller(
        wallet.Client()..snapshot = Ok(wallet.observation(missing: true)),
      );
      await capture('SendArkWalletUnavailable', wallet.screen(unknown, []));
      final receiver = receive.controller(
        FakeArkClient()
          ..destination = Ok(
            ArkReceiveDestination(
              kind: ArkDestinationKind.ark,
              value: 'ark1publicfixtureaddressforlayoutonly',
            ),
          ),
      );
      addTearDown(receiver.close);
      await capture('SendArkReceiveEditing', ArkReceiveScreen(cubit: receiver));
      await receiver.request(lightning: false, amount: '');
      await capture(
        'SendArkReceive',
        ArkReceiveScreen(cubit: receiver, onShare: (_) {}),
      );
      final sender = payment.PaymentRig();
      await capture(
        'SendArkScan',
        ArkPaymentScreen(
          cubit: sender.cubit,
          onReconcile: () {},
          onScan: () async => null,
        ),
      );
      final amountSender = payment.PaymentRig();
      await capture(
        'SendArkAmount',
        ArkPaymentScreen(
          cubit: amountSender.cubit,
          initialDestination: payment.destination,
          observedSpendable: Sats.fromInt(1234),
          onReconcile: () {},
        ),
      );
      await sender.ready();
      await capture(
        'SendArkConfirm',
        ArkPaymentScreen(cubit: sender.cubit, onReconcile: () {}),
      );
      sender.cubit.emit(
        ArkPaymentSubmitted(
          ArkOperation(
            id: 'public-payment-operation',
            kind: ArkOperationKind.payment,
            status: ArkOperationStatus.succeeded,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
          ),
        ),
      );
      await capture(
        'SendArkSent',
        ArkPaymentScreen(cubit: sender.cubit, onReconcile: () {}),
      );
      final boarding = board.Rig();
      await boarding.cubit.prepare(Sats.fromInt(1000));
      await capture('BoardConfirm', boarding.screen);
      await capture(
        'BoardAmount',
        ArkBoardAmountScreen(
          config: information.config(),
          onReviewRequest: (_, _) {},
        ),
      );
      await capture(
        'ArkInfo',
        ArkInformationScreen(
          snapshot: vtxos.view(),
          config: information.config(),
        ),
      );
      final preferences = settings.Fixture()..preferences.enabled = true;
      addTearDown(preferences.cubit.close);
      await capture(
        'ArkSettings',
        ArkSettingsScreen(cubit: preferences.cubit, onOpenAccount: (_) {}),
      );
      await capture(
        'Vtxos',
        ArkVtxosScreen(snapshot: vtxos.view(), onRenew: (_) {}),
      );
      await capture(
        'VtxosEmpty',
        ArkVtxosScreen(
          snapshot: vtxos.view(values: []),
          onRenew: (_) {},
          onBoard: () {},
        ),
      );
      await capture('EmergencyExit', exits.Harness(exits.view()).screen);
      await capture(
        'ExitEmpty',
        exits.Harness(exits.view(rows: [], exits: ArkExitStatus.none)).screen,
      );
      for (final frame in await arkFlowFrames()) {
        await capture(frame.name, frame.screen, arrange: frame.arrange);
      }
    });
  }
}
