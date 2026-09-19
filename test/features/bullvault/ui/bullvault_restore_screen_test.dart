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
