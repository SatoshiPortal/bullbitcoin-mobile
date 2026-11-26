import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

/// The AutoBuy activation flow (composition §5, AutoBuy column): session →
/// account load → intro (restriction gate) → KYC gate → exchange default
/// wallets editor → review → activation (server confirm of the preference
/// write, verified by re-reading the account) → done.
@immutable
sealed class AutoBuyFlowState {
  const AutoBuyFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is AutoBuyFlowState &&
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
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The account and the open journal entries of AutoBuy writes.
@immutable
final class AutoBuyContext {
  final UserSummary summary;
  final List<UnknownWrite> openEntries;

  const AutoBuyContext(this.summary, this.openEntries);

  bool get isActive => summary.autoBuy.isActive;

  bool get isRestricted => summary.isFundingRestricted;

  /// The market of the account's currency: AutoBuy buys with its balance.
  /// Null when this build has no market for it; the server then decides.
  Market? get market => switch (ExchangeCatalog.parse(summary.currency ?? '')) {
    KnownCurrency(:final market) => market,
    UnknownCurrency() => null,
  };

  @override
  bool operator ==(Object other) =>
      other is AutoBuyContext &&
      other.summary == summary &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(summary, openEntries.length);
}

@immutable
final class AutoBuyOpen {
  final ExchangeSession session;
  final AutoBuyContext context;

  const AutoBuyOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is AutoBuyOpen &&
      other.session == session &&
      other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// The AutoBuy state a write asks for.
@immutable
final class AutoBuyTarget {
  final bool enabled;

  const AutoBuyTarget({required this.enabled});

  @override
  bool operator ==(Object other) =>
      other is AutoBuyTarget && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(AutoBuyTarget, enabled);

  @override
  String toString() => 'AutoBuyTarget($enabled)';
}

String? _noResourceId(AutoBuyTarget _) => null;

/// An AutoBuy switch is a preference write, journaled as a preferences save.
const autoBuyWritePolicy = ServerConfirmPolicy<AutoBuyTarget>(
  writeKind: FinancialWriteKind.preferenceWrite,
  journalKind: UnknownWriteKind.preferencesSave,
  resourceIdOf: _noResourceId,
);

/// The open preference saves that changed AutoBuy: only those start the
/// write in Verifying.
List<UnknownWrite> autoBuyEntries(List<UnknownWrite> entries) => [
  for (final entry in entries)
    if (entry.kind == UnknownWriteKind.preferencesSave &&
        entry.request.containsKey('autoBuyEnabled'))
      entry,
];

/// What a re-read of the account shows about [target].
ConfirmCheck<bool> autoBuyCheck(
  AutoBuyTarget target,
  ExchangeRead<UserSummary> read,
) => switch (read) {
  ReadGot(:final value) when value.autoBuy.isActive == target.enabled =>
    ConfirmSeenApplied(value.autoBuy.isActive),
  ReadGot() => const ConfirmSeenNotApplied(),
  ReadSessionRejected() => const ConfirmCheckSessionRejected(),
  ReadMissing() ||
  ReadUnreachable() ||
  ReadMalformed() => ConfirmCheckFailed(ReadProblem.of(read)!),
};

typedef AutoBuyConfirmState = ServerConfirmState<AutoBuyTarget, bool>;
typedef AutoBuyConfirmEvent = ServerConfirmEvent<AutoBuyTarget, bool>;

const _activate = AutoBuyTarget(enabled: true);

final class AutoBuyLoading extends AutoBuyFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<AutoBuyContext> load;

  const AutoBuyLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// What AutoBuy is. [gate] is the restriction gate: restricted accounts see
/// why and get no way on.
final class AutoBuyIntro extends AutoBuyFlowState {
  final AutoBuyOpen open;

  /// [RestrictionAllowed] or [RestrictionRestricted].
  final RestrictionGateState gate;

  const AutoBuyIntro(this.open, this.gate);

  @override
  List<Object?> get _props => [open, gate];
}

/// The KYC level does not allow buying in the account's market yet.
final class AutoBuyKyc extends AutoBuyFlowState {
  final AutoBuyOpen open;
  final RestrictionCleared cleared;

  /// [KycGateRequired] or [KycGateInKyc].
  final KycGateState kyc;

  const AutoBuyKyc(this.open, this.cleared, this.kyc);

  @override
  List<Object?> get _props => [open, kyc];
}

/// Editing the exchange default wallets AutoBuy pays out to.
final class AutoBuyWallets extends AutoBuyFlowState {
  final AutoBuyOpen open;
  final RestrictionCleared cleared;

  /// Null only when the account's currency has no market in this build.
  final KycCleared? kyc;

  const AutoBuyWallets(this.open, this.cleared, this.kyc);

  @override
  List<Object?> get _props => [open, kyc];
}

/// The wallets AutoBuy will pay to. An account where AutoBuy is already
/// active sees that, with no Activate (AB-2).
final class AutoBuyReview extends AutoBuyFlowState {
  final AutoBuyOpen open;
  final RestrictionCleared cleared;
  final KycCleared? kyc;
  final DefaultWallets wallets;

  const AutoBuyReview(this.open, this.cleared, this.kyc, this.wallets);

  bool get alreadyActive => open.context.isActive;

  @override
  List<Object?> get _props => [open, kyc, wallets];
}

final class AutoBuyActivating extends AutoBuyFlowState {
  final AutoBuyOpen open;
  final RestrictionCleared cleared;
  final KycCleared? kyc;
  final DefaultWallets wallets;

  /// Never [ConfirmConfirmed], [ConfirmSessionEnded] or [ConfirmLeft].
  final AutoBuyConfirmState confirm;

  const AutoBuyActivating(
    this.open,
    this.cleared,
    this.kyc,
    this.wallets,
    this.confirm,
  );

  @override
  List<Object?> get _props => [open, kyc, wallets, confirm];
}

/// The account reports AutoBuy active.
final class AutoBuyDone extends AutoBuyFlowState {
  final AutoBuyOpen open;

  const AutoBuyDone(this.open);

  @override
  List<Object?> get _props => [open];
}

final class AutoBuySessionEnded extends AutoBuyFlowState {
  const AutoBuySessionEnded();

  @override
  List<Object?> get _props => const [];
}

final class AutoBuyClosed extends AutoBuyFlowState {
  const AutoBuyClosed();

  @override
  List<Object?> get _props => const [];
}

@immutable
sealed class AutoBuyFlowEvent {
  const AutoBuyFlowEvent();
}

final class AutoBuyContextLoaded extends AutoBuyFlowEvent {
  final int attempt;
  final ExchangeRead<AutoBuyContext> read;

  const AutoBuyContextLoaded(this.attempt, this.read);
}

final class AutoBuyRetryPressed extends AutoBuyFlowEvent {
  const AutoBuyRetryPressed();
}

final class AutoBuyBackPressed extends AutoBuyFlowEvent {
  const AutoBuyBackPressed();
}

final class AutoBuyDonePressed extends AutoBuyFlowEvent {
  const AutoBuyDonePressed();
}

final class AutoBuyGetStartedPressed extends AutoBuyFlowEvent {
  const AutoBuyGetStartedPressed();
}

/// Back from the KYC web view the KYC page opened.
final class AutoBuyKycReturned extends AutoBuyFlowEvent {
  const AutoBuyKycReturned();
}

/// The account read again after the KYC web view.
final class AutoBuyKycReloaded extends AutoBuyFlowEvent {
  final ExchangeRead<AutoBuyContext> read;

  const AutoBuyKycReloaded(this.read);
}

/// Continue under the editor, with the default wallets it shows saved.
final class AutoBuyWalletsContinued extends AutoBuyFlowEvent {
  final DefaultWallets wallets;

  const AutoBuyWalletsContinued(this.wallets);
}

final class AutoBuyActivatePressed extends AutoBuyFlowEvent {
  const AutoBuyActivatePressed();
}

final class AutoBuyConfirmChanged extends AutoBuyFlowEvent {
  final AutoBuyConfirmEvent event;

  const AutoBuyConfirmChanged(this.event);
}

final class AutoBuySessionChanged extends AutoBuyFlowEvent {
  final ExchangeSession? session;

  const AutoBuySessionChanged(this.session);
}

@immutable
sealed class AutoBuyFlowEffect {
  const AutoBuyFlowEffect();
}

final class AutoBuyLoadContext extends AutoBuyFlowEffect {
  final int attempt;

  const AutoBuyLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is AutoBuyLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(AutoBuyLoadContext, attempt);
}

/// Read the account again after KYC; answer [AutoBuyKycReloaded].
final class AutoBuyReloadForKyc extends AutoBuyFlowEffect {
  const AutoBuyReloadForKyc();

  @override
  bool operator ==(Object other) => other is AutoBuyReloadForKyc;

  @override
  int get hashCode => (AutoBuyReloadForKyc).hashCode;
}

final class AutoBuyConfirmEffect extends AutoBuyFlowEffect {
  final ServerConfirmEffect<AutoBuyTarget> effect;

  const AutoBuyConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is AutoBuyConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(AutoBuyConfirmEffect, effect);
}

typedef AutoBuyFlowNext = StepNext<AutoBuyFlowState, AutoBuyFlowEffect>;

const _ended = AutoBuyFlowNext(AutoBuySessionEnded());
const _closed = AutoBuyFlowNext(AutoBuyClosed());

AutoBuyFlowNext autoBuyFlowStart(ExchangeSession? session) => switch (session) {
  final session? => AutoBuyFlowNext(
    AutoBuyLoading(session, const ContextLoading(1)),
    const [AutoBuyLoadContext(1)],
  ),
  null => _ended,
};

AutoBuyFlowNext transitionAutoBuyFlow(
  AutoBuyFlowState state,
  AutoBuyFlowEvent event,
) {
  if (event case AutoBuySessionChanged(:final session)) {
    final current = _sessionOf(state);
    return current != null && current != session
        ? _ended
        : AutoBuyFlowNext.stay(state);
  }
  return switch (state) {
    AutoBuyLoading() => _loading(state, event),
    AutoBuyIntro() => _intro(state, event),
    AutoBuyKyc() => _kyc(state, event),
    AutoBuyWallets() => _wallets(state, event),
    AutoBuyReview() => _review(state, event),
    AutoBuyActivating() => _activating(state, event),
    AutoBuyDone() || AutoBuySessionEnded() => _end(state, event),
    AutoBuyClosed() => AutoBuyFlowNext.stay(state),
  };
}

ExchangeSession? _sessionOf(AutoBuyFlowState state) => switch (state) {
  AutoBuyLoading(:final session) => session,
  AutoBuyIntro(:final open) ||
  AutoBuyKyc(:final open) ||
  AutoBuyWallets(:final open) ||
  AutoBuyReview(:final open) ||
  AutoBuyActivating(:final open) ||
  AutoBuyDone(:final open) => open.session,
  AutoBuySessionEnded() || AutoBuyClosed() => null,
};

AutoBuyFlowNext _introOf(AutoBuyOpen open) => AutoBuyFlowNext(
  AutoBuyIntro(
    open,
    restrictionGateStart(restricted: open.context.isRestricted).state,
  ),
);

AutoBuyFlowNext _loading(AutoBuyLoading state, AutoBuyFlowEvent event) {
  final ContextLoadEvent<AutoBuyContext> loadEvent;
  switch (event) {
    case AutoBuyContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case AutoBuyRetryPressed():
      loadEvent = const ContextRetryPressed();
    case AutoBuyBackPressed() || AutoBuyDonePressed():
      return _closed;
    case AutoBuyGetStartedPressed() ||
        AutoBuyKycReturned() ||
        AutoBuyKycReloaded() ||
        AutoBuyWalletsContinued() ||
        AutoBuyActivatePressed() ||
        AutoBuyConfirmChanged() ||
        AutoBuySessionChanged():
      return AutoBuyFlowNext.stay(state);
  }
  final next = transitionContextLoad(state.load, loadEvent);
  if (identical(next.state, state.load)) return AutoBuyFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _introOf(
      AutoBuyOpen(state.session, context),
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => AutoBuyFlowNext(
      AutoBuyLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => AutoBuyLoadContext(attempt),
          },
      ],
    ),
  };
}

/// Past the restriction gate: the KYC gate for the account's market, then
/// the wallets.
AutoBuyFlowNext _kycNext(
  AutoBuyOpen open,
  RestrictionCleared cleared,
  KycGateState kyc,
) => switch (kyc) {
  KycGatePassed(cleared: final passed) => AutoBuyFlowNext(
    AutoBuyWallets(open, cleared, passed),
  ),
  KycGateLeft() => _introOf(open),
  KycGateRequired() ||
  KycGateInKyc() => AutoBuyFlowNext(AutoBuyKyc(open, cleared, kyc)),
};

AutoBuyFlowNext _intro(
  AutoBuyIntro state,
  AutoBuyFlowEvent event,
) => switch (event) {
  AutoBuyGetStartedPressed() => switch (state.gate) {
    RestrictionAllowed(:final cleared) => switch (state.open.context.market) {
      final market? => _kycNext(
        state.open,
        cleared,
        kycGateStart(market, state.open.context.summary.kycGroups).state,
      ),
      null => AutoBuyFlowNext(AutoBuyWallets(state.open, cleared, null)),
    },
    RestrictionRestricted() || RestrictionLeft() => AutoBuyFlowNext.stay(state),
  },
  AutoBuyBackPressed() => _closed,
  AutoBuyContextLoaded() ||
  AutoBuyRetryPressed() ||
  AutoBuyDonePressed() ||
  AutoBuyKycReturned() ||
  AutoBuyKycReloaded() ||
  AutoBuyWalletsContinued() ||
  AutoBuyActivatePressed() ||
  AutoBuyConfirmChanged() ||
  AutoBuySessionChanged() => AutoBuyFlowNext.stay(state),
};

AutoBuyFlowNext _kyc(AutoBuyKyc state, AutoBuyFlowEvent event) {
  switch (event) {
    case AutoBuyKycReturned():
      final next = transitionKycGate(state.kyc, const KycGateOpenPressed());
      return switch (next.state) {
        final KycGateInKyc inKyc => AutoBuyFlowNext(
          AutoBuyKyc(state.open, state.cleared, inKyc),
          const [AutoBuyReloadForKyc()],
        ),
        KycGateRequired() ||
        KycGatePassed() ||
        KycGateLeft() => AutoBuyFlowNext.stay(state),
      };
    case AutoBuyKycReloaded(:final read):
      return switch ((state.kyc, read)) {
        (KycGateInKyc(), ReadGot(value: final context)) => _kycNext(
          AutoBuyOpen(state.open.session, context),
          state.cleared,
          transitionKycGate(
            state.kyc,
            KycGateReturned(context.summary.kycGroups),
          ).state,
        ),
        (KycGateInKyc(), ReadSessionRejected()) => _ended,
        // The read failed: the account is checked again on the next return.
        (
          KycGateInKyc(:final market, :final amount),
          ReadMissing() || ReadUnreachable() || ReadMalformed(),
        ) =>
          AutoBuyFlowNext(
            AutoBuyKyc(
              state.open,
              state.cleared,
              KycGateRequired(market, amount: amount),
            ),
          ),
        (
          KycGateRequired() || KycGatePassed() || KycGateLeft(),
          ReadGot() ||
              ReadSessionRejected() ||
              ReadMissing() ||
              ReadUnreachable() ||
              ReadMalformed(),
        ) =>
          AutoBuyFlowNext.stay(state),
      };
    case AutoBuyBackPressed():
      return _introOf(state.open);
    case AutoBuyContextLoaded() ||
        AutoBuyRetryPressed() ||
        AutoBuyDonePressed() ||
        AutoBuyGetStartedPressed() ||
        AutoBuyWalletsContinued() ||
        AutoBuyActivatePressed() ||
        AutoBuyConfirmChanged() ||
        AutoBuySessionChanged():
      return AutoBuyFlowNext.stay(state);
  }
}

AutoBuyFlowNext _wallets(AutoBuyWallets state, AutoBuyFlowEvent event) =>
    switch (event) {
      AutoBuyWalletsContinued(:final wallets) when wallets.hasAnyWallet =>
        AutoBuyFlowNext(
          AutoBuyReview(state.open, state.cleared, state.kyc, wallets),
        ),
      AutoBuyBackPressed() => _introOf(state.open),
      AutoBuyWalletsContinued() ||
      AutoBuyContextLoaded() ||
      AutoBuyRetryPressed() ||
      AutoBuyDonePressed() ||
      AutoBuyGetStartedPressed() ||
      AutoBuyKycReturned() ||
      AutoBuyKycReloaded() ||
      AutoBuyActivatePressed() ||
      AutoBuyConfirmChanged() ||
      AutoBuySessionChanged() => AutoBuyFlowNext.stay(state),
    };

AutoBuyFlowNext _review(AutoBuyReview state, AutoBuyFlowEvent event) =>
    switch (event) {
      AutoBuyActivatePressed() when !state.alreadyActive => _activatingNext(
        state.open,
        state.cleared,
        state.kyc,
        state.wallets,
        serverConfirmStart<AutoBuyTarget, bool>(
          _activate,
          openEntry: openEntryFor(
            autoBuyWritePolicy,
            _activate,
            autoBuyEntries(state.open.context.openEntries),
          ),
        ),
      ),
      AutoBuyDonePressed() when state.alreadyActive => _closed,
      AutoBuyBackPressed() => AutoBuyFlowNext(
        AutoBuyWallets(state.open, state.cleared, state.kyc),
      ),
      AutoBuyActivatePressed() ||
      AutoBuyDonePressed() ||
      AutoBuyContextLoaded() ||
      AutoBuyRetryPressed() ||
      AutoBuyGetStartedPressed() ||
      AutoBuyKycReturned() ||
      AutoBuyKycReloaded() ||
      AutoBuyWalletsContinued() ||
      AutoBuyConfirmChanged() ||
      AutoBuySessionChanged() => AutoBuyFlowNext.stay(state),
    };

AutoBuyFlowNext _activatingNext(
  AutoBuyOpen open,
  RestrictionCleared cleared,
  KycCleared? kyc,
  DefaultWallets wallets,
  ServerConfirmNext<AutoBuyTarget, bool> next,
) => switch (next.state) {
  ConfirmConfirmed() => AutoBuyFlowNext(AutoBuyDone(open)),
  ConfirmSessionEnded() => _ended,
  // Nothing in flight; a second activation asks for the same state.
  ConfirmLeft() => AutoBuyFlowNext(AutoBuyReview(open, cleared, kyc, wallets)),
  ConfirmConfirming() ||
  ConfirmWriteRefused() ||
  ConfirmFailed() ||
  ConfirmVerifying() ||
  ConfirmUnverified() => AutoBuyFlowNext(
    AutoBuyActivating(open, cleared, kyc, wallets, next.state),
    [for (final effect in next.effects) AutoBuyConfirmEffect(effect)],
  ),
};

AutoBuyFlowNext _activating(AutoBuyActivating state, AutoBuyFlowEvent event) {
  final AutoBuyConfirmEvent stepEvent;
  switch (event) {
    case AutoBuyConfirmChanged(:final event):
      stepEvent = event;
    case AutoBuyActivatePressed():
      stepEvent = const ConfirmCommitPressed();
    case AutoBuyRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case AutoBuyBackPressed():
      stepEvent = const ConfirmBackPressed();
    case AutoBuyContextLoaded() ||
        AutoBuyDonePressed() ||
        AutoBuyGetStartedPressed() ||
        AutoBuyKycReturned() ||
        AutoBuyKycReloaded() ||
        AutoBuyWalletsContinued() ||
        AutoBuySessionChanged():
      return AutoBuyFlowNext.stay(state);
  }
  final next = transitionServerConfirm(
    autoBuyWritePolicy,
    state.confirm,
    stepEvent,
  );
  if (identical(next.state, state.confirm) && next.effects.isEmpty) {
    return AutoBuyFlowNext.stay(state);
  }
  return _activatingNext(
    state.open,
    state.cleared,
    state.kyc,
    state.wallets,
    next,
  );
}

AutoBuyFlowNext _end(AutoBuyFlowState state, AutoBuyFlowEvent event) =>
    switch (event) {
      AutoBuyDonePressed() || AutoBuyBackPressed() => _closed,
      AutoBuyContextLoaded() ||
      AutoBuyRetryPressed() ||
      AutoBuyGetStartedPressed() ||
      AutoBuyKycReturned() ||
      AutoBuyKycReloaded() ||
      AutoBuyWalletsContinued() ||
      AutoBuyActivatePressed() ||
      AutoBuyConfirmChanged() ||
      AutoBuySessionChanged() => AutoBuyFlowNext.stay(state),
    };
