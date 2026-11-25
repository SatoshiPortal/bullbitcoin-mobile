import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

/// The fund flow (composition §5, Fund column): session → account load →
/// restriction gate → jurisdiction and rail → consent gate → the rail's
/// pre-step → instructions. Every state holds the session it opened with
/// and only the data valid in it.
@immutable
sealed class FundFlowState {
  const FundFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is FundFlowState &&
      other.runtimeType == runtimeType &&
      _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final (x, y) = (a[i], b[i]);
    if (x is List<Object?> && y is List<Object?>) {
      if (!_listEquals(x, y)) return false;
    } else if (x != y) {
      return false;
    }
  }
  return true;
}

/// What every state after the account load and the restriction gate holds.
@immutable
final class FundOpen {
  final ExchangeSession session;
  final FundingAccount account;
  final RestrictionCleared cleared;

  const FundOpen(this.session, this.account, this.cleared);

  @override
  bool operator ==(Object other) =>
      other is FundOpen &&
      other.session == session &&
      other.account == account &&
      other.cleared == cleared;

  @override
  int get hashCode => Object.hash(session, account, cleared);
}

/// Reading the account. Its failure has a Retry; it never falls back to an
/// unrestricted, consent-less default (FUND-3).
final class FundLoading extends FundFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<FundingAccount> load;

  const FundLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// The account may not fund. The only exit is Leave.
final class FundRestricted extends FundFlowState {
  final ExchangeSession session;
  final FundingAccount account;

  const FundRestricted(this.session, this.account);

  @override
  List<Object?> get _props => [session, account];
}

/// The jurisdiction and its rail tiles. [jurisdiction] is null only when the
/// account has no currency this build knows: the user picks one, nothing is
/// preselected. [consent] is set once the gate passed in this flow, so a
/// lagging summary can't ask again (FUND-2, FUND-6).
final class FundPicking extends FundFlowState {
  final FundOpen open;
  final Jurisdiction? jurisdiction;
  final ConsentGiven? consent;

  const FundPicking(this.open, this.jurisdiction, this.consent);

  /// The tiles: the rails of [jurisdiction] this account can use.
  List<FundingRail> get rails => switch (jurisdiction) {
    final jurisdiction? => open.account.railsIn(jurisdiction),
    null => const [],
  };

  @override
  List<Object?> get _props => [open, jurisdiction, consent];
}

/// The consent sheet for [rail]: shown exactly while [gate] is asking,
/// submitting, verifying or failed (FUND-7, FUND-8).
final class FundConsenting extends FundFlowState {
  final FundOpen open;
  final FundingRail rail;
  final ConsentGateState gate;

  const FundConsenting(this.open, this.rail, this.gate);

  @override
  List<Object?> get _props => [open, rail, gate];
}

/// COP pre-step, part 1: the banks of Colombia.
final class FundInstitutions extends FundFlowState {
  final FundOpen open;
  final ConsentGiven consent;

  /// [ContextLoading] or [ContextFailed]; an empty list is
  /// [ReadProblemMissing].
  final ContextLoadState<List<FundingInstitution>> load;

  const FundInstitutions(this.open, this.consent, this.load);

  @override
  List<Object?> get _props => [open, consent, load];
}

/// COP pre-step, part 2: the paying bank and the amount.
final class FundCopInput extends FundFlowState {
  final FundOpen open;
  final ConsentGiven consent;
  final List<FundingInstitution> institutions;

  const FundCopInput(this.open, this.consent, this.institutions);

  @override
  List<Object?> get _props => [open, consent, institutions];
}

/// Confidential SEPA: the virtual IBAN screen, after consent (FUND-4).
final class FundVirtualIban extends FundFlowState {
  final FundOpen open;
  final ConsentGiven consent;

  const FundVirtualIban(this.open, this.consent);

  @override
  List<Object?> get _props => [open, consent];
}

/// Where Back from the instructions goes.
@immutable
sealed class FundOrigin {
  const FundOrigin();
}

final class FundFromPicking extends FundOrigin {
  const FundFromPicking();

  @override
  bool operator ==(Object other) => other is FundFromPicking;

  @override
  int get hashCode => (FundFromPicking).hashCode;
}

final class FundFromCopInput extends FundOrigin {
  final List<FundingInstitution> institutions;

  const FundFromCopInput(this.institutions);

  @override
  bool operator ==(Object other) =>
      other is FundFromCopInput &&
      _listEquals(other.institutions, institutions);

  @override
  int get hashCode => Object.hashAll(institutions);
}

final class FundFromVirtualIban extends FundOrigin {
  const FundFromVirtualIban();

  @override
  bool operator ==(Object other) => other is FundFromVirtualIban;

  @override
  int get hashCode => (FundFromVirtualIban).hashCode;
}

/// The instructions of [request] are being read; the answer must carry the
/// same [attempt] and [request] (FUND-5: the last tap wins).
final class FundFetching extends FundFlowState {
  final FundOpen open;
  final FundingRequest request;
  final FundOrigin origin;
  final int attempt;

  const FundFetching(this.open, this.request, this.origin, this.attempt);

  @override
  List<Object?> get _props => [open, request, origin, attempt];
}

final class FundShowing extends FundFlowState {
  final FundOpen open;
  final FundingRequest request;
  final FundOrigin origin;
  final FundingInstructions instructions;

  const FundShowing(this.open, this.request, this.origin, this.instructions);

  @override
  List<Object?> get _props => [open, request, origin, instructions];
}

/// The exchange refused the rail for this account (e.g. SINPE number not
/// registered). Back only.
final class FundRefused extends FundFlowState {
  final FundOpen open;
  final FundingRequest request;
  final FundOrigin origin;
  final FundingRefusal reason;

  const FundRefused(this.open, this.request, this.origin, this.reason);

  @override
  List<Object?> get _props => [open, request, origin, reason];
}

/// The instructions could not be read. Retry reads again; nothing is shown
/// in their place.
final class FundFetchFailed extends FundFlowState {
  final FundOpen open;
  final FundingRequest request;
  final FundOrigin origin;
  final int attempt;
  final ReadProblem problem;

  const FundFetchFailed(
    this.open,
    this.request,
    this.origin,
    this.attempt,
    this.problem,
  );

  @override
  List<Object?> get _props => [open, request, origin, attempt, problem];
}

/// The session the flow opened with ended. Terminal.
final class FundSessionEnded extends FundFlowState {
  const FundSessionEnded();

  @override
  List<Object?> get _props => const [];
}

/// The user left. Terminal.
final class FundClosed extends FundFlowState {
  const FundClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class FundFlowEvent {
  const FundFlowEvent();
}

final class FundAccountLoaded extends FundFlowEvent {
  final int attempt;
  final ExchangeRead<FundingAccount> read;

  const FundAccountLoaded(this.attempt, this.read);
}

final class FundRetryPressed extends FundFlowEvent {
  const FundRetryPressed();
}

final class FundJurisdictionPicked extends FundFlowEvent {
  final Jurisdiction jurisdiction;

  const FundJurisdictionPicked(this.jurisdiction);
}

final class FundRailPicked extends FundFlowEvent {
  final FundingRail rail;

  const FundRailPicked(this.rail);
}

final class FundConsentAccepted extends FundFlowEvent {
  const FundConsentAccepted();
}

final class FundConsentSubmitted extends FundFlowEvent {
  final int attempt;
  final ExchangeWrite<void> write;

  const FundConsentSubmitted(this.attempt, this.write);
}

final class FundConsentVerified extends FundFlowEvent {
  final int attempt;
  final ExchangeRead<bool> read;

  const FundConsentVerified(this.attempt, this.read);
}

final class FundInstitutionsLoaded extends FundFlowEvent {
  final int attempt;
  final ExchangeRead<List<FundingInstitution>> read;

  const FundInstitutionsLoaded(this.attempt, this.read);
}

final class FundCopSubmitted extends FundFlowEvent {
  final FundingInstitution institution;
  final CopAmount amount;

  const FundCopSubmitted(this.institution, this.amount);
}

final class FundRegularSepaChosen extends FundFlowEvent {
  const FundRegularSepaChosen();
}

final class FundInstructionsLoaded extends FundFlowEvent {
  final int attempt;
  final FundingRequest request;
  final ExchangeRead<FundingAnswer> read;

  const FundInstructionsLoaded(this.attempt, this.request, this.read);
}

/// Back, a dismissed sheet or a popped page.
final class FundBackPressed extends FundFlowEvent {
  const FundBackPressed();
}

final class FundDonePressed extends FundFlowEvent {
  const FundDonePressed();
}

/// The exchange access changed; [session] is the signed-in session, or null.
final class FundSessionChanged extends FundFlowEvent {
  final ExchangeSession? session;

  const FundSessionChanged(this.session);
}

@immutable
sealed class FundFlowEffect {
  const FundFlowEffect();
}

final class FundLoadAccount extends FundFlowEffect {
  final int attempt;

  const FundLoadAccount(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundLoadAccount && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundLoadAccount, attempt);
}

final class FundSubmitConsent extends FundFlowEffect {
  final int attempt;

  const FundSubmitConsent(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundSubmitConsent && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundSubmitConsent, attempt);
}

final class FundVerifyConsent extends FundFlowEffect {
  final int attempt;

  const FundVerifyConsent(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundVerifyConsent && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundVerifyConsent, attempt);
}

final class FundLoadInstitutions extends FundFlowEffect {
  final int attempt;

  const FundLoadInstitutions(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundLoadInstitutions && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundLoadInstitutions, attempt);
}

final class FundFetchInstructions extends FundFlowEffect {
  final int attempt;
  final FundingRequest request;

  const FundFetchInstructions(this.attempt, this.request);

  @override
  bool operator ==(Object other) =>
      other is FundFetchInstructions &&
      other.attempt == attempt &&
      other.request == request;

  @override
  int get hashCode => Object.hash(FundFetchInstructions, attempt, request);
}

typedef FundFlowNext = StepNext<FundFlowState, FundFlowEffect>;

const _ended = FundFlowNext(FundSessionEnded());
const _closed = FundFlowNext(FundClosed());

/// The flow for [session]; without a signed-in session it has ended.
FundFlowNext fundFlowStart(ExchangeSession? session) => switch (session) {
  final session? => FundFlowNext(
    FundLoading(session, const ContextLoading(1)),
    const [FundLoadAccount(1)],
  ),
  null => _ended,
};

FundFlowNext transitionFundFlow(FundFlowState state, FundFlowEvent event) {
  if (event case FundSessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? _ended
        : FundFlowNext.stay(state);
  }
  return switch (state) {
    FundLoading() => _loading(state, event),
    FundRestricted() => _restricted(state, event),
    FundPicking() => _picking(state, event),
    FundConsenting() => _consenting(state, event),
    FundInstitutions() => _institutions(state, event),
    FundCopInput() => _copInput(state, event),
    FundVirtualIban() => _virtualIban(state, event),
    FundFetching() => _fetching(state, event),
    FundShowing() => _showing(state, event),
    FundRefused() => _refused(state, event),
    FundFetchFailed() => _fetchFailed(state, event),
    // The session-ended page's Back and Done leave the flow.
    FundSessionEnded() => switch (event) {
      FundBackPressed() || FundDonePressed() => _closed,
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    },
    FundClosed() => FundFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(FundFlowState state) => switch (state) {
  FundLoading(:final session) || FundRestricted(:final session) => session,
  FundPicking(:final open) ||
  FundConsenting(:final open) ||
  FundInstitutions(:final open) ||
  FundCopInput(:final open) ||
  FundVirtualIban(:final open) ||
  FundFetching(:final open) ||
  FundShowing(:final open) ||
  FundRefused(:final open) ||
  FundFetchFailed(:final open) => open.session,
  FundSessionEnded() || FundClosed() => null,
};

FundFlowNext _loading(FundLoading state, FundFlowEvent event) {
  final ContextLoadEvent<FundingAccount> loadEvent;
  switch (event) {
    case FundAccountLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case FundRetryPressed():
      loadEvent = const ContextRetryPressed();
    case FundBackPressed():
      return _closed;
    case FundJurisdictionPicked() ||
        FundRailPicked() ||
        FundConsentAccepted() ||
        FundConsentSubmitted() ||
        FundConsentVerified() ||
        FundInstitutionsLoaded() ||
        FundCopSubmitted() ||
        FundRegularSepaChosen() ||
        FundInstructionsLoaded() ||
        FundDonePressed() ||
        FundSessionChanged():
      return FundFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return FundFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(context: final account) => _opened(state.session, account),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => FundFlowNext(
      FundLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => FundLoadAccount(attempt),
          },
      ],
    ),
  };
}

FundFlowNext _opened(ExchangeSession session, FundingAccount account) =>
    switch (restrictionGateStart(restricted: account.restricted).state) {
      RestrictionAllowed(:final cleared) => FundFlowNext(
        FundPicking(
          FundOpen(session, account, cleared),
          account.jurisdiction,
          null,
        ),
      ),
      RestrictionRestricted() ||
      RestrictionLeft() => FundFlowNext(FundRestricted(session, account)),
    };

FundFlowNext _restricted(FundRestricted state, FundFlowEvent event) =>
    switch (event) {
      FundBackPressed() || FundDonePressed() => _closed,
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _picking(FundPicking state, FundFlowEvent event) =>
    switch (event) {
      FundJurisdictionPicked(:final jurisdiction)
          when jurisdiction != state.jurisdiction =>
        FundFlowNext(FundPicking(state.open, jurisdiction, state.consent)),
      FundRailPicked(:final rail) when state.rails.contains(rail) =>
        switch (state.consent) {
          final consent? => _afterConsent(state.open, rail, consent),
          null => _askConsent(state.open, rail),
        },
      FundBackPressed() => _closed,
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundDonePressed() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _askConsent(FundOpen open, FundingRail rail) {
  final start = consentGateStart(alreadyGiven: open.account.consented);
  return switch (start.state) {
    ConsentGateGiven(:final given) => _afterConsent(open, rail, given),
    ConsentRequired() ||
    ConsentAsking() ||
    ConsentSubmitting() ||
    ConsentVerifying() ||
    ConsentFailed() ||
    ConsentUnverified() ||
    ConsentDeclined() ||
    ConsentSessionEnded() => _consentNext(
      open,
      rail,
      transitionConsentGate(start.state, const ConsentStartPressed()),
    ),
  };
}

FundFlowNext _consentNext(
  FundOpen open,
  FundingRail rail,
  StepNext<ConsentGateState, ConsentGateEffect> next,
) => switch (next.state) {
  ConsentGateGiven(:final given) => _afterConsent(open, rail, given),
  ConsentDeclined() => FundFlowNext(FundPicking(open, rail.jurisdiction, null)),
  ConsentSessionEnded() => _ended,
  ConsentRequired() ||
  ConsentAsking() ||
  ConsentSubmitting() ||
  ConsentVerifying() ||
  ConsentFailed() ||
  ConsentUnverified() => FundFlowNext(FundConsenting(open, rail, next.state), [
    for (final effect in next.effects)
      switch (effect) {
        ConsentSubmit(:final attempt) => FundSubmitConsent(attempt),
        ConsentVerify(:final attempt) => FundVerifyConsent(attempt),
      },
  ]),
};

/// The rail's pre-step, or its instructions when it has none.
FundFlowNext _afterConsent(
  FundOpen open,
  FundingRail rail,
  ConsentGiven consent,
) => switch (rail) {
  ProcessorCodeFundingRail() => _fetch(
    open,
    ProcessorCodeRequest(
      rail,
      userNumber: open.account.userNumber,
      consent: consent,
    ),
    const FundFromPicking(),
    1,
  ),
  CopBankTransferFundingRail() => FundFlowNext(
    FundInstitutions(open, consent, const ContextLoading(1)),
    const [FundLoadInstitutions(1)],
  ),
  ConfidentialSepaFundingRail() => FundFlowNext(FundVirtualIban(open, consent)),
};

FundFlowNext _fetch(
  FundOpen open,
  FundingRequest request,
  FundOrigin origin,
  int attempt,
) => FundFlowNext(FundFetching(open, request, origin, attempt), [
  FundFetchInstructions(attempt, request),
]);

FundFlowNext _consenting(FundConsenting state, FundFlowEvent event) {
  final ConsentGateEvent gateEvent;
  switch (event) {
    case FundConsentAccepted():
      gateEvent = const ConsentAcceptPressed();
    case FundBackPressed():
      gateEvent = const ConsentDeclinePressed();
    case FundConsentSubmitted(:final attempt, :final write):
      gateEvent = ConsentSubmitted(attempt, write);
    case FundConsentVerified(:final attempt, :final read):
      gateEvent = ConsentVerified(attempt, read);
    case FundRetryPressed():
      gateEvent = const ConsentRetryPressed();
    case FundAccountLoaded() ||
        FundJurisdictionPicked() ||
        FundRailPicked() ||
        FundInstitutionsLoaded() ||
        FundCopSubmitted() ||
        FundRegularSepaChosen() ||
        FundInstructionsLoaded() ||
        FundDonePressed() ||
        FundSessionChanged():
      return FundFlowNext.stay(state);
  }
  final next = transitionConsentGate(state.gate, gateEvent);
  if (identical(next.state, state.gate)) return FundFlowNext.stay(state);
  return _consentNext(state.open, state.rail, next);
}

FundFlowNext _institutions(FundInstitutions state, FundFlowEvent event) {
  final ContextLoadEvent<List<FundingInstitution>> loadEvent;
  switch (event) {
    case FundInstitutionsLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(
        attempt,
        read is ReadGot<List<FundingInstitution>> && read.value.isEmpty
            ? const ReadMissing<List<FundingInstitution>>()
            : read,
      );
    case FundRetryPressed():
      loadEvent = const ContextRetryPressed();
    case FundBackPressed():
      return FundFlowNext(
        FundPicking(
          state.open,
          const CopBankTransferFundingRail().jurisdiction,
          state.consent,
        ),
      );
    case FundAccountLoaded() ||
        FundJurisdictionPicked() ||
        FundRailPicked() ||
        FundConsentAccepted() ||
        FundConsentSubmitted() ||
        FundConsentVerified() ||
        FundCopSubmitted() ||
        FundRegularSepaChosen() ||
        FundInstructionsLoaded() ||
        FundDonePressed() ||
        FundSessionChanged():
      return FundFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return FundFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(context: final institutions) => FundFlowNext(
      FundCopInput(state.open, state.consent, institutions),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => FundFlowNext(
      FundInstitutions(state.open, state.consent, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => FundLoadInstitutions(attempt),
          },
      ],
    ),
  };
}

FundFlowNext _copInput(FundCopInput state, FundFlowEvent event) =>
    switch (event) {
      FundCopSubmitted(:final institution, :final amount)
          when state.institutions.any(
            (listed) => listed.code == institution.code,
          ) =>
        _fetch(
          state.open,
          CopPaymentRequest(
            institution: institution,
            amount: amount,
            consent: state.consent,
          ),
          FundFromCopInput(state.institutions),
          1,
        ),
      FundBackPressed() => FundFlowNext(
        FundPicking(
          state.open,
          const CopBankTransferFundingRail().jurisdiction,
          state.consent,
        ),
      ),
      FundCopSubmitted() ||
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundDonePressed() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _virtualIban(FundVirtualIban state, FundFlowEvent event) =>
    switch (event) {
      FundRegularSepaChosen() => _fetch(
        state.open,
        ProcessorCodeRequest(
          const RegularSepaFundingRail(),
          userNumber: state.open.account.userNumber,
          consent: state.consent,
        ),
        const FundFromVirtualIban(),
        1,
      ),
      FundBackPressed() => FundFlowNext(
        FundPicking(
          state.open,
          const ConfidentialSepaFundingRail().jurisdiction,
          state.consent,
        ),
      ),
      FundDonePressed() => _closed,
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundInstructionsLoaded() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

/// Back from the instructions (or their failure) returns where they were
/// asked from, with the consent kept.
FundFlowNext _back(FundOpen open, FundingRequest request, FundOrigin origin) =>
    switch (origin) {
      FundFromPicking() => FundFlowNext(
        FundPicking(open, request.rail.jurisdiction, request.consent),
      ),
      FundFromCopInput(:final institutions) => FundFlowNext(
        FundCopInput(open, request.consent, institutions),
      ),
      FundFromVirtualIban() => FundFlowNext(
        FundVirtualIban(open, request.consent),
      ),
    };

FundFlowNext _fetching(FundFetching state, FundFlowEvent event) =>
    switch (event) {
      FundInstructionsLoaded(:final attempt, :final request, :final read)
          when attempt == state.attempt && request == state.request =>
        switch (read) {
          ReadGot(value: FundingInstructionsGot(:final instructions)) =>
            FundFlowNext(
              FundShowing(
                state.open,
                state.request,
                state.origin,
                instructions,
              ),
            ),
          ReadGot(value: FundingRefused(:final reason)) => FundFlowNext(
            FundRefused(state.open, state.request, state.origin, reason),
          ),
          ReadSessionRejected() => _ended,
          ReadMissing() || ReadUnreachable() || ReadMalformed() => FundFlowNext(
            FundFetchFailed(
              state.open,
              state.request,
              state.origin,
              state.attempt,
              ReadProblem.of(read)!,
            ),
          ),
        },
      FundBackPressed() => _back(state.open, state.request, state.origin),
      FundInstructionsLoaded() ||
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundDonePressed() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _showing(FundShowing state, FundFlowEvent event) =>
    switch (event) {
      FundBackPressed() => _back(state.open, state.request, state.origin),
      FundDonePressed() => _closed,
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _refused(FundRefused state, FundFlowEvent event) =>
    switch (event) {
      FundBackPressed() => _back(state.open, state.request, state.origin),
      FundAccountLoaded() ||
      FundRetryPressed() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundDonePressed() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };

FundFlowNext _fetchFailed(FundFetchFailed state, FundFlowEvent event) =>
    switch (event) {
      FundRetryPressed() => _fetch(
        state.open,
        state.request,
        state.origin,
        state.attempt + 1,
      ),
      FundBackPressed() => _back(state.open, state.request, state.origin),
      FundAccountLoaded() ||
      FundJurisdictionPicked() ||
      FundRailPicked() ||
      FundConsentAccepted() ||
      FundConsentSubmitted() ||
      FundConsentVerified() ||
      FundInstitutionsLoaded() ||
      FundCopSubmitted() ||
      FundRegularSepaChosen() ||
      FundInstructionsLoaded() ||
      FundDonePressed() ||
      FundSessionChanged() => FundFlowNext.stay(state),
    };
