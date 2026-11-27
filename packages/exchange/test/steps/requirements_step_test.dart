import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

typedef _Next = StepNext<RequirementsState, RequirementsEffect>;

const _policy = RequirementsPolicy();

Recipient _recipient(RecipientDetails details) => Recipient.create(
  recipientId: 'r-1',
  userId: 'u-1',
  userNbr: 1,
  isArchived: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  details: details,
);

final _anyRail = RecipientFilter(rails: PayoutRails.all);

ChosenRecipient _choose(RecipientDetails details) =>
    _anyRail.choose(_recipient(details))!;

final _sepaDetails = SepaEurDetails.create(
  iban: 'FR76',
  isCorporate: false,
  firstname: 'Ana',
  lastname: 'Silva',
  isOwner: true,
);
final _sepa = _choose(_sepaDetails);
final _confidential = _choose(_sepaDetails.asConfidential());
final _interac = _choose(
  InteracEmailCadDetails.create(
    email: 'a@b.ca',
    name: 'Ann',
    securityQuestion: 'Pet?',
    securityAnswer: 'rex',
  ),
);
final _active = VirtualIban.fromBankDetails(
  iban: 'DE89',
  bicCode: 'FRBKDE',
  bankAddress: 'Berlin',
) as ActiveVirtualIban;

const _continue = RequirementInteracEvent(InteracContinuePressed());
final _ibanActive = RequirementVirtualIbanEvent(
  VibanLoaded(
    1,
    Ok(VirtualIbanContext(virtualIban: _active, ownerName: 'Ana')),
  ),
);
const _payeeActive = RequirementVirtualPayeeEvent(
  PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.active)),
);
const _cancel = RequirementsCancelPressed();

RequirementsNext _step(RequirementsState state, RequirementsEvent event) =>
    state.next(_policy, event);

RequirementsState _run(
  RequirementsState state,
  List<RequirementsEvent> events,
) {
  var current = state;
  for (final event in events) {
    current = _step(current, event).state;
  }
  return current;
}

void main() {
  test('a rail without requirements is ready at once, no screen', () {
    final next = requirementsStart(_policy, _sepa, PayoutPurpose.sell);
    final ready = (next.state as RequirementsReady).ready;
    expect(next.effects, isEmpty);
    expect(ready.chosen, _sepa);
    expect(
      ready.orderParams,
      const OrderPayoutParams(
        recipientId: 'r-1',
        paymentProcessor: SepaPaymentProcessor.regular,
      ),
    );
  });

  for (final purpose in PayoutPurpose.values) {
    test('Interac asks the answer, then sends it on $purpose', () {
      final start = requirementsStart(_policy, _interac, purpose);
      expect(
        (start.state as RequirementsRunning).current,
        const InteracStep(
          InteracEditing(question: 'Pet?', answer: 'rex', saveAsDefault: true),
        ),
      );
      final state = _run(start.state, [_continue]);
      final ready = (state as RequirementsReady).ready;
      final params = ready.orderParams;
      expect(params.paymentProcessor, isNull);
      expect(params.interacAnswer?.question, 'Pet?');
      expect(params.interacAnswer?.answer, 'rex');
      expect(ready.interac?.saveAsDefault, isTrue);
    });
  }

  test('Confidential SEPA meets the virtual IBAN, then the payee', () {
    final start = requirementsStart(
      _policy,
      _confidential,
      PayoutPurpose.withdraw,
    );
    expect(start.effects, const [RequirementVirtualIbanEffect(VibanLoad(1))]);
    final afterIban = _step(start.state, _ibanActive);
    expect(
      (afterIban.state as RequirementsRunning).current,
      const VirtualPayeeStep(PayeeLoading(1)),
    );
    expect(afterIban.effects, const [
      RequirementVirtualPayeeEffect('r-1', PayeeLoad(1)),
    ]);
    final ready =
        (_step(afterIban.state, _payeeActive).state as RequirementsReady).ready;
    expect(ready.evidence, [VirtualIbanMet(_active), const VirtualPayeeMet()]);
    expect(
      ready.orderParams.paymentProcessor,
      SepaPaymentProcessor.confidential,
    );
  });

  test('a payee the list shows active is passed without a screen', () {
    final activePayee = _choose(
      SepaEurDetails.create(
        iban: 'FR76',
        isCorporate: false,
        firstname: 'Ana',
        lastname: 'Silva',
        virtualPayeeStatus: SepaVirtualPayeeStatus.active,
      ).asConfidential(),
    );
    final start = requirementsStart(
      _policy,
      activePayee,
      PayoutPurpose.withdraw,
    );
    final next = _step(start.state, _ibanActive);
    expect(next.state, isA<RequirementsReady>());
    expect(next.effects, isEmpty);
  });

  test('declining the virtual IBAN falls back to regular SEPA', () {
    final start = requirementsStart(_policy, _confidential, PayoutPurpose.sell);
    final intro = _step(
      start.state,
      const RequirementVirtualIbanEvent(
        VibanLoaded(
          1,
          Ok(VirtualIbanContext(virtualIban: null, ownerName: 'Ana')),
        ),
      ),
    ).state;
    final next = _step(
      intro,
      const RequirementVirtualIbanEvent(VibanDeclinePressed()),
    );
    final ready = (next.state as RequirementsReady).ready;
    expect(ready.rail, PayoutRails.sepa);
    expect(ready.orderParams.paymentProcessor, SepaPaymentProcessor.regular);
  });

  test('a rejected session ends the step', () {
    final start = requirementsStart(_policy, _confidential, PayoutPurpose.sell);
    final next = _step(
      start.state,
      const RequirementVirtualIbanEvent(
        VibanLoaded(
          1,
          Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
        ),
      ),
    );
    expect(next.state, const RequirementsSessionEnded());
  });

  test('leaving while the payee is polled stops the watch', () {
    final start = requirementsStart(_policy, _confidential, PayoutPurpose.sell);
    final pending = _run(start.state, [
      _ibanActive,
      const RequirementVirtualPayeeEvent(
        PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.pending)),
      ),
    ]);
    expect((pending as RequirementsRunning).current, isA<VirtualPayeeStep>());
    expect(
      _step(pending, _cancel),
      const _Next(RequirementsCancelled(), [
        RequirementVirtualPayeeEffect('r-1', PayeeStopWatching()),
      ]),
    );
  });

  group('every (state, event) pair', () {
    final interacRunning = requirementsStart(
      _policy,
      _interac,
      PayoutPurpose.pay,
    ).state;
    final ibanRunning = requirementsStart(
      _policy,
      _confidential,
      PayoutPurpose.withdraw,
    ).state;
    final payeeRunning = _step(ibanRunning, _ibanActive).state;
    final ready = requirementsStart(_policy, _sepa, PayoutPurpose.sell).state;
    const cancelled = RequirementsCancelled();
    const ended = RequirementsSessionEnded();

    final states = <String, RequirementsState>{
      'interac': interacRunning,
      'iban': ibanRunning,
      'payee': payeeRunning,
      'ready': ready,
      'cancelled': cancelled,
      'ended': ended,
    };
    final events = <String, RequirementsEvent>{
      'interac': _continue,
      'iban': _ibanActive,
      'payee': _payeeActive,
      'cancel': _cancel,
    };
    // The pairs that move; every other pair is a stay.
    final moves = <(String, String), Type>{
      ('interac', 'interac'): RequirementsReady,
      ('interac', 'cancel'): RequirementsCancelled,
      ('iban', 'iban'): RequirementsRunning,
      ('iban', 'cancel'): RequirementsCancelled,
      ('payee', 'payee'): RequirementsReady,
      ('payee', 'cancel'): RequirementsCancelled,
    };

    for (final MapEntry(key: stateName, value: state) in states.entries) {
      for (final MapEntry(key: eventName, value: event) in events.entries) {
        test('$stateName + $eventName', () {
          final next = _step(state, event);
          final moved = moves[(stateName, eventName)];
          if (moved == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next.state.runtimeType, moved);
          }
        });
      }
    }

    test('every state is reachable', () {
      expect(
        {
          interacRunning.runtimeType,
          ready.runtimeType,
          _step(interacRunning, _cancel).state.runtimeType,
          _step(
            ibanRunning,
            const RequirementVirtualIbanEvent(
              VibanLoaded(
                1,
                Err(
                  ExchangeSessionRejectedFailure(
                    ExchangeSessionRejection.server,
                  ),
                ),
              ),
            ),
          ).state.runtimeType,
        },
        {
          RequirementsRunning,
          RequirementsReady,
          RequirementsCancelled,
          RequirementsSessionEnded,
        },
      );
    });
  });
}
