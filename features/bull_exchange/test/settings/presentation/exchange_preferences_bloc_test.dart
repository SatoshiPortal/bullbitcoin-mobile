import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/exchange_preferences_machine.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_preferences_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../settings_usecase_fakes.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);
const _a = ExchangePreferences(
  language: 'EN',
  currency: 'CAD',
  emailNotificationsEnabled: true,
);
const _b = ExchangePreferences(
  language: 'FR',
  currency: 'CAD',
  emailNotificationsEnabled: true,
);

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ExchangePreferencesBloc _bloc(
  List<String> calls, {
  ExchangeSession? session = _session,
  GatedWrite<Result<void, ExchangeSettingsFailure>>? saved,
}) {
  final bloc = ExchangePreferencesBloc(
    session: session,
    getPreferences: FakeGetExchangePreferencesUsecase(() async {
      calls.add('get');
      return const Ok(_a);
    }),
    updatePreferences: FakeUpdateExchangePreferencesUsecase((
      session, {
      required loaded,
      required edited,
    }) async {
      calls.add(
        'update ${session?.sessionId} ${loaded.language}->${edited.language}',
      );
      if (saved == null) throw StateError('update was not expected');
      return saved;
    }),
  );
  addTearDown(bloc.close);
  return bloc;
}

void main() {
  test('the save is sent for the session the screen opened for', () async {
    final calls = <String>[];
    final bloc = _bloc(calls, saved: const GateAdmitted(Ok(null)));
    await _settle();
    bloc
      ..add(const PreferencesLanguageChosen('FR'))
      ..add(const PreferencesSavePressed());
    await _settle();
    expect(calls, ['get', 'update s EN->FR']);
    expect(bloc.state, isNot(isA<PreferencesSaving>()));
  });

  test('a save the gate refuses is shown as busy', () async {
    final calls = <String>[];
    final bloc = _bloc(
      calls,
      saved: const GateRefused(WriteGateBusy(FinancialWriteKind.orderConfirm)),
    );
    await _settle();
    bloc
      ..add(const PreferencesLanguageChosen('FR'))
      ..add(const PreferencesSavePressed());
    await _settle();
    expect(
      bloc.state,
      const PreferencesSaveFailed(_a, _b, ExchangeSettingsWriteBusyFailure()),
    );
  });

  test('without a session nothing is read', () async {
    final calls = <String>[];
    final bloc = _bloc(calls, session: null);
    await _settle();
    expect(bloc.state, const PreferencesSignedOut());
    expect(calls, isEmpty);
  });
}
