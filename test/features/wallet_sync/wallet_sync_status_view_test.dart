import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/wallet_sync/presentation/wallet_sync_status_cubit.dart';
import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/watch_wallet_sync_status_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_status_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Watch extends Fake implements WatchWalletSyncStatusUsecase {
  final Stream<WalletSyncStatus> stream;
  _Watch(this.stream);
  @override
  Stream<WalletSyncStatus> execute(String walletId) => stream;
}

class _Start extends Fake implements StartWalletSyncUsecase {
  @override
  void execute(String walletId, {bool policyChanged = false}) {}
}

const _key = WalletNetworkKey('public', 'bitcoin', 'mainnet');
Widget _app(Widget child, {String locale = 'en', bool dark = false}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.themeData(dark ? AppThemeType.dark : AppThemeType.light),
      home: Scaffold(body: child),
    );
Widget _view(
  Stream<WalletSyncStatus> stream,
  WalletSyncViewKind kind, {
  VoidCallback? onNetwork,
}) => WalletSyncStatusView(
  walletId: 'public',
  watch: _Watch(stream),
  start: _Start(),
  kind: kind,
  onSettings: () {},
  onNetwork: onNetwork ?? () {},
);
void main() {
  for (final dark in [false, true]) {
    testWidgets('recovery completion survives coalesced frames (dark=$dark)', (
      tester,
    ) async {
      final stream = StreamController<WalletSyncStatus>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        _app(_view(stream.stream, WalletSyncViewKind.recovery), dark: dark),
      );
      stream.add(
        const WalletSyncStatus(
          progress: BitcoinSyncProgress(
            key: _key,
            phase: BitcoinSyncPhase.checkingBlocks,
            isRecovery: true,
            operationId: 1,
            fraction: 0.9,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Checking blocks'), findsOneWidget);
      const done = WalletSyncStatus(
        recoveryRequired: false,
        progress: BitcoinSyncProgress(
          key: _key,
          phase: BitcoinSyncPhase.done,
          isRecovery: true,
          operationId: 1,
          fraction: 1,
        ),
      );
      const reactive = WalletSyncStatus(
        recoveryRequired: false,
        progress: BitcoinSyncProgress(
          key: _key,
          phase: BitcoinSyncPhase.checkingBlocks,
          isRecovery: false,
          operationId: 1,
        ),
      );
      // A retained node may publish again before Flutter paints recovery done.
      stream.add(done);
      stream.add(reactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Incomplete — still checking older blocks'),
        findsNothing,
      );
      expect(find.text('Wallet restored'), findsOneWidget);
      BullSnackBar.dismiss();
      await tester.pump(const Duration(seconds: 4));
      stream.add(done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Wallet restored'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      // Reopening a completed operation must not replay the confirmation.
      await tester.pumpWidget(
        _app(
          _view(Stream.value(done), WalletSyncViewKind.recovery),
          dark: dark,
        ),
      );
      await tester.pump();
      expect(find.text('Wallet restored'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test(
    'returning from Tor settings refreshes local status without starting a scan',
    () async {
      final watch = _ReloadingWatch();
      final start = _Start();
      final cubit = WalletSyncStatusCubit(
        walletId: 'public',
        watch: watch,
        start: start,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(cubit.state?.torEnabled, isFalse);
      watch.tor = true;
      await cubit.refresh();
      await pumpEventQueue();
      expect(cubit.state?.torEnabled, isTrue);
      expect(watch.reads, 2);
    },
  );

  testWidgets(
    'status shows height and relative freshness and opens network detail',
    (tester) async {
      var opened = false;
      final status = WalletSyncStatus(
        recoveryRequired: false,
        lastSuccessfulSync: DateTime.now().toUtc().subtract(
          const Duration(minutes: 3),
        ),
        progress: const BitcoinSyncProgress(
          key: _key,
          phase: BitcoinSyncPhase.done,
          targetHeight: 970000,
        ),
      );
      await tester.pumpWidget(
        _app(
          _view(
            Stream.value(status),
            WalletSyncViewKind.status,
            onNetwork: () => opened = true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Status'), findsOneWidget);
      expect(
        find.textContaining('Up to date · block 970,000 · 3 min ago'),
        findsOneWidget,
      );
      await tester.tap(find.text('Status'));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final (locale, dark) in [('en', false), ('fr', true), ('ar', true)]) {
    testWidgets(
      'expert network screen keeps peer addresses private ($locale)',
      (tester) async {
        final status = WalletSyncStatus(
          recoveryRequired: false,
          torEnabled: true,
          lastSuccessfulSync: DateTime.now().toUtc(),
          progress: const BitcoinSyncProgress(
            key: _key,
            phase: BitcoinSyncPhase.done,
            targetHeight: 200,
            connectedPeers: 2,
          ),
        );
        await tester.pumpWidget(
          _app(
            _view(Stream.value(status), WalletSyncViewKind.network),
            locale: locale,
            dark: dark,
          ),
        );
        await tester.pump();
        if (locale == 'en') {
          expect(find.text('2 connected peers'), findsOneWidget);
          expect(find.text('Tor: on'), findsOneWidget);
          expect(find.text('Tip height: 200'), findsOneWidget);
        }
        if (locale == 'fr') {
          expect(find.text('2 pairs connectés'), findsOneWidget);
        }
        if (locale == 'ar') {
          expect(
            Directionality.of(
              tester.element(find.byType(WalletSyncStatusView)),
            ),
            TextDirection.rtl,
          );
        }
        expect(find.textContaining('127.0.0.1'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final dark in [false, true]) {
    testWidgets('private receive note uses a text action (dark=$dark)', (
      tester,
    ) async {
      var settings = 0;
      await tester.pumpWidget(
        _app(
          WalletSyncStatusView(
            walletId: 'public',
            watch: _Watch(Stream.value(const WalletSyncStatus())),
            start: _Start(),
            kind: WalletSyncViewKind.receiveNote,
            onSettings: () => settings++,
            onNetwork: () {},
          ),
          dark: dark,
        ),
      );
      await tester.pump();
      expect(
        find.text(
          'Private sync: this payment will appear once confirmed, usually within an hour.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final action = tester.widget<BullButton>(find.byType(BullButton));
      expect(action.outlined, isFalse);
      expect(action.size, BullButtonSize.small);
      expect(action.bgColor.a, 0);
      expect(action.compact, isTrue);
      expect(tester.getSize(find.byType(BullButton)).width, lessThan(300));
      await tester.tap(find.text('Sync settings'));
      expect(settings, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final tor in [false, true]) {
    testWidgets('private send explains its route (Tor=$tor)', (tester) async {
      await tester.pumpWidget(
        _app(
          _view(
            Stream.value(
              WalletSyncStatus(recoveryRequired: false, torEnabled: tor),
            ),
            WalletSyncViewKind.sendReview,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          tor
              ? 'Sent through a random Bitcoin node over Tor'
              : 'Sent through a random Bitcoin node',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'persisted private source reveals recovery without a wallet bloc update',
    (tester) async {
      final stream = StreamController<WalletSyncStatus>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        _app(_view(stream.stream, WalletSyncViewKind.incomplete)),
      );
      stream.add(
        const WalletSyncStatus(
          source: BitcoinSyncSource.electrum,
          recoveryRequired: false,
        ),
      );
      await tester.pump();
      expect(
        find.text('Incomplete — still checking older blocks'),
        findsNothing,
      );
      stream.add(const WalletSyncStatus());
      await tester.pump();
      expect(
        find.text('Incomplete — still checking older blocks'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ReloadingWatch extends Fake implements WatchWalletSyncStatusUsecase {
  bool tor = false;
  int reads = 0;
  @override
  Stream<WalletSyncStatus> execute(String walletId) {
    reads++;
    return Stream.value(WalletSyncStatus(torEnabled: tor));
  }
}
