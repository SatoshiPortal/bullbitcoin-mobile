import 'package:bull_exchange/src/recipients/domain/entities/account_owner_name.dart';
import 'package:bull_exchange/src/recipients/domain/entities/cad_biller_summary.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_effect.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_event.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show StepNext, listsEqual;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Rows asked for per page of the list.
const recipientsPageSize = 50;

typedef RecipientsNext = StepNext<RecipientsState, RecipientsEffect>;

// ---------------------------------------------------------------------------
// The parts of the screen that load or write on their own.

/// The read of whether Confidential SEPA is offered and, when it is not
/// unavailable, of the account owner's name the SEPA form prefills.
@immutable
sealed class SepaRead {
  const SepaRead();
}

/// Not reading: never read, or the last read answered.
final class SepaReadIdle extends SepaRead {
  const SepaReadIdle();

  @override
  bool operator ==(Object other) => other is SepaReadIdle;

  @override
  int get hashCode => (SepaReadIdle).hashCode;
}

final class SepaReadingAvailability extends SepaRead {
  const SepaReadingAvailability();

  @override
  bool operator ==(Object other) => other is SepaReadingAvailability;

  @override
  int get hashCode => (SepaReadingAvailability).hashCode;
}

/// Confidential SEPA is offered; its owner name is being read.
final class SepaReadingOwnerName extends SepaRead {
  const SepaReadingOwnerName();

  @override
  bool operator ==(Object other) => other is SepaReadingOwnerName;

  @override
  int get hashCode => (SepaReadingOwnerName).hashCode;
}

/// The availability or the owner name could not be read; Retry reads both
/// again.
final class SepaReadFailed extends SepaRead {
  final ExchangeFailure failure;

  const SepaReadFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is SepaReadFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(SepaReadFailed, failure);
}

/// The list's load. A load is tagged with the generation it started as; an
/// answer of an older generation is dropped (a newer filter, search or
/// refresh replaced it).
@immutable
sealed class RecipientsListLoad {
  const RecipientsListLoad();
}

final class ListIdle extends RecipientsListLoad {
  const ListIdle();

  @override
  bool operator ==(Object other) => other is ListIdle;

  @override
  int get hashCode => (ListIdle).hashCode;
}

/// The first page is being read; [searchTicket] when a search started it
/// (a newer search replaces it).
final class ListLoadingFirst extends RecipientsListLoad {
  final int generation;
  final int? searchTicket;

  const ListLoadingFirst(this.generation, {this.searchTicket});

  @override
  bool operator ==(Object other) =>
      other is ListLoadingFirst &&
      other.generation == generation &&
      other.searchTicket == searchTicket;

  @override
  int get hashCode => Object.hash(ListLoadingFirst, generation, searchTicket);
}

final class ListLoadingMore extends RecipientsListLoad {
  final int generation;

  const ListLoadingMore(this.generation);

  @override
  bool operator ==(Object other) =>
      other is ListLoadingMore && other.generation == generation;

  @override
  int get hashCode => Object.hash(ListLoadingMore, generation);
}

/// A search's load was dropped for a newer search still waiting out its
/// typing pause: shown loading until that one loads.
final class ListSearchPending extends RecipientsListLoad {
  const ListSearchPending();

  @override
  bool operator ==(Object other) => other is ListSearchPending;

  @override
  int get hashCode => (ListSearchPending).hashCode;
}

/// Retry re-reads Confidential SEPA before the list: shown loading
/// meanwhile, still under the last list failure ([shown]) if there was one.
final class ListRetryPending extends RecipientsListLoad {
  final ExchangeFailure? shown;

  const ListRetryPending(this.shown);

  @override
  bool operator ==(Object other) =>
      other is ListRetryPending && other.shown == shown;

  @override
  int get hashCode => Object.hash(ListRetryPending, shown);
}

final class ListFailed extends RecipientsListLoad {
  final ExchangeFailure failure;

  const ListFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is ListFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(ListFailed, failure);
}

/// Opening the screen: Confidential SEPA first (it decides the types and
/// jurisdictions), then the first page, then the preferred jurisdiction.
@immutable
sealed class RecipientsStartup {
  const RecipientsStartup();
}

final class StartupNotStarted extends RecipientsStartup {
  const StartupNotStarted();

  @override
  bool operator ==(Object other) => other is StartupNotStarted;

  @override
  int get hashCode => (StartupNotStarted).hashCode;
}

final class StartupReadingSepa extends RecipientsStartup {
  const StartupReadingSepa();

  @override
  bool operator ==(Object other) => other is StartupReadingSepa;

  @override
  int get hashCode => (StartupReadingSepa).hashCode;
}

/// Waiting for the answer of its first-page load [generation], even when a
/// newer load replaced it.
final class StartupLoading extends RecipientsStartup {
  final int generation;

  const StartupLoading(this.generation);

  @override
  bool operator ==(Object other) =>
      other is StartupLoading && other.generation == generation;

  @override
  int get hashCode => Object.hash(StartupLoading, generation);
}

final class StartupReadingPreference extends RecipientsStartup {
  const StartupReadingPreference();

  @override
  bool operator ==(Object other) => other is StartupReadingPreference;

  @override
  int get hashCode => (StartupReadingPreference).hashCode;
}

final class StartupDone extends RecipientsStartup {
  const StartupDone();

  @override
  bool operator ==(Object other) => other is StartupDone;

  @override
  int get hashCode => (StartupDone).hashCode;
}

/// Retrying a failed Confidential SEPA read: the read, then the first page.
/// Another Retry is dropped until it ends.
@immutable
sealed class RecipientsRetry {
  const RecipientsRetry();
}

final class RetryIdle extends RecipientsRetry {
  const RetryIdle();

  @override
  bool operator ==(Object other) => other is RetryIdle;

  @override
  int get hashCode => (RetryIdle).hashCode;
}

final class RetryReadingSepa extends RecipientsRetry {
  const RetryReadingSepa();

  @override
  bool operator ==(Object other) => other is RetryReadingSepa;

  @override
  int get hashCode => (RetryReadingSepa).hashCode;
}

final class RetryLoading extends RecipientsRetry {
  final int generation;

  const RetryLoading(this.generation);

  @override
  bool operator ==(Object other) =>
      other is RetryLoading && other.generation == generation;

  @override
  int get hashCode => Object.hash(RetryLoading, generation);
}

/// Saving a new recipient, then handing it to the caller's selection hook.
@immutable
sealed class RecipientSave {
  const RecipientSave();
}

final class SaveIdle extends RecipientSave {
  const SaveIdle();

  @override
  bool operator ==(Object other) => other is SaveIdle;

  @override
  int get hashCode => (SaveIdle).hashCode;
}

final class SaveSaving extends RecipientSave {
  const SaveSaving();

  @override
  bool operator ==(Object other) => other is SaveSaving;

  @override
  int get hashCode => (SaveSaving).hashCode;
}

/// Saved; the caller's selection hook runs.
final class SaveSelecting extends RecipientSave {
  const SaveSelecting();

  @override
  bool operator ==(Object other) => other is SaveSelecting;

  @override
  int get hashCode => (SaveSelecting).hashCode;
}

/// Shown under the form until it changes. An unknown outcome
/// ([ExchangeRecipientsSaveOutcomeUnknownFailure]) blocks another save from
/// this form: the last one may have created the recipient.
final class SaveFailed extends RecipientSave {
  final ExchangeFailure failure;

  const SaveFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is SaveFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(SaveFailed, failure);
}

/// Handing a recipient picked from the list to the caller's selection hook.
@immutable
sealed class RecipientSelection {
  const RecipientSelection();
}

final class SelectionIdle extends RecipientSelection {
  const SelectionIdle();

  @override
  bool operator ==(Object other) => other is SelectionIdle;

  @override
  int get hashCode => (SelectionIdle).hashCode;
}

final class SelectionRunning extends RecipientSelection {
  const SelectionRunning();

  @override
  bool operator ==(Object other) => other is SelectionRunning;

  @override
  int get hashCode => (SelectionRunning).hashCode;
}

final class SelectionFailed extends RecipientSelection {
  final ExchangeFailure failure;

  const SelectionFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is SelectionFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(SelectionFailed, failure);
}

/// The SINPE Móvil owner look-up of a phone number.
@immutable
sealed class SinpeCheck {
  const SinpeCheck();
}

final class SinpeIdle extends SinpeCheck {
  const SinpeIdle();

  @override
  bool operator ==(Object other) => other is SinpeIdle;

  @override
  int get hashCode => (SinpeIdle).hashCode;
}

final class SinpeChecking extends SinpeCheck {
  const SinpeChecking();

  @override
  bool operator ==(Object other) => other is SinpeChecking;

  @override
  int get hashCode => (SinpeChecking).hashCode;
}

final class SinpeChecked extends SinpeCheck {
  final String ownerName;

  const SinpeChecked(this.ownerName);

  @override
  bool operator ==(Object other) =>
      other is SinpeChecked && other.ownerName == ownerName;

  @override
  int get hashCode => Object.hash(SinpeChecked, ownerName);
}

final class SinpeFailed extends SinpeCheck {
  final ExchangeFailure failure;

  const SinpeFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is SinpeFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(SinpeFailed, failure);
}

/// The CAD bill-payment payee search.
@immutable
sealed class CadBillerSearch {
  const CadBillerSearch();
}

final class BillersIdle extends CadBillerSearch {
  const BillersIdle();

  @override
  bool operator ==(Object other) => other is BillersIdle;

  @override
  int get hashCode => (BillersIdle).hashCode;
}

final class BillersSearching extends CadBillerSearch {
  const BillersSearching();

  @override
  bool operator ==(Object other) => other is BillersSearching;

  @override
  int get hashCode => (BillersSearching).hashCode;
}

final class BillersFound extends CadBillerSearch {
  final List<CadBillerSummary> billers;

  const BillersFound(this.billers);

  @override
  bool operator ==(Object other) =>
      other is BillersFound && listsEqual(other.billers, billers);

  @override
  int get hashCode => Object.hash(BillersFound, Object.hashAll(billers));
}

final class BillersFailed extends CadBillerSearch {
  final ExchangeFailure failure;

  const BillersFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is BillersFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(BillersFailed, failure);
}

// ---------------------------------------------------------------------------
// The screen.

const Object _unset = Object();

/// The recipients screen: the filters and list data, with each part that
/// loads or writes on its own as its own sealed state. Every transition is
/// in [next].
@immutable
final class RecipientsState {
  final RecipientFilterCriteria allowedRecipientFilters;
  final Jurisdiction? preferredJurisdiction;
  final Jurisdiction? jurisdictionFilter;
  final RecipientType sepaType;
  final String searchQuery;

  /// The last search typed; a paused search applies only if still last.
  final int searchTicket;

  /// The last Confidential SEPA availability read (or activated), and the
  /// owner name read with it.
  final ConfidentialSepaAvailability? confidentialSepaAvailability;
  final AccountOwnerName? accountOwnerName;
  final SepaRead sepaRead;

  /// Null before a first page arrived, and while a new filter loads.
  final List<RecipientViewModel>? recipients;
  final int? totalRecipients;
  final int loadedPages;

  /// The generation of the latest list load.
  final int loadGeneration;
  final RecipientsListLoad listLoad;
  final RecipientsStartup startup;
  final RecipientsRetry retry;
  final RecipientSave save;
  final RecipientSelection selection;
  final SinpeCheck sinpe;
  final CadBillerSearch billers;

  const RecipientsState({
    required this.allowedRecipientFilters,
    this.preferredJurisdiction,
    this.jurisdictionFilter,
    this.sepaType = RecipientType.sepaEur,
    this.searchQuery = '',
    this.searchTicket = 0,
    this.confidentialSepaAvailability,
    this.accountOwnerName,
    this.sepaRead = const SepaReadIdle(),
    this.recipients,
    this.totalRecipients,
    this.loadedPages = 0,
    this.loadGeneration = 0,
    this.listLoad = const ListIdle(),
    this.startup = const StartupNotStarted(),
    this.retry = const RetryIdle(),
    this.save = const SaveIdle(),
    this.selection = const SelectionIdle(),
    this.sinpe = const SinpeIdle(),
    this.billers = const BillersIdle(),
  });

  RecipientsState copyWith({
    Object? preferredJurisdiction = _unset,
    Object? jurisdictionFilter = _unset,
    RecipientType? sepaType,
    String? searchQuery,
    int? searchTicket,
    Object? confidentialSepaAvailability = _unset,
    Object? accountOwnerName = _unset,
    SepaRead? sepaRead,
    Object? recipients = _unset,
    Object? totalRecipients = _unset,
    int? loadedPages,
    int? loadGeneration,
    RecipientsListLoad? listLoad,
    RecipientsStartup? startup,
    RecipientsRetry? retry,
    RecipientSave? save,
    RecipientSelection? selection,
    SinpeCheck? sinpe,
    CadBillerSearch? billers,
  }) => RecipientsState(
    allowedRecipientFilters: allowedRecipientFilters,
    preferredJurisdiction: identical(preferredJurisdiction, _unset)
        ? this.preferredJurisdiction
        : preferredJurisdiction as Jurisdiction?,
    jurisdictionFilter: identical(jurisdictionFilter, _unset)
        ? this.jurisdictionFilter
        : jurisdictionFilter as Jurisdiction?,
    sepaType: sepaType ?? this.sepaType,
    searchQuery: searchQuery ?? this.searchQuery,
    searchTicket: searchTicket ?? this.searchTicket,
    confidentialSepaAvailability:
        identical(confidentialSepaAvailability, _unset)
        ? this.confidentialSepaAvailability
        : confidentialSepaAvailability as ConfidentialSepaAvailability?,
    accountOwnerName: identical(accountOwnerName, _unset)
        ? this.accountOwnerName
        : accountOwnerName as AccountOwnerName?,
    sepaRead: sepaRead ?? this.sepaRead,
    recipients: identical(recipients, _unset)
        ? this.recipients
        : recipients as List<RecipientViewModel>?,
    totalRecipients: identical(totalRecipients, _unset)
        ? this.totalRecipients
        : totalRecipients as int?,
    loadedPages: loadedPages ?? this.loadedPages,
    loadGeneration: loadGeneration ?? this.loadGeneration,
    listLoad: listLoad ?? this.listLoad,
    startup: startup ?? this.startup,
    retry: retry ?? this.retry,
    save: save ?? this.save,
    selection: selection ?? this.selection,
    sinpe: sinpe ?? this.sinpe,
    billers: billers ?? this.billers,
  );

  RecipientsNext next(RecipientsEvent event) {
    final state = this;
    switch (event) {
      case RecipientsStarted():
        return switch (state.startup) {
          StartupNotStarted() =>
            state._offersConfidentialSepa && !state._readingSepa
                ? RecipientsNext(
                    state.copyWith(
                      startup: const StartupReadingSepa(),
                      sepaRead: const SepaReadingAvailability(),
                    ),
                    const [RecipientsReadSepaAvailability()],
                  )
                : state._startupLoad(),
          StartupReadingSepa() ||
          StartupLoading() ||
          StartupReadingPreference() ||
          StartupDone() => RecipientsNext.stay(state),
        };
      case RecipientsSepaAvailabilityAnswered(:final availability):
        if (state.sepaRead is! SepaReadingAvailability) {
          return RecipientsNext.stay(state);
        }
        return switch (availability) {
          Ok(value: ConfidentialSepaAvailability.unavailable) =>
            state
                .copyWith(
                  confidentialSepaAvailability:
                      ConfidentialSepaAvailability.unavailable,
                  sepaRead: const SepaReadIdle(),
                )
                ._sepaDone(),
          Ok(:final value) => RecipientsNext(
            state.copyWith(
              confidentialSepaAvailability: value,
              sepaRead: const SepaReadingOwnerName(),
            ),
            const [RecipientsReadOwnerName()],
          ),
          Err(:final failure) =>
            state.copyWith(sepaRead: SepaReadFailed(failure))._sepaDone(),
        };
      case RecipientsOwnerNameAnswered(:final ownerName):
        if (state.sepaRead is! SepaReadingOwnerName) {
          return RecipientsNext.stay(state);
        }
        return switch (ownerName) {
          Ok(:final value) =>
            state
                .copyWith(
                  accountOwnerName: value,
                  sepaRead: const SepaReadIdle(),
                )
                ._sepaDone(),
          Err(:final failure) =>
            state.copyWith(sepaRead: SepaReadFailed(failure))._sepaDone(),
        };
      case RecipientsPreferenceAnswered(:final jurisdiction):
        return switch (state.startup) {
          StartupReadingPreference() => RecipientsNext(
            state.copyWith(
              startup: const StartupDone(),
              // Not surfaced as a failure: a missing preference only means
              // no jurisdiction is offered first; the user picks one.
              preferredJurisdiction: switch (jurisdiction) {
                Ok(:final value) => value,
                Err() => null,
              },
            ),
          ),
          StartupNotStarted() ||
          StartupReadingSepa() ||
          StartupLoading() ||
          StartupDone() => RecipientsNext.stay(state),
        };
      case RecipientsPageAnswered(:final generation, :final page):
        return state._pageAnswered(generation, page);
      case RecipientsMoreLoaded():
        return switch (state.listLoad) {
          ListIdle() ||
          ListFailed() when state.hasMoreRecipientsToLoad => RecipientsNext(
            state.copyWith(listLoad: ListLoadingMore(state.loadGeneration)),
            [state._fetch(state.loadGeneration, state.loadedPages + 1)],
          ),
          ListIdle() ||
          ListFailed() ||
          ListLoadingFirst() ||
          ListLoadingMore() ||
          ListSearchPending() ||
          ListRetryPending() => RecipientsNext.stay(state),
        };
      case RecipientsRefreshed():
        return switch (state.sepaRead) {
          SepaReadFailed() => state._retried(),
          SepaReadIdle() ||
          SepaReadingAvailability() ||
          SepaReadingOwnerName() => state._loadFirst(clear: false),
        };
      case RecipientsConfidentialSepaAvailabilityRetried():
        return state._retried();
      case RecipientsSepaTypeChanged(:final sepaType):
        return state.copyWith(sepaType: sepaType)._loadFirst(clear: true);
      case RecipientsJurisdictionChanged(:final jurisdiction):
        return state
            .copyWith(jurisdictionFilter: jurisdiction)
            ._loadFirst(clear: true);
      case RecipientsSearchChanged(:final query):
        final ticket = state.searchTicket + 1;
        final typed = switch (state.listLoad) {
          // The load of the search this one replaces is dropped.
          ListLoadingFirst(searchTicket: _?) => state.copyWith(
            searchTicket: ticket,
            loadGeneration: state.loadGeneration + 1,
            listLoad: const ListSearchPending(),
          ),
          ListLoadingFirst() ||
          ListIdle() ||
          ListLoadingMore() ||
          ListSearchPending() ||
          ListRetryPending() ||
          ListFailed() => state.copyWith(searchTicket: ticket),
        };
        return query.isEmpty
            ? typed
                  .copyWith(searchQuery: query)
                  ._loadFirst(clear: true, searchTicket: ticket)
            : RecipientsNext(typed, [RecipientsSearchPause(ticket, query)]);
      case RecipientsSearchSettled(:final ticket, :final query):
        return ticket == state.searchTicket
            ? state
                  .copyWith(searchQuery: query)
                  ._loadFirst(clear: true, searchTicket: ticket)
            : RecipientsNext.stay(state);
      case RecipientsAdded(:final recipient):
        return switch (state.save) {
          SaveIdle() ||
          SaveFailed() when !state._saveMayHaveApplied => RecipientsNext(
            state.copyWith(save: const SaveSaving()),
            [RecipientsSave(recipient)],
          ),
          SaveIdle() ||
          SaveFailed() ||
          SaveSaving() ||
          SaveSelecting() => RecipientsNext.stay(state),
        };
      case RecipientsSaveAnswered(:final saved):
        if (state.save is! SaveSaving) return RecipientsNext.stay(state);
        return switch (saved) {
          Ok(:final value) => RecipientsNext(
            state.copyWith(save: const SaveSelecting()),
            [
              RecipientsRunSelection(
                RecipientViewModel(value.recipient),
                isNew: true,
              ),
            ],
          ),
          // The list says whether the recipient was saved.
          Err(failure: final ExchangeRecipientsSaveOutcomeUnknownFailure f) =>
            state
                .copyWith(save: SaveFailed(f))
                .next(const RecipientsRefreshed()),
          Err(:final failure) => RecipientsNext(
            state.copyWith(save: SaveFailed(failure)),
          ),
        };
      case RecipientsSavedSelectionAnswered(:final selected):
        if (state.save is! SaveSelecting) return RecipientsNext.stay(state);
        return RecipientsNext(
          state.copyWith(
            save: switch (selected) {
              Ok() => const SaveIdle(),
              // The recipient IS saved; only the onward step failed: its own
              // failure, so it does not read as "save failed" under a
              // Continue button the user would then press again.
              Err() => const SaveFailed(
                ExchangeRecipientsSavedButNotSelectedFailure(),
              ),
            },
          ),
        );
      case RecipientsNewRecipientFormChanged():
        // A save failure belongs to the form it was shown under; another
        // country or payout method starts without one, and without its
        // outcome-unknown guard: the new form is a different recipient.
        return switch (state.save) {
          SaveFailed() => RecipientsNext(
            state.copyWith(save: const SaveIdle()),
          ),
          SaveIdle() ||
          SaveSaving() ||
          SaveSelecting() => RecipientsNext.stay(state),
        };
      case RecipientsSelected(:final recipient):
        return RecipientsNext(
          state.copyWith(selection: const SelectionRunning()),
          [RecipientsRunSelection(recipient, isNew: false)],
        );
      case RecipientsSelectionAnswered(:final selected):
        return switch ((state.selection, selected)) {
          (SelectionRunning(), Ok()) => RecipientsNext(
            state.copyWith(selection: const SelectionIdle()),
          ),
          // Another selection failed meanwhile: its failure stays.
          (SelectionIdle() || SelectionFailed(), Ok()) => RecipientsNext.stay(
            state,
          ),
          (
            SelectionIdle() || SelectionRunning() || SelectionFailed(),
            Err(:final failure),
          ) =>
            RecipientsNext(state.copyWith(selection: SelectionFailed(failure))),
        };
      case RecipientsVirtualIbanActivated():
        return RecipientsNext(
          state.copyWith(
            confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
          ),
        );
      case RecipientsSinpeChecked(:final phoneNumber):
        return RecipientsNext(state.copyWith(sinpe: const SinpeChecking()), [
          RecipientsCheckSinpe(phoneNumber),
        ]);
      case RecipientsSinpeAnswered(:final owner):
        return RecipientsNext(
          state.copyWith(
            sinpe: switch (owner) {
              Ok(:final value) => SinpeChecked(value.ownerName),
              Err(:final failure) => SinpeFailed(failure),
            },
          ),
        );
      case RecipientsCadBillersSearched(:final query):
        return RecipientsNext(
          state.copyWith(billers: const BillersSearching()),
          [RecipientsSearchBillers(query)],
        );
      case RecipientsBillersAnswered(:final billers):
        return RecipientsNext(
          state.copyWith(
            billers: switch (billers) {
              Ok(:final value) => BillersFound(value.billers),
              Err(:final failure) => BillersFailed(failure),
            },
          ),
        );
    }
  }

  bool get _offersConfidentialSepa =>
      allowedRecipientFilters.types.contains(RecipientType.confidentialSepaEur);

  bool get _readingSepa => switch (sepaRead) {
    SepaReadingAvailability() || SepaReadingOwnerName() => true,
    SepaReadIdle() || SepaReadFailed() => false,
  };

  bool get _saveMayHaveApplied => switch (save) {
    SaveFailed(failure: ExchangeRecipientsSaveOutcomeUnknownFailure()) => true,
    SaveFailed() || SaveIdle() || SaveSaving() || SaveSelecting() => false,
  };

  RecipientsFetchPage _fetch(int generation, int page) => RecipientsFetchPage(
    generation: generation,
    page: page,
    types: listedTypes.toList(),
    isOwner: allowedRecipientFilters.isOwner,
    search: searchQuery,
  );

  /// A new first-page load; it replaces any load in flight.
  RecipientsNext _loadFirst({required bool clear, int? searchTicket}) {
    final generation = loadGeneration + 1;
    final loading = copyWith(
      loadGeneration: generation,
      listLoad: ListLoadingFirst(generation, searchTicket: searchTicket),
      recipients: clear ? null : recipients,
    );
    return RecipientsNext(loading, [loading._fetch(generation, 1)]);
  }

  /// Startup after Confidential SEPA was read (or isn't offered): a single
  /// jurisdiction is selected, then the first page loads.
  RecipientsNext _startupLoad() {
    final jurisdictions = availableJurisdictions;
    final next = copyWith(
      jurisdictionFilter: jurisdictions.length == 1
          ? jurisdictions.first
          : jurisdictionFilter,
    )._loadFirst(clear: true);
    return RecipientsNext(
      next.state.copyWith(startup: StartupLoading(next.state.loadGeneration)),
      next.effects,
    );
  }

  /// The Confidential SEPA read ended: whichever of startup and retry waited
  /// for it goes on to the list.
  RecipientsNext _sepaDone() {
    if (startup case StartupReadingSepa()) return _startupLoad();
    if (retry case RetryReadingSepa()) {
      final next = _loadFirst(clear: false);
      return RecipientsNext(
        next.state.copyWith(retry: RetryLoading(next.state.loadGeneration)),
        next.effects,
      );
    }
    return RecipientsNext(this);
  }

  RecipientsNext _retried() {
    if (retry case RetryReadingSepa() || RetryLoading()) {
      return RecipientsNext.stay(this);
    }
    final waiting = copyWith(
      listLoad: switch (listLoad) {
        ListIdle() => const ListRetryPending(null),
        ListFailed(:final failure) => ListRetryPending(failure),
        ListLoadingFirst() ||
        ListLoadingMore() ||
        ListSearchPending() ||
        ListRetryPending() => listLoad,
      },
    );
    if (_offersConfidentialSepa && !_readingSepa) {
      return RecipientsNext(
        waiting.copyWith(
          retry: const RetryReadingSepa(),
          sepaRead: const SepaReadingAvailability(),
        ),
        const [RecipientsReadSepaAvailability()],
      );
    }
    final next = waiting._loadFirst(clear: false);
    return RecipientsNext(
      next.state.copyWith(retry: RetryLoading(next.state.loadGeneration)),
      next.effects,
    );
  }

  RecipientsNext _pageAnswered(
    int generation,
    Result<GetRecipientsResult, ExchangeFailure> page,
  ) {
    // Startup and retry go on once their own load answered, current or not.
    var state = this;
    final effects = <RecipientsEffect>[];
    if (startup case StartupLoading(generation: final g) when g == generation) {
      state = state.copyWith(startup: const StartupReadingPreference());
      effects.add(const RecipientsReadPreferredJurisdiction());
    }
    if (retry case RetryLoading(generation: final g) when g == generation) {
      state = state.copyWith(retry: const RetryIdle());
    }
    if (generation == loadGeneration) {
      state = switch ((listLoad, page)) {
        (ListLoadingFirst(), Ok(:final value)) => state.copyWith(
          totalRecipients: value.totalRecipients,
          loadedPages: 1,
          recipients: value.recipients.map(RecipientViewModel.new).toList(),
          listLoad: const ListIdle(),
        ),
        (ListLoadingMore(), Ok(:final value)) => state.copyWith(
          // A page with no row this build can show ends the list: the
          // server's total can count rows it never returns, and the list
          // asks for more while it has none to show.
          totalRecipients: value.recipients.isEmpty
              ? recipients!.length
              : value.totalRecipients,
          loadedPages: loadedPages + 1,
          recipients: [
            ...recipients!,
            ...value.recipients.map(RecipientViewModel.new),
          ],
          listLoad: const ListIdle(),
        ),
        (ListLoadingFirst() || ListLoadingMore(), Err(:final failure)) =>
          state.copyWith(listLoad: ListFailed(failure)),
        (
          ListIdle() ||
              ListSearchPending() ||
              ListRetryPending() ||
              ListFailed(),
          Ok() || Err(),
        ) =>
          state,
      };
    }
    return identical(state, this) && effects.isEmpty
        ? RecipientsNext.stay(this)
        : RecipientsNext(state, effects);
  }

  // -------------------------------------------------------------------------
  // What the screen shows.

  bool get isLoadingConfidentialSepaAvailability => _readingSepa;

  ExchangeFailure? get failedToLoadConfidentialSepaAvailability =>
      switch (sepaRead) {
        SepaReadFailed(:final failure) => failure,
        SepaReadIdle() ||
        SepaReadingAvailability() ||
        SepaReadingOwnerName() => null,
      };

  bool get isLoadingRecipients => switch (listLoad) {
    ListLoadingFirst() ||
    ListLoadingMore() ||
    ListSearchPending() ||
    ListRetryPending() => true,
    ListIdle() || ListFailed() => false,
  };

  ExchangeFailure? get failedToLoadRecipients => switch (listLoad) {
    ListFailed(:final failure) => failure,
    ListRetryPending(:final shown) => shown,
    ListIdle() ||
    ListLoadingFirst() ||
    ListLoadingMore() ||
    ListSearchPending() => null,
  };

  bool get isAddingRecipient => switch (save) {
    SaveSaving() || SaveSelecting() => true,
    SaveIdle() || SaveFailed() => false,
  };

  ExchangeFailure? get failedToAddRecipient => switch (save) {
    SaveFailed(:final failure) => failure,
    SaveIdle() || SaveSaving() || SaveSelecting() => null,
  };

  ExchangeFailure? get failedToSelectRecipient => switch (selection) {
    SelectionFailed(:final failure) => failure,
    SelectionIdle() || SelectionRunning() => null,
  };

  bool get isCheckingSinpe => switch (sinpe) {
    SinpeChecking() => true,
    SinpeIdle() || SinpeChecked() || SinpeFailed() => false,
  };

  ExchangeFailure? get failedToCheckSinpe => switch (sinpe) {
    SinpeFailed(:final failure) => failure,
    SinpeIdle() || SinpeChecking() || SinpeChecked() => null,
  };

  String get sinpeOwnerName => switch (sinpe) {
    SinpeChecked(:final ownerName) => ownerName,
    SinpeIdle() || SinpeChecking() || SinpeFailed() => '',
  };

  bool get isSearchingCadBillers => switch (billers) {
    BillersSearching() => true,
    BillersIdle() || BillersFound() || BillersFailed() => false,
  };

  ExchangeFailure? get failedToSearchCadBillers => switch (billers) {
    BillersFailed(:final failure) => failure,
    BillersIdle() || BillersSearching() || BillersFound() => null,
  };

  List<CadBillerSummary>? get cadBillers => switch (billers) {
    BillersFound(:final billers) => billers,
    BillersIdle() || BillersSearching() || BillersFailed() => null,
  };

  bool get isLoading =>
      isLoadingConfidentialSepaAvailability ||
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers;

  bool get hasMoreRecipientsToLoad {
    final total = totalRecipients;
    if (recipients == null || total == null) return false;
    return loadedPages * recipientsPageSize < total;
  }

  Set<RecipientType> get selectableRecipientTypes => allowedRecipientFilters
      .types
      .where(
        (type) =>
            type != RecipientType.confidentialSepaEur ||
            (confidentialSepaAvailability != null &&
                confidentialSepaAvailability !=
                    ConfidentialSepaAvailability.unavailable),
      )
      .toSet();

  bool get _offersBothSepaRoutes =>
      selectableRecipientTypes.contains(RecipientType.sepaEur) &&
      selectableRecipientTypes.contains(RecipientType.confidentialSepaEur);

  /// Regular and Confidential SEPA list the same accounts, so a list that
  /// offers both shows one route at a time. The route is a type filter of
  /// the European list: it is offered only there, where it decides every
  /// row shown (under all jurisdictions it would leave the other rails'
  /// rows in a list labelled with a SEPA route).
  bool get canChooseSepaType =>
      _offersBothSepaRoutes &&
      jurisdictionFilter == RecipientType.sepaEur.jurisdiction;

  /// The types the list asks for and shows: the selectable ones in the
  /// selected jurisdiction, with one SEPA route when both are offered (the
  /// chosen one in Europe, regular SEPA otherwise).
  Set<RecipientType> get listedTypes {
    final hiddenSepaType = !_offersBothSepaRoutes
        ? null
        : canChooseSepaType && sepaType == RecipientType.confidentialSepaEur
        ? RecipientType.sepaEur
        : RecipientType.confidentialSepaEur;
    final jurisdiction = jurisdictionFilter;
    return selectableRecipientTypes
        .where(
          (type) =>
              type != hiddenSepaType &&
              (jurisdiction == null || type.jurisdiction == jurisdiction),
        )
        .toSet();
  }

  /// The rows the list shows, always derived from the selected type and
  /// jurisdiction ([listedTypes]), whatever the server returned; with
  /// [strict], also only rows of the allowed owner. Null before the first
  /// page arrived.
  List<RecipientViewModel>? shownRecipients({required bool strict}) {
    final rows = selectableRecipients;
    if (rows == null) return null;
    final types = listedTypes;
    final owner = allowedRecipientFilters.isOwner;
    return rows
        .where(
          (recipient) =>
              types.contains(recipient.type) &&
              (!strict || owner == null || recipient.isOwner == owner),
        )
        .toList();
  }

  bool get onlyOwnerRecipients => allowedRecipientFilters.isOwner ?? false;

  bool get onlyNonOwnerRecipients => allowedRecipientFilters.isOwner == false;

  Set<Jurisdiction> get availableJurisdictions =>
      selectableRecipientTypes.map((type) => type.jurisdiction).toSet();

  Jurisdiction? get selectedJurisdiction {
    if (preferredJurisdiction != null) {
      if (selectableRecipientTypes.any(
        (t) => t.jurisdiction == preferredJurisdiction,
      )) {
        return preferredJurisdiction;
      } else {
        // Preferred jurisdiction is not available in the current filters
        // so we fall back to the first available jurisdiction
        return selectableRecipientTypes.map((t) => t.jurisdiction).firstOrNull;
      }
    }
    return null;
  }

  Set<RecipientType> recipientTypesForJurisdiction(Jurisdiction jurisdiction) {
    return selectableRecipientTypes
        .where((type) => type.jurisdiction == jurisdiction)
        .toSet();
  }

  List<RecipientViewModel>? get selectableRecipients {
    final loaded = recipients;
    if (loaded == null) return null;
    final seen = <String>{};
    return loaded.where((recipient) => seen.add(recipient.id)).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is RecipientsState &&
      other.allowedRecipientFilters == allowedRecipientFilters &&
      other.preferredJurisdiction == preferredJurisdiction &&
      other.jurisdictionFilter == jurisdictionFilter &&
      other.sepaType == sepaType &&
      other.searchQuery == searchQuery &&
      other.searchTicket == searchTicket &&
      other.confidentialSepaAvailability == confidentialSepaAvailability &&
      other.accountOwnerName == accountOwnerName &&
      other.sepaRead == sepaRead &&
      _sameRows(other.recipients, recipients) &&
      other.totalRecipients == totalRecipients &&
      other.loadedPages == loadedPages &&
      other.loadGeneration == loadGeneration &&
      other.listLoad == listLoad &&
      other.startup == startup &&
      other.retry == retry &&
      other.save == save &&
      other.selection == selection &&
      other.sinpe == sinpe &&
      other.billers == billers;

  @override
  int get hashCode => Object.hashAll([
    allowedRecipientFilters,
    preferredJurisdiction,
    jurisdictionFilter,
    sepaType,
    searchQuery,
    searchTicket,
    confidentialSepaAvailability,
    accountOwnerName,
    sepaRead,
    recipients == null ? null : Object.hashAll(recipients!),
    totalRecipients,
    loadedPages,
    loadGeneration,
    listLoad,
    startup,
    retry,
    save,
    selection,
    sinpe,
    billers,
  ]);
}

bool _sameRows(List<RecipientViewModel>? a, List<RecipientViewModel>? b) =>
    switch ((a, b)) {
      (null, null) => true,
      (final List<RecipientViewModel> a, final List<RecipientViewModel> b) =>
        listsEqual(a, b),
      (null, List<RecipientViewModel>()) ||
      (List<RecipientViewModel>(), null) => false,
    };
