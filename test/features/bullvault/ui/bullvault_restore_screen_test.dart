import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'dart:async';
import 'package:bull_ui/bull_ui.dart' show BullSecretTextInput;
import 'package:primitives/primitives.dart' show Err, Result;
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
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
    const passphrase = '  café vault  ';
    final restore = _MockRestoreBullVaultUsecase();
    final result =
        Completer<Result<BullVaultRestoreResult, BullVaultFailure>>();
    when(
      () => restore.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: descriptor,
        label: any(named: 'label'),
        mobilePassphrase: passphrase,
      ),
    ).thenAnswer((_) => result.future);
    final cubit = BullVaultRestoreCubit(restore);
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

    final passphraseField = find.descendant(
      of: find.byType(BullSecretTextInput),
      matching: find.byType(TextField),
    );
    await tester.enterText(passphraseField, passphrase);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
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
    final loc = AppLocalizations.of(
      tester.element(find.byType(BullVaultRestoreScreen)),
    );
    await tester.ensureVisible(find.text(loc.bullVaultRestoreDescriptorAction));
    await tester.tap(find.text(loc.bullVaultRestoreDescriptorAction));
    await tester.pump();
    expect(cubit.state.isRestoring, isTrue);
    verify(
      () => restore.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: descriptor,
        label: any(named: 'label'),
        mobilePassphrase: passphrase,
      ),
    ).called(1);
    result.complete(const Err(BullVaultInvalidRecoveryFailure()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
  });
}
