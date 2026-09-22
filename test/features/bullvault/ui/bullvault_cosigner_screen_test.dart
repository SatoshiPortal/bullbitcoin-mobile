import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_cosigner_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullInputText;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _Import extends Mock implements ImportBullVaultCosignerUsecase {}

Future<void> _mount(
  WidgetTester tester,
  _Import usecase, {
  void Function(bool?)? onResult,
}) async {
  final cubit = BullVaultCosignerCubit(usecase, walletId: 'selected');
  addTearDown(cubit.close);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await context.push<bool>('/import');
              onResult?.call(result);
            },
            child: const Text('Open fixture'),
          ),
        ),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: const BullVaultCosignerScreen(),
        ),
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
  await tester.tap(find.text('Open fixture'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cancelling the warning never displays input or calls import', (
    tester,
  ) async {
    final usecase = _Import();
    await _mount(tester, usecase);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(MnemonicWidget), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open fixture'), findsOneWidget);
    verifyZeroInteractions(usecase);
  });
  testWidgets(
    'matching import returns a refresh result for the selected vault',
    (tester) async {
      final usecase = _Import();
      bool? result;
      when(
        () => usecase.execute(
          walletId: 'selected',
          words: ['fixture'],
          passphrase: 'fixture-passphrase',
        ),
      ).thenAnswer((_) async => Ok(testBullVaultCreateResult().wallet));
      await _mount(tester, usecase, onResult: (value) => result = value);
      await tester.tap(find.text('Continue to key import'));
      await tester.pumpAndSettle();
      final input = tester.widget<MnemonicWidget>(find.byType(MnemonicWidget));
      expect(input.allowLabel, isFalse);
      expect(input.allowPassphrase, isFalse);
      tester
          .widget<BullInputText>(find.byType(BullInputText))
          .onChanged('fixture-passphrase');
      input.onSubmit((
        words: ['fixture'],
        label: '',
        passphrase: '',
        language: bip39.Language.english,
      ));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(MnemonicWidget), findsNothing);
      verify(
        () => usecase.execute(
          walletId: 'selected',
          words: ['fixture'],
          passphrase: 'fixture-passphrase',
        ),
      ).called(1);
    },
  );
  testWidgets('mismatch remains on the input screen with a localized error', (
    tester,
  ) async {
    final usecase = _Import();
    when(
      () => usecase.execute(
        walletId: 'selected',
        words: ['fixture'],
        passphrase: '',
      ),
    ).thenAnswer((_) async => const Err(BullVaultCosignerMismatchFailure()));
    await _mount(tester, usecase);
    await tester.tap(find.text('Continue to key import'));
    await tester.pumpAndSettle();
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: ['fixture'],
      label: '',
      passphrase: '',
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).externalError,
      'These words and passphrase do not match a cosigner in this vault. Nothing was imported.',
    );
    expect(find.byType(BullVaultCosignerScreen), findsOneWidget);
  });
}
