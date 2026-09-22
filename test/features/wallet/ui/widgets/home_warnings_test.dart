import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

const _serverDown = WalletWarning(
  reason: ElectrumServerDown.bitcoin,
  action: WalletWarningAction.electrumSettings,
  type: WarningType.error,
);

Future<void> _pump(WidgetTester tester, WalletState state) async {
  final bloc = _MockWalletBloc();
  whenListen(bloc, const Stream<WalletState>.empty(), initialState: state);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<WalletBloc>.value(
          value: bloc,
          child: const HomeWarnings(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a sync failure reads as stale balances, not a failed load', (
    tester,
  ) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.success,
        failure: WalletSyncFailure('sync: timeout'),
      ),
    );

    expect(find.textContaining('may be out of date'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('a sync failure is not stacked on top of a server warning', (
    tester,
  ) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.success,
        failure: WalletSyncFailure('sync: timeout'),
        warnings: [_serverDown],
      ),
    );

    // The server warning already explains the outage, with its own remedy.
    expect(find.textContaining('may be out of date'), findsNothing);
    expect(find.textContaining('Bitcoin'), findsWidgets);
  });

  testWidgets('a failed load is still reported', (tester) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.failure,
        failure: WalletStorageFailure('read failed'),
      ),
    );

    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });
}
