import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/screens/receive_payjoin_in_progress_screen.dart';

class _FakeBloc extends Fake implements ReceiveBloc {
  _FakeBloc(this.state);

  @override
  final ReceiveState state;

  @override
  Stream<ReceiveState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

void main() {
  testWidgets('completed payjoin with animation fits a small scaled screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(840, 1200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    Size? logicalSize;
    final bloc = _FakeBloc(
      ReceiveState(
        payjoin: PayjoinReceiverSession(
          status: PayjoinStatus.completed,
          id: 'session',
          network: BitcoinNetwork.regtest,
          walletId: 'wallet',
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
          payjoinUri: 'https://example.com',
          hasOriginalTransaction: true,
          hasProposal: true,
        ),
        showPaymentAnimations: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          logicalSize = media.size;
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: const Scaffold(body: PayjoinInProgressPage()),
        ),
      ),
    );
    expect(logicalSize, const Size(320, 1200 / 2.625));
    expect(tester.takeException(), isNull);
    expect(find.byType(BullPaymentAnimation), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is BullText && widget.text == 'Payment in progress',
      ),
      findsOneWidget,
    );
    final details = find.byWidgetPredicate(
      (widget) => widget is BullButton && widget.label == 'View Details',
    );
    expect(details, findsOneWidget);
    await tester.ensureVisible(details);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(Scaffold)).contains(tester.getCenter(details)),
      isTrue,
    );
  });

  for (final (status, animations, size) in [
    (PayjoinStatus.requested, false, const Size(1080, 2400)),
    (PayjoinStatus.requested, true, const Size(1080, 2400)),
    (PayjoinStatus.aborted, false, const Size(840, 1200)),
    (PayjoinStatus.expired, false, const Size(840, 1200)),
  ]) {
    testWidgets('payjoin $status, animations=$animations lays out', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final bloc = _FakeBloc(
        ReceiveState(
          payjoin: PayjoinReceiverSession(
            status: status,
            id: 'session',
            network: BitcoinNetwork.regtest,
            walletId: 'wallet',
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
            payjoinUri: 'https://example.com',
            hasOriginalTransaction: true,
          ),
          showPaymentAnimations: animations,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.dark),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ReceiveLocalizations.delegate,
          ],
          supportedLocales: ReceiveLocalizations.supportedLocales,
          home: BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: const Scaffold(body: PayjoinInProgressPage()),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PayjoinInProgressPage), findsOneWidget);
      if (status == PayjoinStatus.aborted || status == PayjoinStatus.expired) {
        final action = find.byType(BullButton);
        expect(action, findsOneWidget);
        await tester.ensureVisible(action);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
