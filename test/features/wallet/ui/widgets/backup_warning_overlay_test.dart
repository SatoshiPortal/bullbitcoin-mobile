import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show ScriptType, SignerEntity;

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

void main() {
  test(
    'unknown readiness falls back to physical backup and respects dismissal',
    () {
      final wallet = Wallet(
        origin: 'default',
        network: Network.bitcoinMainnet,
        isDefault: true,
        xpubFingerprint: '00000000',
        scriptType: ScriptType.bip84,
        xpub: '',
        externalPublicDescriptor: '',
        internalPublicDescriptor: '',
        signer: SignerEntity.local,
        signerDevice: null,
        balanceSat: BigInt.one,
      );
      final fallback = WalletState(wallets: [wallet]);
      expect(fallback.showBackupWarning(), isTrue);
      expect(
        fallback.copyWith(backupNeeded: false).showBackupWarning(),
        isFalse,
      );
      expect(
        fallback.copyWith(backupWarningDismissed: true).showBackupWarning(),
        isFalse,
      );
      expect(
        fallback
            .copyWith(wallets: [wallet.copyWith(isPhysicalBackupTested: true)])
            .showBackupWarning(),
        isFalse,
      );
    },
  );

  testWidgets('backup warning owns accessibility until dismissed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final states = StreamController<WalletState>();
    addTearDown(states.close);
    final bloc = _MockWalletBloc();
    const warning = WalletState(
      backupNeeded: true,
      isSpFeatureEnabled: true,
      isSpWalletSetup: true,
      spBalanceSat: 1,
    );
    whenListen(
      bloc,
      states.stream,
      initialState: warning.copyWith(backupWarningDismissed: true),
    );
    when(() => bloc.add(const DismissBackupWarning())).thenAnswer((_) {
      states.add(warning.copyWith(backupWarningDismissed: true));
    });
    var historyTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WalletBloc>.value(
          value: bloc,
          child: Scaffold(
            body: AppRouter.withBackupWarning(
              Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () => historyTaps++,
                  child: const Text('History'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final history = find.semantics.byLabel('History');
    expect(history, findsOne);
    states.add(warning);
    await tester.pumpAndSettle();
    verify(() => bloc.add(const VerifyBackupStatus())).called(1);

    expect(history, findsNothing);
    await tester.tap(find.text('History'), warnIfMissed: false);
    expect(historyTaps, 0);
    const title = 'BACKUP YOUR WALLET NOW';
    expect(
      tester.getSemantics(find.bySemanticsLabel(title)),
      matchesSemantics(label: title, isHeader: true, namesRoute: true),
    );
    expect(find.bySemanticsLabel('YES'), findsOneWidget);
    expect(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.bySemanticsLabel('NO, I UNDERSTAND THE RISK'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(title), findsNothing);
    expect(history, findsOne);
    await tester.tap(find.bySemanticsLabel('History'));
    expect(historyTaps, 1);
    semantics.dispose();
  });
}
