import 'package:bull_exchange/src/funding/domain/fund_state.dart';
import 'package:bull_exchange/src/funding/domain/fund_event.dart';
import 'package:bull_exchange/src/funding/domain/fund_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

typedef _Next = FundFlowNext;

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'a',
);
const _otherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'b',
);

FundingAccount _account({
  String? currency = 'CAD',
  bool restricted = false,
  bool consented = false,
}) => FundingAccount(
  userNumber: 7,
  firstName: 'Ada',
  lastName: 'Lovelace',
  currency: currency == null ? null : ExchangeCatalog.parse(currency),
  restricted: restricted,
  consented: consented,
  confidentialSepa: ConfidentialSepaAvailability.needsVirtualIban,
);

final _acct = _account();
final _restrictedAcct = _account(restricted: true);
final _cleared =
    (restrictionGateStart(restricted: false).state as RestrictionAllowed)
        .cleared;
final _consent =
    (consentGateStart(alreadyGiven: true).state as ConsentGateGiven).given;
final _open = FundOpen(_session, _acct, _cleared);
final _banks = [FundingInstitution.create(code: 'BC01', name: 'Bank')];
final _amount = CopAmount.parse('50000')!;

const _eTransfer = EmailETransferFundingRail();
final _req = ProcessorCodeRequest(_eTransfer, userNumber: 7, consent: _consent);
final _copReq = CopPaymentRequest(
  institution: _banks.first,
  amount: _amount,
  consent: _consent,
);
final _sepaReq = ProcessorCodeRequest(
  const RegularSepaFundingRail(),
  userNumber: 7,
  consent: _consent,
);
const _instructions = FundingInstructionRows([
  InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
]);

final _states = <FundFlowState>[
  const FundLoading(_session, ContextLoading(1)), // 0
  const FundLoading(
    _session,
    ContextFailed(1, ReadProblemUnreachable(isNetwork: true)),
  ), // 1
  FundRestricted(_session, _acct), // 2
  FundPicking(_open, Jurisdiction.canada, null), // 3
  FundPicking(_open, Jurisdiction.canada, _consent), // 4
  FundConsenting(_open, _eTransfer, const ConsentAsking()), // 5
  FundConsenting(_open, _eTransfer, const ConsentSubmitting(1)), // 6
  FundConsenting(
    _open,
    _eTransfer,
    const ConsentFailed(1, WriteProblemNotApplied()),
  ), // 7
  FundInstitutions(_open, _consent, const ContextLoading(1)), // 8
  FundCopInput(_open, _consent, _banks), // 9
  FundVirtualIban(_open, _consent), // 10
  FundFetching(_open, _req, const FundFromPicking(), 1), // 11
  FundShowing(_open, _req, const FundFromPicking(), _instructions), // 12
  FundRefused(
    _open,
    _req,
    const FundFromPicking(),
    FundingRefusal.sinpeNotRegistered,
  ), // 13
  FundFetchFailed(
    _open,
    _req,
    const FundFromPicking(),
    1,
    const ReadProblemMalformed(),
  ), // 14
  const FundSessionEnded(), // 15
  const FundClosed(), // 16
];

final _events = <FundFlowEvent>[
  FundAccountLoaded(1, Ok(_acct)), // 0
  const FundAccountLoaded(
    1,
    Err(ExchangeUnreachableFailure('timeout', isNetwork: true)),
  ), // 1
  const FundAccountLoaded(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 2
  FundAccountLoaded(2, Ok(_acct)), // 3
  const FundRetryPressed(), // 4
  const FundJurisdictionPicked(Jurisdiction.europe), // 5
  const FundRailPicked(_eTransfer), // 6
  const FundRailPicked(CopBankTransferFundingRail()), // 7
  const FundConsentAccepted(), // 8
  const FundConsentSubmitted(1, Ok(null)), // 9
  const FundConsentVerified(1, Ok(true)), // 10
  FundInstitutionsLoaded(1, Ok(_banks)), // 11
  const FundInstitutionsLoaded(1, Ok([])), // 12
  FundCopSubmitted(_banks.first, _amount), // 13
  const FundRegularSepaChosen(), // 14
  FundInstructionsLoaded(
    1,
    _req,
    const Ok(FundingInstructionsGot(_instructions)),
  ), // 15
  FundInstructionsLoaded(
    1,
    _req,
    const Ok(FundingRefused(FundingRefusal.sinpeNotRegistered)),
  ), // 16
  FundInstructionsLoaded(
    1,
    _req,
    const Err(ExchangeMalformedFailure('missing iban')),
  ), // 17
  FundInstructionsLoaded(
    1,
    _copReq,
    const Ok(FundingInstructionsGot(_instructions)),
  ), // 18
  FundInstructionsLoaded(
    1,
    _req,
    const Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 19
  const FundBackPressed(), // 20
  const FundDonePressed(), // 21
  const FundSessionChanged(_session), // 22
  const FundSessionChanged(_otherSession), // 23
  const FundSessionChanged(null), // 24
  FundAccountLoaded(1, Ok(_restrictedAcct)), // 25
  const FundRailPicked(ConfidentialSepaFundingRail()), // 26
  const FundJurisdictionPicked(Jurisdiction.colombia), // 27
];

const _ended = _Next(FundSessionEnded());
const _closed = _Next(FundClosed());
const _sessionGone = {23: _ended, 24: _ended};

_Next _picking(Jurisdiction jurisdiction, ConsentGiven? consent) =>
    _Next(FundPicking(_open, jurisdiction, consent));

_Next _fetching(FundingRequest request, FundOrigin origin, [int attempt = 1]) =>
    _Next(FundFetching(_open, request, origin, attempt), [
      FundFetchInstructions(attempt, request),
    ]);

/// The transitions; every pair not listed is a stay.
final _table = <int, Map<int, _Next>>{
  0: {
    0: _picking(Jurisdiction.canada, null),
    1: const _Next(
      FundLoading(
        _session,
        ContextFailed(1, ReadProblemUnreachable(isNetwork: true)),
      ),
    ),
    2: _ended,
    20: _closed,
    25: _Next(FundRestricted(_session, _restrictedAcct)),
    ..._sessionGone,
  },
  1: {
    4: const _Next(FundLoading(_session, ContextLoading(2)), [
      FundLoadAccount(2),
    ]),
    20: _closed,
    ..._sessionGone,
  },
  2: {20: _closed, 21: _closed, ..._sessionGone},
  3: {
    5: _picking(Jurisdiction.europe, null),
    6: _Next(FundConsenting(_open, _eTransfer, const ConsentAsking())),
    20: _closed,
    27: _picking(Jurisdiction.colombia, null),
    ..._sessionGone,
  },
  4: {
    5: _picking(Jurisdiction.europe, _consent),
    6: _fetching(_req, const FundFromPicking()),
    20: _closed,
    27: _picking(Jurisdiction.colombia, _consent),
    ..._sessionGone,
  },
  5: {
    8: _Next(FundConsenting(_open, _eTransfer, const ConsentSubmitting(1)), [
      const FundSubmitConsent(1),
    ]),
    20: _picking(Jurisdiction.canada, null),
    ..._sessionGone,
  },
  6: {9: _fetching(_req, const FundFromPicking()), ..._sessionGone},
  7: {
    4: _Next(FundConsenting(_open, _eTransfer, const ConsentSubmitting(2)), [
      const FundSubmitConsent(2),
    ]),
    20: _picking(Jurisdiction.canada, null),
    ..._sessionGone,
  },
  8: {
    11: _Next(FundCopInput(_open, _consent, _banks)),
    12: _Next(
      FundInstitutions(
        _open,
        _consent,
        const ContextFailed(1, ReadProblemMissing()),
      ),
    ),
    20: _picking(Jurisdiction.colombia, _consent),
    ..._sessionGone,
  },
  9: {
    13: _fetching(_copReq, FundFromCopInput(_banks)),
    20: _picking(Jurisdiction.colombia, _consent),
    ..._sessionGone,
  },
  10: {
    14: _fetching(_sepaReq, const FundFromVirtualIban()),
    20: _picking(Jurisdiction.europe, _consent),
    21: _closed,
    ..._sessionGone,
  },
  11: {
    15: _Next(FundShowing(_open, _req, const FundFromPicking(), _instructions)),
    16: _Next(
      FundRefused(
        _open,
        _req,
        const FundFromPicking(),
        FundingRefusal.sinpeNotRegistered,
      ),
    ),
    17: _Next(
      FundFetchFailed(
        _open,
        _req,
        const FundFromPicking(),
        1,
        const ReadProblemMalformed(),
      ),
    ),
    19: _ended,
    20: _picking(Jurisdiction.canada, _consent),
    ..._sessionGone,
  },
  12: {
    20: _picking(Jurisdiction.canada, _consent),
    21: _closed,
    ..._sessionGone,
  },
  13: {20: _picking(Jurisdiction.canada, _consent), ..._sessionGone},
  14: {
    4: _fetching(_req, const FundFromPicking(), 2),
    20: _picking(Jurisdiction.canada, _consent),
    ..._sessionGone,
  },
  15: {20: _closed, 21: _closed},
  16: {},
};

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, List.generate(_states.length, (i) => i));
  });

  for (final (s, state) in _states.indexed) {
    for (final (e, event) in _events.indexed) {
      test('#$s $state + #$e ${event.runtimeType}', () {
        final next = state.next(event);
        final expected = _table[s]![e];
        if (expected == null) {
          expect(identical(next.state, state), isTrue, reason: '$next');
          expect(next.effects, isEmpty);
        } else {
          expect(next, expected);
        }
      });
    }
  }

  test('every state is reachable', () {
    // Walk states, not types: the first state of a type found is not always
    // the one the events lead on from (attempt ids, chosen rails).
    final seen = <FundFlowState>{fundFlowStart(_session).state};
    var frontier = seen.toList();
    for (var depth = 0; frontier.isNotEmpty && depth < 12; depth++) {
      final next = <FundFlowState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = state.next(event).state;
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(
      {for (final state in seen) state.runtimeType},
      {for (final state in _states) state.runtimeType},
    );
  });

  group('behaviour', () {
    test('without a session the flow has ended', () {
      expect(fundFlowStart(null), _ended);
      expect(
        fundFlowStart(_session),
        const _Next(FundLoading(_session, ContextLoading(1)), [
          FundLoadAccount(1),
        ]),
      );
    });

    test('consent already on the account opens the rail without the sheet', () {
      final open = FundOpen(_session, _account(consented: true), _cleared);
      final next = FundPicking(
        open,
        Jurisdiction.canada,
        null,
      ).next(const FundRailPicked(_eTransfer));
      expect(next.state, isA<FundFetching>());
    });

    test('Confidential SEPA asks for consent too (FUND-4)', () {
      final next = FundPicking(
        _open,
        Jurisdiction.europe,
        null,
      ).next(const FundRailPicked(ConfidentialSepaFundingRail()));
      expect(
        next.state,
        FundConsenting(
          _open,
          const ConfidentialSepaFundingRail(),
          const ConsentAsking(),
        ),
      );
    });

    test('an account it cannot use offers no Confidential SEPA tile', () {
      final open = FundOpen(
        _session,
        FundingAccount(
          userNumber: 7,
          firstName: 'Ada',
          lastName: 'Lovelace',
          currency: ExchangeCatalog.parse('EUR'),
          restricted: false,
          consented: true,
          confidentialSepa: ConfidentialSepaAvailability.unavailable,
        ),
        _cleared,
      );
      expect(FundPicking(open, Jurisdiction.europe, null).rails, const [
        InstantSepaFundingRail(),
        RegularSepaFundingRail(),
      ]);
    });

    test(
      'USD opens on Costa Rica; an unknown currency on nothing (D1, D3)',
      () {
        expect(_account(currency: 'USD').jurisdiction, Jurisdiction.costaRica);
        expect(_account(currency: 'JPY').jurisdiction, isNull);
        expect(_account(currency: null).jurisdiction, isNull);
        final unknown = FundOpen(_session, _account(currency: 'JPY'), _cleared);
        final picking = FundPicking(unknown, null, null);
        expect(picking.rails, isEmpty);
        expect(
          identical(
            picking.next(const FundRailPicked(_eTransfer)).state,
            picking,
          ),
          isTrue,
        );
      },
    );

    test('a late answer for an earlier rail is ignored (FUND-5)', () {
      final back = FundFetching(
        _open,
        _req,
        const FundFromPicking(),
        1,
      ).next(const FundBackPressed()).state;
      final wire = back.next(const FundRailPicked(BankWireFundingRail())).state;
      expect(wire, isA<FundFetching>());
      final late = wire.next(
        FundInstructionsLoaded(
          1,
          _req,
          const Ok(FundingInstructionsGot(_instructions)),
        ),
      );
      expect(identical(late.state, wire), isTrue);
    });

    test('the consent sheet cannot be left while the consent is sent', () {
      final submitting = _states[6];
      expect(
        identical(submitting.next(const FundBackPressed()).state, submitting),
        isTrue,
      );
    });

    test('an unknown consent outcome re-reads, never re-sends', () {
      final next = (_states[6]).next(
        const FundConsentSubmitted(
          1,
          Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
        ),
      );
      expect(
        next,
        _Next(FundConsenting(_open, _eTransfer, const ConsentVerifying(1)), [
          const FundVerifyConsent(1),
        ]),
      );
    });
  });
}
