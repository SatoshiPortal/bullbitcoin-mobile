import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../domain/exchange_page.dart';
import '../payout/payout_rail.dart';
import '../payout/recipient_choice.dart';
import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/entities/recipient_details.dart';
import '../recipients/domain/entities/recipient_details_input.dart';
import 'recipient_pick_effect.dart';
import 'recipient_pick_event.dart';
import 'step_next.dart';

/// What the recipient list shows: the rails it lists (a subset of the
/// filter's, e.g. one jurisdiction or one SEPA kind) and the search text.
@immutable
final class RecipientQuery {
  final List<PayoutRail> rails;
  final String search;

  const RecipientQuery({required this.rails, this.search = ''});

  @override
  bool operator ==(Object other) =>
      other is RecipientQuery &&
      other.search == search &&
      _same(other.rails, rails);

  @override
  int get hashCode => Object.hash(Object.hashAll(rails), search);

  @override
  String toString() => 'RecipientQuery(${rails.length} rails, "$search")';
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
  }
  return true;
}

/// Why the new-recipient form is shown again.
@immutable
sealed class RecipientCreateProblem {
  const RecipientCreateProblem();
}

/// The form's values don't make a recipient of the rail (form and domain
/// validation drifted apart). Not sent.
final class RecipientInputInvalid extends RecipientCreateProblem {
  const RecipientInputInvalid();

  @override
  bool operator ==(Object other) => other is RecipientInputInvalid;

  @override
  int get hashCode => (RecipientInputInvalid).hashCode;
}

/// The save was refused, never sent, or (after an unknown outcome) not
/// found: saving again can't make a duplicate.
final class RecipientSaveFailed extends RecipientCreateProblem {
  final WriteProblem problem;

  const RecipientSaveFailed(this.problem);

  @override
  bool operator ==(Object other) =>
      other is RecipientSaveFailed && other.problem == problem;

  @override
  int get hashCode => Object.hash(RecipientSaveFailed, problem);
}

/// The recipient pick step (composition §4.4): a list under one query, a
/// form per rail, and a picked recipient as the only way out. Every state
/// keeps the query and the id of the last effect it started ([attempt]);
/// an answer for another id is a stay.
@immutable
sealed class RecipientPickState {
  final RecipientQuery query;
  final int attempt;

  const RecipientPickState(this.query, this.attempt);

  RecipientPickNext next(RecipientFilter filter, RecipientPickEvent event) {
    final state = this;
    return switch (state) {
      final RecipientPickLoading s => _fromLoading(filter, s, event),
      final RecipientPickLoadFailed s => _fromListFailed(filter, s, event),
      final RecipientPickBrowsing s => _fromBrowsing(filter, s, event),
      final RecipientPickLoadingMore s => _fromLoadingMore(filter, s, event),
      final RecipientPickMoreFailed s => _fromMoreFailed(filter, s, event),
      final RecipientPickCreating s => _fromCreating(filter, s, event),
      final RecipientPickSaving s => _fromSaving(filter, s, event),
      final RecipientPickVerifying s => _fromVerifying(filter, s, event),
      final RecipientPickUnverified s => _fromUnverified(filter, s, event),
      RecipientPickPicked() ||
      RecipientPickNotAdmitted() => _fromDone(filter, state, event),
      RecipientPickSessionEnded() => StepNext.stay(state),
    };
  }
}

final class RecipientPickLoading extends RecipientPickState {
  const RecipientPickLoading(super.query, super.attempt);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickLoading &&
      other.query == query &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(RecipientPickLoading, query, attempt);

  @override
  String toString() => 'RecipientPickLoading($attempt)';
}

final class RecipientPickLoadFailed extends RecipientPickState {
  final ReadProblem problem;

  const RecipientPickLoadFailed(super.query, super.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickLoadFailed &&
      other.query == query &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(RecipientPickLoadFailed, query, attempt, problem);

  @override
  String toString() => 'RecipientPickLoadFailed($attempt, $problem)';
}

/// The loaded pages; [nextPage] is the next page number, or null on the last.
final class RecipientPickBrowsing extends RecipientPickState {
  final List<Recipient> items;
  final int? nextPage;

  const RecipientPickBrowsing(
    super.query,
    super.attempt,
    this.items,
    this.nextPage,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickBrowsing &&
      other.query == query &&
      other.attempt == attempt &&
      other.nextPage == nextPage &&
      _same(other.items, items);

  @override
  int get hashCode => Object.hash(
    RecipientPickBrowsing,
    query,
    attempt,
    nextPage,
    Object.hashAll(items),
  );

  @override
  String toString() =>
      'RecipientPickBrowsing($attempt, ${items.length}, next $nextPage)';
}

final class RecipientPickLoadingMore extends RecipientPickState {
  final List<Recipient> items;
  final int page;

  const RecipientPickLoadingMore(
    super.query,
    super.attempt,
    this.items,
    this.page,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickLoadingMore &&
      other.query == query &&
      other.attempt == attempt &&
      other.page == page &&
      _same(other.items, items);

  @override
  int get hashCode => Object.hash(
    RecipientPickLoadingMore,
    query,
    attempt,
    page,
    Object.hashAll(items),
  );

  @override
  String toString() => 'RecipientPickLoadingMore($attempt, page $page)';
}

/// A later page failed; the loaded ones stay usable.
final class RecipientPickMoreFailed extends RecipientPickState {
  final List<Recipient> items;
  final int page;
  final ReadProblem problem;

  const RecipientPickMoreFailed(
    super.query,
    super.attempt,
    this.items,
    this.page,
    this.problem,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickMoreFailed &&
      other.query == query &&
      other.attempt == attempt &&
      other.page == page &&
      other.problem == problem &&
      _same(other.items, items);

  @override
  int get hashCode => Object.hash(
    RecipientPickMoreFailed,
    query,
    attempt,
    page,
    problem,
    Object.hashAll(items),
  );

  @override
  String toString() =>
      'RecipientPickMoreFailed($attempt, page $page, $problem)';
}

/// The new-recipient form of [rail].
final class RecipientPickCreating extends RecipientPickState {
  final PayoutRail rail;
  final RecipientCreateProblem? problem;

  const RecipientPickCreating(
    super.query,
    super.attempt,
    this.rail, [
    this.problem,
  ]);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickCreating &&
      other.query == query &&
      other.attempt == attempt &&
      other.rail == rail &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(RecipientPickCreating, query, attempt, rail, problem);

  @override
  String toString() => 'RecipientPickCreating($attempt, $rail, $problem)';
}

final class RecipientPickSaving extends RecipientPickState {
  final PayoutRail rail;
  final RecipientDetails details;

  const RecipientPickSaving(
    super.query,
    super.attempt,
    this.rail,
    this.details,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickSaving &&
      other.query == query &&
      other.attempt == attempt &&
      other.rail == rail &&
      identical(other.details, details);

  @override
  int get hashCode => Object.hash(RecipientPickSaving, query, attempt, rail);

  @override
  String toString() => 'RecipientPickSaving($attempt, $rail)';
}

/// The save may have reached the exchange: the list is read again for a
/// recipient with the same account, never saved again.
final class RecipientPickVerifying extends RecipientPickState {
  final PayoutRail rail;
  final RecipientDetails details;

  const RecipientPickVerifying(
    super.query,
    super.attempt,
    this.rail,
    this.details,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickVerifying &&
      other.query == query &&
      other.attempt == attempt &&
      other.rail == rail &&
      identical(other.details, details);

  @override
  int get hashCode => Object.hash(RecipientPickVerifying, query, attempt, rail);

  @override
  String toString() => 'RecipientPickVerifying($attempt, $rail)';
}

/// The re-read failed; Retry reads again, Back shows the list.
final class RecipientPickUnverified extends RecipientPickState {
  final PayoutRail rail;
  final RecipientDetails details;
  final ReadProblem problem;

  const RecipientPickUnverified(
    super.query,
    super.attempt,
    this.rail,
    this.details,
    this.problem,
  );

  @override
  bool operator ==(Object other) =>
      other is RecipientPickUnverified &&
      other.query == query &&
      other.attempt == attempt &&
      other.rail == rail &&
      other.problem == problem &&
      identical(other.details, details);

  @override
  int get hashCode =>
      Object.hash(RecipientPickUnverified, query, attempt, rail, problem);

  @override
  String toString() => 'RecipientPickUnverified($attempt, $rail, $problem)';
}

/// Output.
final class RecipientPickPicked extends RecipientPickState {
  final ChosenRecipient chosen;

  /// Whether the recipient was created in this step.
  final bool isNew;

  const RecipientPickPicked(
    super.query,
    super.attempt,
    this.chosen, {
    required this.isNew,
  });

  @override
  bool operator ==(Object other) =>
      other is RecipientPickPicked &&
      other.query == query &&
      other.attempt == attempt &&
      other.chosen == chosen &&
      other.isNew == isNew;

  @override
  int get hashCode =>
      Object.hash(RecipientPickPicked, query, attempt, chosen, isNew);

  @override
  String toString() => 'RecipientPickPicked($chosen, new: $isNew)';
}

/// Saved, but the exchange returned it with an owner or rail the flow's
/// filter doesn't admit: it is in the user's list, not usable here.
final class RecipientPickNotAdmitted extends RecipientPickState {
  final Recipient saved;

  const RecipientPickNotAdmitted(super.query, super.attempt, this.saved);

  @override
  bool operator ==(Object other) =>
      other is RecipientPickNotAdmitted &&
      other.query == query &&
      other.attempt == attempt &&
      identical(other.saved, saved);

  @override
  int get hashCode => Object.hash(RecipientPickNotAdmitted, query, attempt);

  @override
  String toString() => 'RecipientPickNotAdmitted($attempt)';
}

/// A call got HTTP 401. Terminal; the flow ends its session.
final class RecipientPickSessionEnded extends RecipientPickState {
  const RecipientPickSessionEnded(super.query, super.attempt);

  @override
  bool operator ==(Object other) => other is RecipientPickSessionEnded;

  @override
  int get hashCode => (RecipientPickSessionEnded).hashCode;
}

typedef RecipientPickNext = StepNext<RecipientPickState, RecipientPickEffect>;

RecipientPickNext _load(
  RecipientFilter filter,
  RecipientQuery query,
  int attempt,
) => StepNext(RecipientPickLoading(query, attempt), [
  RecipientPickFetchPage(query, filter.owner, 1, attempt),
]);

/// Starts on the first page of [query], or of every rail of [filter].
RecipientPickNext recipientPickStart(
  RecipientFilter filter, {
  RecipientQuery? query,
}) => _load(filter, query ?? RecipientQuery(rails: filter.rails), 1);

/// The query, kept to the filter's rails.
RecipientQuery _within(RecipientFilter filter, RecipientQuery query) =>
    RecipientQuery(
      rails: [
        for (final rail in query.rails)
          if (filter.rails.contains(rail)) rail,
      ],
      search: query.search,
    );

RecipientPickNext _paged(
  RecipientFilter filter,
  RecipientPickState state,
  List<Recipient> before,
  int page,
  Result<ExchangePage<Recipient>, ExchangeListFailure> answer,
) => switch (answer) {
  Ok(value: ExchangePage(:final items, :final next)) => StepNext(
    RecipientPickBrowsing(state.query, state.attempt, [
      ...before,
      ...items,
    ], next),
  ),
  Err(failure: ExchangeUnreachableFailure(:final isNetwork)) => StepNext(
    page == 1
        ? RecipientPickLoadFailed(
            state.query,
            state.attempt,
            ReadProblemUnreachable(isNetwork: isNetwork),
          )
        : RecipientPickMoreFailed(
            state.query,
            state.attempt,
            before,
            page,
            ReadProblemUnreachable(isNetwork: isNetwork),
          ),
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    RecipientPickSessionEnded(state.query, state.attempt),
  ),
};

/// The recipient the exchange saved (or the re-read found) for [rail]:
/// picked when the filter admits it on that rail.
RecipientPickNext _saved(
  RecipientFilter filter,
  RecipientPickState state,
  PayoutRail rail,
  Recipient saved,
) {
  final adopted = rail.adopt(saved);
  final chosen = adopted == null ? null : filter.choose(adopted);
  return StepNext(
    chosen == null
        ? RecipientPickNotAdmitted(state.query, state.attempt, saved)
        : RecipientPickPicked(state.query, state.attempt, chosen, isNew: true),
  );
}

RecipientPickNext _new(
  RecipientFilter filter,
  RecipientPickState state,
  PayoutRail rail,
) => filter.rails.contains(rail)
    ? StepNext(RecipientPickCreating(state.query, state.attempt, rail))
    : StepNext.stay(state);

RecipientPickNext _select(
  RecipientFilter filter,
  RecipientPickState state,
  List<Recipient> items,
  Recipient recipient,
) {
  final listed = items.any((item) => item.recipientId == recipient.recipientId);
  final chosen = listed ? filter.choose(recipient) : null;
  return chosen == null
      ? StepNext.stay(state)
      : StepNext(
          RecipientPickPicked(state.query, state.attempt, chosen, isNew: false),
        );
}

RecipientPickNext _requery(
  RecipientFilter filter,
  RecipientPickState state,
  RecipientQuery query,
) => _load(filter, _within(filter, query), state.attempt + 1);

RecipientPickNext _reload(RecipientFilter filter, RecipientPickState state) =>
    _load(filter, state.query, state.attempt + 1);

RecipientPickNext _submit(
  RecipientFilter filter,
  RecipientPickCreating creating,
  RecipientDetailsInput input,
) {
  if (input.recipientType != creating.rail.type) {
    return StepNext.stay(creating);
  }
  final owned = switch (filter.owner) {
    null => input,
    final RecipientOwnership owner => input.withOwner(owner.isOwner),
  };
  return switch (owned.tryToDomain()) {
    final RecipientDetails details => StepNext(
      RecipientPickSaving(
        creating.query,
        creating.attempt + 1,
        creating.rail,
        details,
      ),
      [RecipientPickSave(details, creating.attempt + 1)],
    ),
    null => StepNext(
      RecipientPickCreating(
        creating.query,
        creating.attempt,
        creating.rail,
        const RecipientInputInvalid(),
      ),
    ),
  };
}

RecipientPickNext _onSave(
  RecipientFilter filter,
  RecipientPickSaving saving,
  Result<Recipient, ExchangeWriteFailure> write,
) => switch (write) {
  Ok(value: final saved) => _saved(filter, saving, saving.rail, saved),
  Err(failure: ExchangeWriteRefusedFailure(:final reason)) => StepNext(
    RecipientPickCreating(
      saving.query,
      saving.attempt,
      saving.rail,
      RecipientSaveFailed(WriteProblemRefused(reason)),
    ),
  ),
  Err(failure: ExchangeWriteNotSentFailure(:final reason)) => StepNext(
    RecipientPickCreating(
      saving.query,
      saving.attempt,
      saving.rail,
      RecipientSaveFailed(WriteProblemNotSent(reason)),
    ),
  ),
  Err(failure: ExchangeWriteOutcomeUnknownFailure()) => StepNext(
    RecipientPickVerifying(
      saving.query,
      saving.attempt + 1,
      saving.rail,
      saving.details,
    ),
    [RecipientPickFind(saving.details, saving.attempt + 1)],
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    RecipientPickSessionEnded(saving.query, saving.attempt),
  ),
};

RecipientPickNext _onFound(
  RecipientFilter filter,
  RecipientPickVerifying verifying,
  Result<Recipient, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: final saved) => _saved(filter, verifying, verifying.rail, saved),
  Err(failure: ExchangeMissingFailure()) => StepNext(
    RecipientPickCreating(
      verifying.query,
      verifying.attempt,
      verifying.rail,
      const RecipientSaveFailed(WriteProblemNotApplied()),
    ),
  ),
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(failure: ExchangeMalformedFailure()) => StepNext(
    RecipientPickUnverified(
      verifying.query,
      verifying.attempt,
      verifying.rail,
      verifying.details,
      ReadProblem.of(read)!,
    ),
  ),
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    RecipientPickSessionEnded(verifying.query, verifying.attempt),
  ),
};

RecipientPickNext _fromLoading(
  RecipientFilter filter,
  RecipientPickLoading state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickPageLoaded(:final attempt, :final page)
      when attempt == state.attempt =>
    _paged(filter, state, const [], 1, page),
  RecipientPickQueryChanged(:final query) => _requery(filter, state, query),
  RecipientPickNewPressed(:final rail) => _new(filter, state, rail),
  RecipientPickPageLoaded() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSelected() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromListFailed(
  RecipientFilter filter,
  RecipientPickLoadFailed state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickRetryPressed() => _reload(filter, state),
  RecipientPickQueryChanged(:final query) => _requery(filter, state, query),
  RecipientPickNewPressed(:final rail) => _new(filter, state, rail),
  RecipientPickPageLoaded() ||
  RecipientPickMoreRequested() ||
  RecipientPickSelected() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromBrowsing(
  RecipientFilter filter,
  RecipientPickBrowsing state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickMoreRequested() => switch (state.nextPage) {
    null => StepNext.stay(state),
    final int page => StepNext(
      RecipientPickLoadingMore(
        state.query,
        state.attempt + 1,
        state.items,
        page,
      ),
      [
        RecipientPickFetchPage(
          state.query,
          filter.owner,
          page,
          state.attempt + 1,
        ),
      ],
    ),
  },
  RecipientPickSelected(:final recipient) => _select(
    filter,
    state,
    state.items,
    recipient,
  ),
  RecipientPickQueryChanged(:final query) => _requery(filter, state, query),
  RecipientPickNewPressed(:final rail) => _new(filter, state, rail),
  RecipientPickRetryPressed() => _reload(filter, state),
  RecipientPickPageLoaded() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromLoadingMore(
  RecipientFilter filter,
  RecipientPickLoadingMore state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickPageLoaded(:final attempt, :final page)
      when attempt == state.attempt =>
    _paged(filter, state, state.items, state.page, page),
  RecipientPickSelected(:final recipient) => _select(
    filter,
    state,
    state.items,
    recipient,
  ),
  RecipientPickQueryChanged(:final query) => _requery(filter, state, query),
  RecipientPickNewPressed(:final rail) => _new(filter, state, rail),
  RecipientPickPageLoaded() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromMoreFailed(
  RecipientFilter filter,
  RecipientPickMoreFailed state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickRetryPressed() || RecipientPickMoreRequested() => StepNext(
    RecipientPickLoadingMore(
      state.query,
      state.attempt + 1,
      state.items,
      state.page,
    ),
    [
      RecipientPickFetchPage(
        state.query,
        filter.owner,
        state.page,
        state.attempt + 1,
      ),
    ],
  ),
  RecipientPickSelected(:final recipient) => _select(
    filter,
    state,
    state.items,
    recipient,
  ),
  RecipientPickQueryChanged(:final query) => _requery(filter, state, query),
  RecipientPickNewPressed(:final rail) => _new(filter, state, rail),
  RecipientPickPageLoaded() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromCreating(
  RecipientFilter filter,
  RecipientPickCreating state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickSubmitted(:final input) => _submit(filter, state, input),
  RecipientPickNewPressed(:final rail) when rail != state.rail => _new(
    filter,
    state,
    rail,
  ),
  RecipientPickBackPressed() => _reload(filter, state),
  RecipientPickPageLoaded() ||
  RecipientPickQueryChanged() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSelected() ||
  RecipientPickNewPressed() ||
  RecipientPickSaved() ||
  RecipientPickFound() => StepNext.stay(state),
};

RecipientPickNext _fromSaving(
  RecipientFilter filter,
  RecipientPickSaving state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickSaved(:final attempt, :final write)
      when attempt == state.attempt =>
    _onSave(filter, state, write),
  RecipientPickPageLoaded() ||
  RecipientPickQueryChanged() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSelected() ||
  RecipientPickNewPressed() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromVerifying(
  RecipientFilter filter,
  RecipientPickVerifying state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickFound(:final attempt, :final read)
      when attempt == state.attempt =>
    _onFound(filter, state, read),
  RecipientPickPageLoaded() ||
  RecipientPickQueryChanged() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSelected() ||
  RecipientPickNewPressed() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() ||
  RecipientPickBackPressed() => StepNext.stay(state),
};

RecipientPickNext _fromUnverified(
  RecipientFilter filter,
  RecipientPickUnverified state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickRetryPressed() => StepNext(
    RecipientPickVerifying(
      state.query,
      state.attempt + 1,
      state.rail,
      state.details,
    ),
    [RecipientPickFind(state.details, state.attempt + 1)],
  ),
  RecipientPickBackPressed() => _reload(filter, state),
  RecipientPickPageLoaded() ||
  RecipientPickQueryChanged() ||
  RecipientPickMoreRequested() ||
  RecipientPickSelected() ||
  RecipientPickNewPressed() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() => StepNext.stay(state),
};

/// Back shows the list again, read afresh so a new recipient is in it.
RecipientPickNext _fromDone(
  RecipientFilter filter,
  RecipientPickState state,
  RecipientPickEvent event,
) => switch (event) {
  RecipientPickBackPressed() => _reload(filter, state),
  RecipientPickPageLoaded() ||
  RecipientPickQueryChanged() ||
  RecipientPickMoreRequested() ||
  RecipientPickRetryPressed() ||
  RecipientPickSelected() ||
  RecipientPickNewPressed() ||
  RecipientPickSubmitted() ||
  RecipientPickSaved() ||
  RecipientPickFound() => StepNext.stay(state),
};
