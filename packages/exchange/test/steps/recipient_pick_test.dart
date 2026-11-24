import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<RecipientPickState, RecipientPickEffect>;

Recipient _recipient(String id, RecipientDetails details) => Recipient.create(
  recipientId: id,
  userId: 'u-1',
  userNbr: 1,
  isArchived: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  details: details,
);

final _filter = RecipientFilter(
  rails: [PayoutRails.interacEmail, PayoutRails.sepa],
  owner: RecipientOwnership.own,
);
final _query = RecipientQuery(rails: _filter.rails);
final _interacOnly = RecipientQuery(rails: [PayoutRails.interacEmail]);

final _ann = _recipient(
  'r-1',
  InteracEmailCadDetails.create(email: 'a@b.ca', name: 'Ann', isOwner: true),
);
final _theirs = _recipient(
  'r-2',
  InteracEmailCadDetails.create(email: 'c@d.ca', name: 'Cy', isOwner: false),
);
final _newDetails = InteracEmailCadDetails.create(
  email: 'e@f.ca',
  name: 'Eve',
  isOwner: true,
);
final _saved = _recipient('r-3', _newDetails);
const _input = RecipientDetailsInput(
  recipientType: RecipientType.interacEmailCad,
  email: 'e@f.ca',
  name: 'Eve',
  isOwner: false,
);
const _badInput = RecipientDetailsInput(
  recipientType: RecipientType.interacEmailCad,
  email: 'e@f.ca',
);
const _otherRailInput = RecipientDetailsInput(
  recipientType: RecipientType.billPaymentCad,
);
const _refusal = ExchangeRefusal(rpcCode: -32000);
const _unreachable = ReadProblemUnreachable(isNetwork: true);

final _loading = RecipientPickLoading(_query, 1);
final _loadFailed = RecipientPickLoadFailed(_query, 1, _unreachable);
final _browsing = RecipientPickBrowsing(_query, 1, [_ann, _theirs], 2);
final _browsingLast = RecipientPickBrowsing(_query, 1, [_ann], null);
final _loadingMore = RecipientPickLoadingMore(_query, 2, [_ann], 2);
final _moreFailed = RecipientPickMoreFailed(_query, 2, [_ann], 2, _unreachable);
final _creating = RecipientPickCreating(_query, 1, PayoutRails.interacEmail);
final _saving = RecipientPickSaving(
  _query,
  2,
  PayoutRails.interacEmail,
  _newDetails,
);
final _verifying = RecipientPickVerifying(
  _query,
  3,
  PayoutRails.interacEmail,
  _newDetails,
);
final _unverified = RecipientPickUnverified(
  _query,
  3,
  PayoutRails.interacEmail,
  _newDetails,
  _unreachable,
);
final _picked = RecipientPickPicked(
  _query,
  1,
  _filter.choose(_ann)!,
  isNew: false,
);
final _notAdmitted = RecipientPickNotAdmitted(_query, 2, _theirs);
final _ended = RecipientPickSessionEnded(_query, 1);

final _states = <RecipientPickState>[
  _loading,
  _loadFailed,
  _browsing,
  _browsingLast,
  _loadingMore,
  _moreFailed,
  _creating,
  _saving,
  _verifying,
  _unverified,
  _picked,
  _notAdmitted,
  _ended,
];

final _events = <RecipientPickEvent>[
  RecipientPickPageLoaded(1, ListPage([_ann], next: 2)), // 0
  const RecipientPickPageLoaded(1, ListUnreachable('down', isNetwork: true)),
  const RecipientPickPageLoaded(
    1,
    ListSessionRejected(ExchangeSessionRejection.server),
  ), // 2
  RecipientPickPageLoaded(2, ListPage([_theirs])), // 3
  const RecipientPickPageLoaded(2, ListUnreachable('down', isNetwork: true)),
  RecipientPickQueryChanged(_interacOnly), // 5
  const RecipientPickMoreRequested(), // 6
  const RecipientPickRetryPressed(), // 7
  RecipientPickSelected(_ann), // 8
  RecipientPickSelected(_theirs), // 9
  const RecipientPickNewPressed(PayoutRails.sepa), // 10
  const RecipientPickNewPressed(PayoutRails.pse), // 11
  const RecipientPickSubmitted(_input), // 12
  const RecipientPickSubmitted(_badInput), // 13
  const RecipientPickSubmitted(_otherRailInput), // 14
  RecipientPickSaved(2, WriteDone(_saved)), // 15
  const RecipientPickSaved(2, WriteRefused(_refusal)), // 16
  const RecipientPickSaved(2, WriteOutcomeUnknown('timeout')), // 17
  const RecipientPickSaved(2, WriteSessionRejected()), // 18
  RecipientPickFound(3, ReadGot(_saved)), // 19
  const RecipientPickFound(3, ReadMissing()), // 20
  const RecipientPickFound(3, ReadUnreachable('down', isNetwork: true)), // 21
  const RecipientPickBackPressed(), // 22
];

_Next _load(int attempt, {RecipientQuery? query}) => _Next(
  RecipientPickLoading(query ?? _query, attempt),
  [RecipientPickFetchPage(query ?? _query, RecipientOwnership.own, 1, attempt)],
);

_Next _requery(int attempt) => _load(attempt, query: _interacOnly);

final _newSepa = _Next(RecipientPickCreating(_query, 1, PayoutRails.sepa));

Map<int, _Next> _listCommon(RecipientPickState state) => {
  5: _requery(state.attempt + 1),
  10: _Next(RecipientPickCreating(_query, state.attempt, PayoutRails.sepa)),
};

final _table = <RecipientPickState, Map<int, _Next>>{
  _loading: {
    0: _Next(RecipientPickBrowsing(_query, 1, [_ann], 2)),
    1: _Next(_loadFailed),
    2: _Next(_ended),
    ..._listCommon(_loading),
  },
  _loadFailed: {7: _load(2), ..._listCommon(_loadFailed)},
  _browsing: {
    6: _Next(RecipientPickLoadingMore(_query, 2, [_ann, _theirs], 2), [
      RecipientPickFetchPage(_query, RecipientOwnership.own, 2, 2),
    ]),
    7: _load(2),
    8: _Next(_picked),
    ..._listCommon(_browsing),
  },
  _browsingLast: {
    7: _load(2),
    8: _Next(_picked),
    ..._listCommon(_browsingLast),
  },
  _loadingMore: {
    3: _Next(RecipientPickBrowsing(_query, 2, [_ann, _theirs], null)),
    4: _Next(_moreFailed),
    8: _Next(
      RecipientPickPicked(_query, 2, _filter.choose(_ann)!, isNew: false),
    ),
    ..._listCommon(_loadingMore),
  },
  _moreFailed: {
    6: _Next(RecipientPickLoadingMore(_query, 3, [_ann], 2), [
      RecipientPickFetchPage(_query, RecipientOwnership.own, 2, 3),
    ]),
    7: _Next(RecipientPickLoadingMore(_query, 3, [_ann], 2), [
      RecipientPickFetchPage(_query, RecipientOwnership.own, 2, 3),
    ]),
    8: _Next(
      RecipientPickPicked(_query, 2, _filter.choose(_ann)!, isNew: false),
    ),
    ..._listCommon(_moreFailed),
  },
  _creating: {
    10: _newSepa,
    13: _Next(
      RecipientPickCreating(
        _query,
        1,
        PayoutRails.interacEmail,
        const RecipientInputInvalid(),
      ),
    ),
    22: _load(2),
  },
  _saving: {
    15: _Next(
      RecipientPickPicked(_query, 2, _filter.choose(_saved)!, isNew: true),
    ),
    16: _Next(
      RecipientPickCreating(
        _query,
        2,
        PayoutRails.interacEmail,
        const RecipientSaveFailed(WriteProblemRefused(_refusal)),
      ),
    ),
    17: _Next(_verifying, [RecipientPickFind(_newDetails, 3)]),
    18: _Next(RecipientPickSessionEnded(_query, 2)),
  },
  _verifying: {
    19: _Next(
      RecipientPickPicked(_query, 3, _filter.choose(_saved)!, isNew: true),
    ),
    20: _Next(
      RecipientPickCreating(
        _query,
        3,
        PayoutRails.interacEmail,
        const RecipientSaveFailed(WriteProblemNotApplied()),
      ),
    ),
    21: _Next(_unverified),
  },
  _unverified: {
    7: _Next(
      RecipientPickVerifying(_query, 4, PayoutRails.interacEmail, _newDetails),
      [RecipientPickFind(_newDetails, 4)],
    ),
    22: _load(4),
  },
  _picked: {22: _load(2)},
  _notAdmitted: {22: _load(3)},
  _ended: {},
};

RecipientPickNext _step(RecipientPickState state, RecipientPickEvent event) =>
    transitionRecipientPick(_filter, state, event);

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = _step(state, event);
        final expected = _table[state]![index];
        if (expected == null) {
          expect(identical(next.state, state), isTrue, reason: '$next');
          expect(next.effects, isEmpty);
        } else if (index == 12 && state == _creating) {
          // The save sends new details: checked below.
          expect(next.state, isA<RecipientPickSaving>());
        } else {
          expect(next, expected);
        }
      });
    }
  }

  test('a new recipient is saved with the filter owner (RCP-9)', () {
    final next = _step(_creating, const RecipientPickSubmitted(_input));
    final saving = next.state as RecipientPickSaving;
    expect(saving.attempt, 2);
    expect(saving.details, isA<InteracEmailCadDetails>());
    expect(saving.details.isOwner, isTrue);
    expect(next.effects.single, isA<RecipientPickSave>());
  });

  test('a filter without owner keeps the form owner', () {
    final any = RecipientFilter(rails: [PayoutRails.interacEmail]);
    final next = transitionRecipientPick(
      any,
      RecipientPickCreating(
        RecipientQuery(rails: any.rails),
        1,
        PayoutRails.interacEmail,
      ),
      const RecipientPickSubmitted(_input),
    );
    expect((next.state as RecipientPickSaving).details.isOwner, isFalse);
  });

  test('a query is kept to the filter rails', () {
    final next = _step(
      _browsing,
      RecipientPickQueryChanged(
        RecipientQuery(rails: [PayoutRails.pse, PayoutRails.sepa], search: 'x'),
      ),
    );
    expect(
      next.state.query,
      RecipientQuery(rails: [PayoutRails.sepa], search: 'x'),
    );
  });

  test('a saved Confidential SEPA recipient is picked on its rail', () {
    final filter = RecipientFilter(
      rails: [PayoutRails.confidentialSepa],
      owner: RecipientOwnership.own,
    );
    final savedSepa = _recipient(
      'r-9',
      SepaEurDetails.create(
        iban: 'FR76',
        isCorporate: false,
        firstname: 'Ana',
        lastname: 'Silva',
        isOwner: true,
      ),
    );
    final details = SepaEurDetails.create(
      iban: 'FR76',
      isCorporate: false,
      firstname: 'Ana',
      lastname: 'Silva',
      isOwner: true,
    ).asConfidential();
    final next = transitionRecipientPick(
      filter,
      RecipientPickSaving(
        RecipientQuery(rails: filter.rails),
        2,
        PayoutRails.confidentialSepa,
        details,
      ),
      RecipientPickSaved(2, WriteDone(savedSepa)),
    );
    final picked = next.state as RecipientPickPicked;
    expect(picked.chosen.rail, PayoutRails.confidentialSepa);
    expect(picked.isNew, isTrue);
  });

  test('a saved recipient the filter refuses is not picked', () {
    final next = _step(_saving, RecipientPickSaved(2, WriteDone(_theirs)));
    expect(next.state, RecipientPickNotAdmitted(_query, 2, _theirs));
  });

  test('an unknown save outcome never saves again', () {
    var state = _step(
      _saving,
      const RecipientPickSaved(2, WriteOutcomeUnknown('timeout')),
    ).state;
    expect(_step(state, const RecipientPickSubmitted(_input)).state, state);
    state = _step(
      state,
      const RecipientPickFound(3, ReadUnreachable('down', isNetwork: true)),
    ).state;
    final retry = _step(state, const RecipientPickRetryPressed());
    expect(retry.effects.single, isA<RecipientPickFind>());
  });

  test('starts on the first page of every filter rail', () {
    expect(recipientPickStart(_filter), _load(1));
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <RecipientPickState>[recipientPickStart(_filter).state];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <RecipientPickState>[];
      for (final state in frontier) {
        for (final event in [
          ..._events,
          for (var a = 1; a < 5; a++) ...[
            RecipientPickPageLoaded(a, ListPage([_ann, _theirs], next: 2)),
            RecipientPickPageLoaded(
              a,
              const ListUnreachable('down', isNetwork: true),
            ),
            RecipientPickSaved(a, WriteDone(_theirs)),
            RecipientPickSaved(a, const WriteOutcomeUnknown('timeout')),
            RecipientPickFound(
              a,
              const ReadUnreachable('down', isNetwork: true),
            ),
          ],
        ]) {
          final target = _step(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
