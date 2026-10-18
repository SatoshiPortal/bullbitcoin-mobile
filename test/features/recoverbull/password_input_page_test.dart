import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/vault_attempts.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecoverBullBloc extends Fake implements RecoverBullBloc {
  @override
  final RecoverBullState state;
  final StreamController<RecoverBullState> _states =
      StreamController<RecoverBullState>.broadcast();

  _FakeRecoverBullBloc(this.state);

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  @override
  void add(RecoverBullEvent event) {}

  @override
  Future<void> close() => _states.close();
}

Future<void> _pumpPage(WidgetTester tester, RecoverBullState state) async {
  // The dial pad and the card need a phone-sized surface.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final bloc = _FakeRecoverBullBloc(state);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<RecoverBullBloc>.value(
        value: bloc,
        child: const PasswordInputPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final warning = find.textContaining(
    'received 3 wrong PIN or password attempts',
    findRichText: true,
  );

  testWidgets('shows the attempts the server saw on the opened vault', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.testVault,
        vaultAttempts: VaultAttempts(failedAttempts: 3),
      ),
    );

    expect(warning, findsOneWidget);
  });

  testWidgets('stays silent while the snapshot is unknown or clean', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        vaultAttempts: VaultAttempts.none(),
      ),
    );

    expect(
      find.textContaining('wrong PIN or password', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('never warns while creating a vault', (tester) async {
    await _pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.secureVault,
        vaultAttempts: VaultAttempts(failedAttempts: 3),
      ),
    );

    expect(warning, findsNothing);
  });
}
