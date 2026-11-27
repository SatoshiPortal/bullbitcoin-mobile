import 'package:bull_exchange/src/recipients/domain/entities/account_owner_name.dart';
import 'package:bull_exchange/src/recipients/domain/entities/cad_biller_summary.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_effect.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_event.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_state.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/check_sinpe_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/list_cad_billers_usecase.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../recipient_fixture.dart';

final _sepaFilters = RecipientFilterCriteria(
  types: const [RecipientType.sepaEur, RecipientType.confidentialSepaEur],
);
final _crcFilters = RecipientFilterCriteria(
  types: const [RecipientType.sinpeMovilCrc],
);

const _owner = AccountOwnerName(firstName: 'Mary Ann', lastName: 'Smith');
const _input = RecipientDetailsInput(
  recipientType: RecipientType.sinpeMovilCrc,
  phoneNumber: '8888-8888',
);

Recipient _entity(String id) =>
    recipientFixture(id, RecipientType.sinpeMovilCrc).recipient;

Result<GetRecipientsResult, ExchangeFailure> _page(
  List<String> ids, {
  required int total,
}) => Ok(
  GetRecipientsResult(
    recipients: [for (final id in ids) _entity(id)],
    totalRecipients: total,
  ),
);

/// Applies [events] in order, collecting every effect.
(RecipientsState, List<RecipientsEffect>) _run(
  RecipientsState state,
  List<RecipientsEvent> events,
) {
  final effects = <RecipientsEffect>[];
  for (final event in events) {
    final next = state.next(event);
    state = next.state;
    effects.addAll(next.effects);
  }
  return (state, effects);
}

/// A CRC list opened and its first page loaded (generation 1).
RecipientsState _loaded({int total = 120}) =>
    _run(RecipientsState(allowedRecipientFilters: _crcFilters), [
      const RecipientsStarted(),
      RecipientsPageAnswered(1, _page(['a', 'b'], total: total)),
    ]).$1;

void main() {
  group('opening', () {
    test('reads Confidential SEPA, its owner name, the first page, then '
        'the preferred jurisdiction', () {
      var next = RecipientsState(allowedRecipientFilters: _sepaFilters)
          .next(const RecipientsStarted());
      expect(next.state.startup, const StartupReadingSepa());
      expect(next.state.isLoadingConfidentialSepaAvailability, isTrue);
      expect(next.effects, [const RecipientsReadSepaAvailability()]);

      next = next.state.next(
        const RecipientsSepaAvailabilityAnswered(
          Ok(ConfidentialSepaAvailability.ready),
        ),
      );
      expect(next.state.sepaRead, const SepaReadingOwnerName());
      expect(next.effects, [const RecipientsReadOwnerName()]);

      next = next.state.next(const RecipientsOwnerNameAnswered(Ok(_owner)));
      expect(next.state.accountOwnerName, _owner);
      expect(next.state.isLoadingConfidentialSepaAvailability, isFalse);
      // Europe is the only jurisdiction left: it is selected.
      expect(next.state.jurisdictionFilter, Jurisdiction.europe);
      expect(next.state.startup, const StartupLoading(1));
      expect(next.state.listLoad, const ListLoadingFirst(1));
      expect(next.effects, [
        const RecipientsFetchPage(
          generation: 1,
          page: 1,
          types: [RecipientType.sepaEur],
          isOwner: null,
          search: '',
        ),
      ]);

      next = next.state.next(RecipientsPageAnswered(1, _page([], total: 0)));
      expect(next.state.recipients, isEmpty);
      expect(next.state.startup, const StartupReadingPreference());
      expect(next.effects, [const RecipientsReadPreferredJurisdiction()]);

      next = next.state.next(
        const RecipientsPreferenceAnswered(Ok(Jurisdiction.europe)),
      );
      expect(next.state.startup, const StartupDone());
      expect(next.state.preferredJurisdiction, Jurisdiction.europe);
    });

    test('an unavailable Confidential SEPA reads no owner name', () {
      final (state, effects) = _run(
        RecipientsState(allowedRecipientFilters: _sepaFilters),
        [
          const RecipientsStarted(),
          const RecipientsSepaAvailabilityAnswered(
            Ok(ConfidentialSepaAvailability.unavailable),
          ),
        ],
      );
      expect(effects, isNot(contains(const RecipientsReadOwnerName())));
      expect(state.selectableRecipientTypes, {RecipientType.sepaEur});
      expect(state.listLoad, const ListLoadingFirst(1));
    });

    test('a failed read is shown and the list still loads', () {
      final (state, _) = _run(
        RecipientsState(allowedRecipientFilters: _sepaFilters),
        [
          const RecipientsStarted(),
          const RecipientsSepaAvailabilityAnswered(
            Ok(ConfidentialSepaAvailability.ready),
          ),
          const RecipientsOwnerNameAnswered(Err(ExchangeNetworkFailure())),
        ],
      );
      expect(
        state.failedToLoadConfidentialSepaAvailability,
        isA<ExchangeNetworkFailure>(),
      );
      expect(state.listLoad, const ListLoadingFirst(1));
    });

    test('a list without Confidential SEPA loads at once; Started again '
        'does nothing', () {
      final next = RecipientsState(allowedRecipientFilters: _crcFilters)
          .next(const RecipientsStarted());
      expect(next.state.listLoad, const ListLoadingFirst(1));
      expect(next.effects.single, isA<RecipientsFetchPage>());
      expect(
        identical(next.state.next(const RecipientsStarted()).state, next.state),
        isTrue,
      );
    });

    test('a failed preference read offers no jurisdiction first', () {
      final (state, _) = _run(_loaded(), [
        const RecipientsPreferenceAnswered(Err(ExchangeNetworkFailure())),
      ]);
      expect(state.preferredJurisdiction, isNull);
      expect(state.startup, const StartupDone());
    });
  });

  group('the list', () {
    test('an answer of a replaced load is dropped; the startup still goes '
        'on', () {
      final (state, effects) = _run(
        RecipientsState(allowedRecipientFilters: _crcFilters),
        [
          const RecipientsStarted(),
          const RecipientsJurisdictionChanged(Jurisdiction.costaRica),
          RecipientsPageAnswered(1, _page(['old'], total: 1)),
        ],
      );
      expect(state.recipients, isNull);
      expect(state.listLoad, const ListLoadingFirst(2));
      expect(effects.last, const RecipientsReadPreferredJurisdiction());
    });

    test('loads more and appends; an empty page ends the list', () {
      var (state, effects) = _run(_loaded(), [const RecipientsMoreLoaded()]);
      expect(state.isLoadingRecipients, isTrue);
      expect(
        effects.single,
        isA<RecipientsFetchPage>().having((e) => e.page, 'page', 2),
      );
      (state, _) = _run(state, [
        RecipientsPageAnswered(1, _page(['c'], total: 120)),
      ]);
      expect(state.recipients!.map((r) => r.id), ['a', 'b', 'c']);
      expect(state.loadedPages, 2);
      expect(state.hasMoreRecipientsToLoad, isTrue);
      (state, _) = _run(state, [
        const RecipientsMoreLoaded(),
        RecipientsPageAnswered(1, _page([], total: 120)),
      ]);
      expect(state.hasMoreRecipientsToLoad, isFalse);
      expect(state.isLoadingRecipients, isFalse);
    });

    test('asks for no more while loading or when all are loaded', () {
      final loading = _loaded().next(const RecipientsMoreLoaded()).state;
      expect(
        identical(loading.next(const RecipientsMoreLoaded()).state, loading),
        isTrue,
      );
      final all = _loaded(total: 2);
      expect(
        identical(all.next(const RecipientsMoreLoaded()).state, all),
        isTrue,
      );
    });

    test('a failed load keeps the rows and shows the failure', () {
      final (state, _) = _run(_loaded(), [
        const RecipientsRefreshed(),
        const RecipientsPageAnswered(2, Err(ExchangeRecipientsLoadFailure())),
      ]);
      expect(state.recipients, hasLength(2));
      expect(
        state.failedToLoadRecipients,
        isA<ExchangeRecipientsLoadFailure>(),
      );
      expect(state.isLoadingRecipients, isFalse);
    });

    test('a typed search waits out its pause; only the last one loads', () {
      var (state, effects) = _run(_loaded(), [
        const RecipientsSearchChanged('sa'),
        const RecipientsSearchChanged('sat'),
      ]);
      expect(effects, [
        const RecipientsSearchPause(1, 'sa'),
        const RecipientsSearchPause(2, 'sat'),
      ]);
      expect(
        identical(
          state.next(const RecipientsSearchSettled(1, 'sa')).state,
          state,
        ),
        isTrue,
      );
      (state, effects) = _run(state, [const RecipientsSearchSettled(2, 'sat')]);
      expect(state.searchQuery, 'sat');
      expect(state.recipients, isNull);
      expect(
        effects.single,
        isA<RecipientsFetchPage>().having((e) => e.search, 'search', 'sat'),
      );
    });

    test('a new search drops the load of the one it replaces', () {
      final (state, _) = _run(_loaded(), [
        const RecipientsSearchChanged('sa'),
        const RecipientsSearchSettled(1, 'sa'),
        const RecipientsSearchChanged('sat'),
        RecipientsPageAnswered(2, _page(['x'], total: 1)),
      ]);
      expect(state.listLoad, const ListSearchPending());
      expect(state.isLoadingRecipients, isTrue);
      expect(state.recipients, isNull);
    });

    test('clearing the search loads at once', () {
      final next = _loaded().next(const RecipientsSearchChanged(''));
      expect(next.state.listLoad, const ListLoadingFirst(2, searchTicket: 1));
      expect(next.effects.single, isA<RecipientsFetchPage>());
    });
  });

  group('retry', () {
    RecipientsState sepaFailed() => _run(
      RecipientsState(allowedRecipientFilters: _sepaFilters),
      [
        const RecipientsStarted(),
        const RecipientsSepaAvailabilityAnswered(Err(ExchangeNetworkFailure())),
        const RecipientsPageAnswered(1, Err(ExchangeRecipientsLoadFailure())),
      ],
    ).$1;

    test('reads Confidential SEPA again, showing the list loading under its '
        'last failure, then reloads the list', () {
      var next = sepaFailed().next(
        const RecipientsConfidentialSepaAvailabilityRetried(),
      );
      expect(next.state.retry, const RetryReadingSepa());
      expect(next.state.isLoadingRecipients, isTrue);
      expect(
        next.state.failedToLoadRecipients,
        isA<ExchangeRecipientsLoadFailure>(),
      );
      expect(next.effects, [const RecipientsReadSepaAvailability()]);
      expect(
        identical(
          next.state
              .next(const RecipientsConfidentialSepaAvailabilityRetried())
              .state,
          next.state,
        ),
        isTrue,
      );

      next = next.state.next(
        const RecipientsSepaAvailabilityAnswered(
          Ok(ConfidentialSepaAvailability.unavailable),
        ),
      );
      expect(next.state.retry, const RetryLoading(2));
      expect(next.state.failedToLoadRecipients, isNull);
      next = next.state.next(RecipientsPageAnswered(2, _page([], total: 0)));
      expect(next.state.retry, const RetryIdle());
    });

    test('a refresh after a failed Confidential SEPA read retries it', () {
      final next = sepaFailed().next(const RecipientsRefreshed());
      expect(next.state.retry, const RetryReadingSepa());
    });
  });

  group('saving a new recipient', () {
    final saved = Ok<AddRecipientResult, ExchangeFailure>(
      AddRecipientResult(recipient: _entity('new')),
    );

    test('saves, then hands it to the selection hook', () {
      var next = _loaded().next(const RecipientsAdded(_input));
      expect(next.state.isAddingRecipient, isTrue);
      expect(next.effects, [const RecipientsSave(_input)]);
      next = next.state.next(RecipientsSaveAnswered(saved));
      expect(next.state.save, const SaveSelecting());
      expect(next.state.isAddingRecipient, isTrue);
      expect(
        next.effects.single,
        isA<RecipientsRunSelection>().having((e) => e.isNew, 'isNew', isTrue),
      );
      final done = next.state.next(
        const RecipientsSavedSelectionAnswered(Ok(null)),
      );
      expect(done.state.save, const SaveIdle());
      expect(done.state.isAddingRecipient, isFalse);
      final notSelected = next.state.next(
        const RecipientsSavedSelectionAnswered(
          Err(ExchangeRecipientsSelectionFailure()),
        ),
      );
      expect(
        notSelected.state.failedToAddRecipient,
        isA<ExchangeRecipientsSavedButNotSelectedFailure>(),
      );
    });

    test('an unknown outcome refreshes the list and blocks another save '
        'until the form changes', () {
      var (state, effects) = _run(_loaded(), [
        const RecipientsAdded(_input),
        const RecipientsSaveAnswered(
          Err(ExchangeRecipientsSaveOutcomeUnknownFailure()),
        ),
      ]);
      expect(state.listLoad, const ListLoadingFirst(2));
      expect(effects.last, isA<RecipientsFetchPage>());
      expect(
        identical(state.next(const RecipientsAdded(_input)).state, state),
        isTrue,
      );
      (state, effects) = _run(state, [
        const RecipientsNewRecipientFormChanged(),
        const RecipientsAdded(_input),
      ]);
      expect(effects.last, const RecipientsSave(_input));
    });

    test('a refused save shows its failure; another try may follow', () {
      final (state, effects) = _run(_loaded(), [
        const RecipientsAdded(_input),
        const RecipientsSaveAnswered(Err(ExchangeNetworkFailure())),
        const RecipientsAdded(_input),
      ]);
      expect(state.save, const SaveSaving());
      expect(effects.whereType<RecipientsSave>(), hasLength(2));
    });
  });

  test('a picked recipient goes to the hook; its failure is shown', () {
    final picked = recipientFixture('a', RecipientType.sinpeMovilCrc);
    var next = _loaded().next(RecipientsSelected(picked));
    expect(next.effects, [RecipientsRunSelection(picked, isNew: false)]);
    next = next.state.next(
      const RecipientsSelectionAnswered(
        Err(ExchangeRecipientsSelectionFailure()),
      ),
    );
    expect(
      next.state.failedToSelectRecipient,
      isA<ExchangeRecipientsSelectionFailure>(),
    );
    next = next.state
        .next(RecipientsSelected(picked))
        .state
        .next(const RecipientsSelectionAnswered(Ok(null)));
    expect(next.state.failedToSelectRecipient, isNull);
  });

  test('SINPE look-up and CAD biller search', () {
    var (state, effects) = _run(_loaded(), [
      const RecipientsSinpeChecked('8888'),
      const RecipientsCadBillersSearched('hydro'),
    ]);
    expect(effects, [
      const RecipientsCheckSinpe('8888'),
      const RecipientsSearchBillers('hydro'),
    ]);
    expect(state.isCheckingSinpe && state.isSearchingCadBillers, isTrue);
    expect(state.isLoading, isTrue);
    (state, _) = _run(state, [
      RecipientsSinpeAnswered(Ok(CheckSinpeResult(ownerName: 'Sat Oshi'))),
      RecipientsBillersAnswered(
        Ok(
          ListCadBillersResult(
            billers: const [
              CadBillerSummary(payeeCode: '1', payeeName: 'Hydro'),
            ],
          ),
        ),
      ),
    ]);
    expect(state.sinpeOwnerName, 'Sat Oshi');
    expect(state.cadBillers, hasLength(1));
    expect(state.isLoading, isFalse);
    (state, _) = _run(state, [
      const RecipientsSinpeChecked('7777'),
      const RecipientsSinpeAnswered(Err(ExchangeNetworkFailure())),
    ]);
    expect(state.sinpeOwnerName, isEmpty);
    expect(state.failedToCheckSinpe, isA<ExchangeNetworkFailure>());
  });

  test('an activated virtual IBAN makes Confidential SEPA ready', () {
    final state = RecipientsState(allowedRecipientFilters: _sepaFilters)
        .next(const RecipientsVirtualIbanActivated())
        .state;
    expect(
      state.confidentialSepaAvailability,
      ConfidentialSepaAvailability.ready,
    );
    expect(state.selectableRecipientTypes, hasLength(2));
  });
}
