import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import '../bullvault_test_fixture.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRestoreBullVaultUsecase extends Mock
    implements RestoreBullVaultUsecase {}

void main() {
  setUpAll(() => registerFallbackValue(BullVaultRestoreInputKind.descriptor));
  testWidgets('fills the descriptor field from a QR scan', (tester) async {
    const descriptor = 'tr(test-descriptor)';
    final cubit = BullVaultRestoreCubit(_MockRestoreBullVaultUsecase());
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: const BullVaultRestoreScreen(),
          ),
        ),
        GoRoute(
          name: BullVaultRouter.scannerRouteName,
          path: '/scan',
          builder: (context, state) {
            expect(state.extra, BullVaultScannerPurpose.descriptor);
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(descriptor),
                child: const Text('Return descriptor'),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    expect(find.text('Mobile passphrase (if configured)'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return descriptor'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text),
      contains(descriptor),
    );
  });
  testWidgets('restores first, then accepts the mobile passphrase with a retry', (
    tester,
  ) async {
    final fixture = testBullVaultCreateResult(mobilePassphrase: 'configured');
    final original = fixture.record;
    final recoveredPolicy = original.recoveryPackage.policy
        .withEverydayOwnership(.local);
    expect(recoveredPolicy.everydayKey.accountKey.requiresPassphrase, isFalse);
    final recoveredRecord = BullVaultRecord(
      walletId: original.walletId,
      lineageId: original.lineageId,
      vaultGeneration: original.vaultGeneration,
      mobileAccount: original.mobileAccount,
      birthHeight: original.birthHeight,
      createdAt: original.createdAt,
      recoveryPackage: BullVaultRecoveryPackage(policy: recoveredPolicy),
    );
    final recovery = BullVaultRestoreResult(
      wallet: fixture.wallet,
      record: recoveredRecord,
      mobileAccess: .recoveryOnly,
    );
    final unlocked = BullVaultRestoreResult(
      wallet: fixture.wallet,
      record: fixture.record,
      mobileAccess: .available,
    );
    final restore = _MockRestoreBullVaultUsecase();
    when(
      () => restore.execute(
        kind: any(named: 'kind'),
        source: any(named: 'source'),
        label: any(named: 'label'),
        mobilePassphrase: any(named: 'mobilePassphrase'),
      ),
    ).thenAnswer((call) async {
      return switch (call.namedArguments[#mobilePassphrase]) {
        null || '' => Ok(recovery),
        'configured' => Ok(unlocked),
        _ => const Err(BullVaultInvalidRecoveryFailure()),
      };
    });
    final cubit = BullVaultRestoreCubit(restore);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const BullVaultRestoreScreen(),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'public-descriptor');
    await tester.ensureVisible(find.text('Restore from descriptor'));
    await tester.tap(find.text('Restore from descriptor'));
    await tester.pumpAndSettle();
    expect(cubit.state.result, same(recovery));
    expect(find.text('Mobile passphrase (if configured)'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use mobile passphrase'));
    await tester.tap(find.text('Use mobile passphrase'));
    await tester.pumpAndSettle();
    expect(cubit.state.result, same(recovery));
    expect(cubit.state.failure, isA<BullVaultInvalidRecoveryFailure>());
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('Continue'), findsOneWidget);
    final mobileFailureNotice = find.text(
      'Could not restore mobile access. You can still continue with this vault.',
    );
    final noticeFound = mobileFailureNotice.evaluate().isNotEmpty;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(noticeFound, isTrue);
    await tester.enterText(find.byType(TextField), 'configured');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use mobile passphrase'));
    await tester.pumpAndSettle();
    expect(cubit.state.result, same(unlocked));
    expect(cubit.state.failure, isNull);
    expect(find.text('Mobile passphrase (if configured)'), findsNothing);
    final calls = verify(
      () => restore.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: 'public-descriptor',
        label: 'BullVault',
        mobilePassphrase: captureAny(named: 'mobilePassphrase'),
      ),
    ).captured;
    expect(calls, [null, 'wrong', 'configured']);
  });

  testWidgets(
    'only a successful restore announces the actual recovered wallet',
    (tester) async {
      final fixture = testBullVaultCreateResult(walletId: 'recovered');
      final result = BullVaultRestoreResult(
        wallet: fixture.wallet,
        record: fixture.record,
        mobileAccess: .unavailable,
      );
      final restore = _MockRestoreBullVaultUsecase();
      when(
        () => restore.execute(
          kind: BullVaultRestoreInputKind.descriptor,
          source: 'public-descriptor',
          label: 'Family vault',
          mobilePassphrase: null,
        ),
      ).thenAnswer((_) async => Ok(result));
      final cubit = BullVaultRestoreCubit(restore);
      final announced = <BullVaultRestoreResult>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: BullVaultRestoreScreen(onRecovered: announced.add),
            ),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await cubit.close();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      expect(announced, isEmpty);
      await cubit.restore(
        kind: .descriptor,
        source: 'public-descriptor',
        label: 'Family vault',
      );
      await tester.pumpAndSettle();
      expect(announced, [result]);
      expect(find.text('Mobile passphrase (if configured)'), findsNothing);
      when(
        () => restore.execute(
          kind: BullVaultRestoreInputKind.descriptor,
          source: 'bad',
          label: 'Family vault',
          mobilePassphrase: null,
        ),
      ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
      await cubit.restore(
        kind: .descriptor,
        source: 'bad',
        label: 'Family vault',
      );
      await tester.pumpAndSettle();
      expect(announced, [result]);
      final pending =
          Completer<Result<BullVaultRestoreResult, BullVaultFailure>>();
      when(
        () => restore.execute(
          kind: BullVaultRestoreInputKind.descriptor,
          source: 'retry',
          label: 'Family vault',
          mobilePassphrase: null,
        ),
      ).thenAnswer((_) => pending.future);
      final retry = cubit.restore(
        kind: .descriptor,
        source: 'retry',
        label: 'Family vault',
      );
      await tester.pump();
      final duringRetry = announced.length;
      pending.complete(const Err(BullVaultInvalidRecoveryFailure()));
      await retry;
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(duringRetry, 1);
      expect(announced, [result]);
    },
  );
}
