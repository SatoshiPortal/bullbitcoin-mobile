import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_effect.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/save_autobuy_preference_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../autobuy_fixtures.dart';

/// The activate the real machine sends from a loaded context.
ConfirmSend<AutoBuyTarget> _send() {
  var next = (autoBuyFlowStart(
    autoBuySession,
  ).state).next(AutoBuyContextLoaded(1, Ok(autoBuyContext())));
  for (final event in const <AutoBuyFlowEvent>[
    AutoBuyGetStartedPressed(),
    AutoBuyWalletsContinued(autoBuyWallets),
    AutoBuyActivatePressed(),
  ]) {
    next = next.state.next(event);
  }
  return next.effects.whereType<AutoBuyConfirmEffect>().single.effect
      as ConfirmSend<AutoBuyTarget>;
}

Future<ConfirmAnswered<AutoBuyTarget, bool>> _save(
  Result<void, ExchangeFailure> saved, {
  List<String>? written,
}) => SaveAutoBuyPreferenceUsecase(
  exchangeForTesting(
    access: fixedAccessForTesting(const ExchangeAccessSignedIn(autoBuySession)),
    getUserSummary: (_) async => Ok(autoBuySummary()),
    saveUserPreference:
        (
          environment, {
          language,
          currency,
          dcaEnabled,
          autoBuyEnabled,
          emailNotificationsEnabled,
        }) async {
          written?.add('${environment.name} autoBuy=$autoBuyEnabled');
          return saved;
        },
    unknownWrites: InMemoryUnknownWriteJournal(),
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  ),
).execute(autoBuySession, _send());

void main() {
  test('a save that returns normally is verified by re-reading the '
      'account, never read as done', () async {
    final written = <String>[];
    final answer = await _save(const Ok(null), written: written);
    expect(answer.attempt, 1);
    expect(
      answer.answer,
      isA<Err<bool, ExchangeWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteOutcomeUnknownFailure>(),
      ),
    );
    expect(written, ['mainnet autoBuy=true']);
  });

  test('a refused save stays refused', () async {
    final answer = await _save(const Err(ExchangePreferencesSaveFailure()));
    expect(answer.answer, isNot(isA<Ok<bool, ExchangeWriteFailure>>()));
  });
}
