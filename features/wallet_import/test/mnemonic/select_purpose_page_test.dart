import 'package:wallet_import/src/presentation/mnemonic/cubit.dart';
import 'package:wallet_import/src/presentation/mnemonic/state.dart';
import 'package:wallet_import/src/ui/mnemonic/select_purpose_page.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bull_ui/app_theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockImportMnemonicCubit extends MockCubit<ImportMnemonicState>
    implements ImportMnemonicCubit {}

void main() {
  late _MockImportMnemonicCubit cubit;
  late ImportLocalizations loc;
  late ImportLocalizations importLoc;

  setUpAll(() async {
    registerFallbackValue(ScriptType.bip84);
    loc = await ImportLocalizations.delegate.load(const Locale('en'));
    importLoc = await ImportLocalizations.delegate.load(const Locale('en'));
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
        localizationsDelegates: ImportLocalizations.localizationsDelegates,
        supportedLocales: ImportLocalizations.supportedLocales,
        home: BlocProvider<ImportMnemonicCubit>.value(
          value: cubit,
          child: SelectScriptTypePage(onExit: (_) {}),
        ),
      ),
    );
  }

  testWidgets('unsupported script is not offered as an importable wallet', (
    tester,
  ) async {
    await host(
      tester,
      const ImportMnemonicState(
        bip84Scan: ScriptTypeScan.empty(),
        bip49Scan: ScriptTypeScan.empty(),
        bip44Scan: ScriptTypeScan.failed(
          ImportMnemonicScanUnsupportedFailure(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(importLoc.importMnemonicUnsupportedScript),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text(loc.importMnemonicLegacy));
    await tester.tap(find.text(loc.importMnemonicLegacy), warnIfMissed: false);
    verifyNever(() => cubit.updateBip39Purpose(ScriptType.bip44));
    expect(find.text(loc.retry), findsNothing);
  });

  testWidgets('an unsupported selected script cannot continue to import', (
    tester,
  ) async {
    await host(
      tester,
      const ImportMnemonicState(
        scriptType: ScriptType.bip44,
        bip84Scan: ScriptTypeScan.empty(),
        bip49Scan: ScriptTypeScan.empty(),
        bip44Scan: ScriptTypeScan.failed(
          ImportMnemonicScanUnsupportedFailure(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(loc.importMnemonicContinue));
    await tester.tap(find.text(loc.importMnemonicContinue));
    verifyNever(() => cubit.import());
  });

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
        find.text(importLoc.importMnemonicScanServerUnavailable),
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

    expect(find.text(importLoc.importMnemonicScanUnavailable), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });
}
