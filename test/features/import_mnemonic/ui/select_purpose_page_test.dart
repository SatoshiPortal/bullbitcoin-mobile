import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/select_purpose_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show ScriptType;

class _MockImportMnemonicCubit extends MockCubit<ImportMnemonicState>
    implements ImportMnemonicCubit {}

void main() {
  late _MockImportMnemonicCubit cubit;
  late AppLocalizations loc;

  setUpAll(() async {
    registerFallbackValue(ScriptType.bip84);
    loc = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    cubit = _MockImportMnemonicCubit();
    when(() => cubit.retryScan(any())).thenAnswer((_) async {});
    when(() => cubit.import()).thenAnswer((_) async {});
  });

  Future<void> host(WidgetTester tester, ImportMnemonicState state) {
    when(() => cubit.state).thenReturn(state);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ImportMnemonicCubit>.value(
          value: cubit,
          child: const SelectScriptTypePage(),
        ),
      ),
    );
  }

  testWidgets(
    'a failed scan shows its reason and a retry, the others their result',
    (tester) async {
      await host(
        tester,
        ImportMnemonicState(
          bip84Scan: const ScriptTypeScan.failed(
            ImportMnemonicScanServerUnavailableFailure(),
          ),
          bip49Scan: ScriptTypeScan.found(
            satoshis: BigInt.from(1500),
            transactions: 4,
          ),
          bip44Scan: const ScriptTypeScan.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(loc.importMnemonicScanServerUnavailable),
        findsOneWidget,
      );
      expect(find.text(loc.importMnemonicBalanceLabel('1500')), findsOneWidget);
      expect(
        find.text(loc.importMnemonicTransactionsLabel('4')),
        findsOneWidget,
      );
      expect(find.text(loc.importMnemonicBalanceLabel('0')), findsOneWidget);
      expect(find.text(loc.retry), findsOneWidget);

      await tester.tap(find.text(loc.retry));
      verify(() => cubit.retryScan(ScriptType.bip84)).called(1);

      // The scan is informational: the import stays available.
      await tester.ensureVisible(find.text(loc.importMnemonicContinue));
      await tester.tap(find.text(loc.importMnemonicContinue));
      verify(() => cubit.import()).called(1);
    },
  );

  testWidgets('an unexpected failure shows the generic message only', (
    tester,
  ) async {
    await host(
      tester,
      const ImportMnemonicState(
        bip84Scan: ScriptTypeScan.failed(
          ImportMnemonicScanUnexpectedFailure('StateError'),
        ),
        bip49Scan: ScriptTypeScan.empty(),
        bip44Scan: ScriptTypeScan.empty(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(loc.importMnemonicScanUnavailable), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });
}
