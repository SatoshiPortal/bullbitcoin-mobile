import 'dart:async';

import 'package:bb_mobile/features/wallet/ui/widgets/ark_receive_share.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart'
    show ArkReceiveReady;
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSnackBar;
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../features/ark/test/ark_module_composition_test.dart'
    show Client, Registry;
import '../../../../../features/ark/test/ark_operations_test.dart'
    show Provisioner;
import '../../../../../features/ark/test/ark_settings_flow_test.dart'
    show config, Selection, Preferences;
import '../../../../../features/ark/test/fake_ark_board_funding.dart';

class _Display implements ArkBoardSourcePort {
  final events = StreamController<void>.broadcast();
  final value = ArkDisplayData(
    account: config().id,
    walletId: 'source-wallet',
    available: Sats.fromInt(100000),
    sourceLabel: 'Current source',
  );
  bool accepted = true;
  @override
  Stream<void> changes(ArkAccountId account) => events.stream;
  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) async =>
      Ok(value);
  @override
  Future<Result<ArkDisplayData, ArkFailure>> refresh(
    ArkAccountId account,
  ) async => Ok(value);
  @override
  bool accepts(ArkDisplayData observation) =>
      accepted && identical(observation, value);
}

Future<({ArkFeature feature, GoRouter router, Client client})> _mount(
  WidgetTester tester,
  _Display display, {
  ArkShare? share,
  bool explicitSource = false,
}) async {
  final client = Client()
    ..destination = Ok(
      ArkReceiveDestination(
        kind: ArkDestinationKind.ark,
        value: 'public-destination',
      ),
    );
  final feature = ArkFeature(
    Selection(),
    config: config(),
    client: client,
    preferences: Preferences()..enabled = true,
    provisioning: Provisioner(),
    registry: Registry(),
    boardFunding: FakeArkBoardFunding(),
    displayData: display,
    boardSource: explicitSource ? display : null,
    share: share,
  );
  final router = GoRouter(initialLocation: '/ark', routes: feature.routes);
  addTearDown(() {
    feature.invalidate();
    router.dispose();
  });
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: testBullExtensions),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
    ),
  );
  await tester.pumpAndSettle();
  return (feature: feature, router: router, client: client);
}

void main() {
  for (final mode in [
    'same-ready-rebuild',
    'edited-ready',
    'closed-sheet',
    'invalidated-owner',
  ]) {
    testWidgets('Share composition feedback is publication-bound after $mode', (
      tester,
    ) async {
      final display = _Display();
      addTearDown(display.events.close);
      addTearDown(BullSnackBar.dismiss);
      final reply = Completer<ShareResult>();
      BuildContext? invokedContext;
      var calls = 0;
      final host = await _mount(
        tester,
        display,
        share: (context, text, {required isCurrent}) {
          invokedContext = context;
          return shareArkReceive(
            context,
            text,
            isCurrent: isCurrent,
            share: (params) {
              calls++;
              expect(params.text, 'public-destination');
              return reply.future;
            },
          );
        },
      );
      tester
          .widget<ArkSettingsScreen>(find.byType(ArkSettingsScreen))
          .onOpenAccount(config());
      await tester.pumpAndSettle();
      final account = tester.widget<ArkAccountScreen>(
        find.byType(ArkAccountScreen),
      );
      account.onReceive();
      await tester.pumpAndSettle();
      final page = tester.widget<ArkReceiveScreen>(
        find.byType(ArkReceiveScreen),
      );
      final owner = page.cubit;
      final ready = owner.state;
      expect(ready, isA<ArkReceiveReady>());
      expect(
        host.client.calls.where((call) => call == 'receive'),
        hasLength(1),
      );
      await tester.tap(
        find.byKey(const ValueKey('ark-receive-address-actions')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BullButton, 'Share'));
      expect(calls, 1);
      final context = invokedContext;
      if (context == null) throw StateError('Missing live sheet context');
      final message = AppLocalizations.of(context).oopsSomethingWentWrong;
      final callback = tester
          .widget<ArkReceiveScreen>(find.byType(ArkReceiveScreen))
          .share;
      if (mode == 'same-ready-rebuild') {
        display.events.add(null);
        await tester.pumpAndSettle();
        final rebuilt = tester.widget<ArkReceiveScreen>(
          find.byType(ArkReceiveScreen),
        );
        expect(identical(rebuilt, page), false);
        expect(identical(rebuilt.cubit, owner), true);
        expect(identical(owner.state, ready), true);
        expect(
          identical(
            tester
                .widget<ArkReceiveScreen>(find.byType(ArkReceiveScreen))
                .share,
            callback,
          ),
          true,
        );
      } else if (mode == 'edited-ready') {
        owner.edit();
        await tester.pumpAndSettle();
      } else if (mode == 'closed-sheet') {
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
      } else {
        host.feature.invalidate();
        await tester.pumpAndSettle();
      }
      reply.completeError(PlatformException(code: 'fixture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(message),
        mode == 'same-ready-rebuild' ? findsOneWidget : findsNothing,
      );
      expect(
        host.client.calls.where((call) => call == 'receive'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }

  for (final explicit in [false, true]) {
    testWidgets(
      'source label publication guard explicit=$explicit preserves passive fallback',
      (tester) async {
        final display = _Display();
        addTearDown(display.events.close);
        await _mount(tester, display, explicitSource: explicit);
        tester
            .widget<ArkSettingsScreen>(find.byType(ArkSettingsScreen))
            .onBoard
            ?.call();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArkBoardScreen>(find.byType(ArkBoardScreen))
              .sourceLabel
              ?.label,
          'Current source',
        );
        display.accepted = false;
        display.events.add(null);
        await tester.pumpAndSettle();
        final board = tester.widget<ArkBoardScreen>(
          find.byType(ArkBoardScreen),
        );
        expect(board.sourceLabel?.label, explicit ? null : 'Current source');
        expect(board.displayData?.available, Sats.fromInt(100000));
      },
    );
  }
}
