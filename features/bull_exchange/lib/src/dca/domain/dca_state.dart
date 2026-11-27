import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'dca_effect.dart';
import 'dca_event.dart';

/// The recurring buy (composition §5, DCA): session → account and exchange
/// default wallets → amount and frequency (funding detour back to the same
/// draft) → payout (an exchange default wallet, a typed address or a
/// Lightning address; bd t-54y) → review → create (a server confirm through
/// the write gate) → done.
@immutable
sealed class DcaFlowState {
  const DcaFlowState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is DcaFlowState &&
      other.runtimeType == runtimeType &&
      _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';

  DcaFlowNext next(DcaFlowEvent event) {
    final state = this;
    if (event case DcaSessionChanged(:final session)) {
      final current = switch (state) {
        DcaLoading(:final session) => session,
        DcaSetup(:final open) ||
        DcaPayoutPick(:final open) ||
        DcaReview(:final open) ||
        DcaConfirming(:final open) ||
        DcaDone(:final open) => open.session,
        DcaSessionEnded() || DcaClosed() => null,
      };
      return current != null && current != session
          ? _ended
          : DcaFlowNext.stay(state);
    }
    return switch (state) {
      DcaLoading() => _loading(state, event),
      DcaSetup() => _setup(state, event),
      DcaPayoutPick() => _payout(state, event),
      DcaReview() => _review(state, event),
      DcaConfirming() => _confirming(state, event),
      DcaDone() || DcaSessionEnded() => switch (event) {
        DcaBackPressed() || DcaDonePressed() => _closed,
        DcaContextLoaded() ||
        DcaRetryPressed() ||
        DcaAmountChanged() ||
        DcaFrequencyPicked() ||
        DcaContinuePressed() ||
        DcaFundingReturned() ||
        DcaKycReturned() ||
        DcaDetourLoaded() ||
        DcaPayoutChosen() ||
        DcaDefaultWalletsReturned() ||
        DcaDefaultWalletsLoaded() ||
        DcaConfirmPressed() ||
        DcaConfirmChanged() ||
        DcaSessionChanged() => DcaFlowNext.stay(state),
      },
      DcaClosed() => DcaFlowNext.stay(state),
    };
  }
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What the flow loads before the amount: the account, the exchange default
/// wallets, and the open journal entries (a create whose outcome is unknown
/// starts in Verifying).
@immutable
final class DcaContext {
  final UserSummary summary;
  final DefaultWallets defaultWallets;
  final List<UnknownWrite> openEntries;

  const DcaContext({
    required this.summary,
    required this.defaultWallets,
    required this.openEntries,
  });

  AmountContext get amountContext => AmountContext(
    kycGroups: summary.kycGroups,
    balances: {
      for (final balance in summary.balances)
        if (ExchangeCatalog.parse(balance.currencyCode) case KnownCurrency(
          :final market,
        ))
          market.currency: balance.amount,
    },
  );

  Market? get preferredMarket => switch (summary.currency) {
    final code? => switch (ExchangeCatalog.parse(code)) {
      KnownCurrency(:final market) => market,
      UnknownCurrency() => null,
    },
    null => null,
  };

  /// The Lightning address saved for AutoBuy, offered as the default one.
  String? get defaultLightningAddress => summary.autoBuy.addresses.lightning;

  /// The exchange default wallet address of [rail], if one is saved.
  String? defaultAddressOf(BtcNetwork rail) {
    final wallet = switch (rail) {
      BtcNetwork.bitcoin => defaultWallets.bitcoin,
      BtcNetwork.liquid => defaultWallets.liquid,
      BtcNetwork.lightning => null,
    };
    return (wallet?.isNotEmpty ?? false) ? wallet!.address : null;
  }

  DcaContext withWallets(DefaultWallets wallets) => DcaContext(
    summary: summary,
    defaultWallets: wallets,
    openEntries: openEntries,
  );

  DcaContext withAccount(DcaContext loaded) => DcaContext(
    summary: loaded.summary,
    defaultWallets: defaultWallets,
    openEntries: loaded.openEntries,
  );

  @override
  bool operator ==(Object other) =>
      other is DcaContext &&
      other.summary == summary &&
      identical(other.defaultWallets, defaultWallets) &&
      identical(other.openEntries, openEntries);

  @override
  int get hashCode => Object.hash(summary, defaultWallets, openEntries.length);
}

@immutable
final class DcaOpen {
  final ExchangeSession session;
  final DcaContext context;

  const DcaOpen(this.session, this.context);

  @override
  bool operator ==(Object other) =>
      other is DcaOpen && other.session == session && other.context == context;

  @override
  int get hashCode => Object.hash(session, context);
}

/// Where every run pays out.
@immutable
final class DcaPayout {
  final BtcNetwork network;
  final String address;

  /// The exchange default wallet or the saved Lightning address.
  final bool isDefault;

  const DcaPayout(this.network, this.address, {this.isDefault = false});

  @override
  bool operator ==(Object other) =>
      other is DcaPayout &&
      other.network == network &&
      other.address == address &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(network, address, isDefault);
}

/// The recurring buy the flow creates.
@immutable
final class DcaPlan {
  final EnteredAmount amount;
  final DcaBuyFrequency frequency;
  final DcaPayout payout;

  const DcaPlan(this.amount, this.frequency, this.payout);

  double get fiat => amount.fiat;
  FiatCurrency get currency => amount.market.currency;

  @override
  bool operator ==(Object other) =>
      other is DcaPlan &&
      other.amount == amount &&
      other.frequency == frequency &&
      other.payout == payout;

  @override
  int get hashCode => Object.hash(amount, frequency, payout);
}

/// DCA amounts are fiat only, in a funded balance, at the KYC level the
/// market asks of a buy.
const dcaAmountPolicy = AmountPolicy(
  currencySource: CurrencyFromFundedBalances(),
  allowBitcoinUnit: false,
  checkBalance: true,
  onShortfall: BalanceShortfall.offerFunding,
  checkKyc: true,
  withDescription: false,
);

String? _noOrderId(DcaPlan plan) => null;

const dcaConfirmPolicy = ServerConfirmPolicy<DcaPlan>(
  writeKind: FinancialWriteKind.dcaCreate,
  journalKind: UnknownWriteKind.dcaCreate,
  resourceIdOf: _noOrderId,
);

/// The re-read after a create whose outcome is unknown: the account's DCA
/// is active and pays out to [plan]'s address (the reconcile rule,
/// `dcaSettlement`).
ConfirmCheck<DcaPlan> dcaConfirmCheck(
  DcaPlan plan,
  Result<UserSummary, ExchangeReadFailure> read,
) => switch (read) {
  Ok(value: UserSummary(:final dca))
      when dca.isActive && dca.address == plan.payout.address =>
    ConfirmSeenApplied(plan),
  Ok() => const ConfirmSeenNotApplied(),
  Err(failure: ExchangeSessionRejectedFailure()) =>
    const ConfirmCheckSessionRejected(),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => ConfirmCheckFailed(ReadProblem.of(read)!),
};

typedef DcaConfirmState = ServerConfirmState<DcaPlan, DcaPlan>;

final class DcaLoading extends DcaFlowState {
  final ExchangeSession session;

  /// [ContextLoading] or [ContextFailed].
  final ContextLoadState<DcaContext> load;

  const DcaLoading(this.session, this.load);

  @override
  List<Object?> get _props => [session, load];
}

/// The amount and the frequency.
final class DcaSetup extends DcaFlowState {
  final DcaOpen open;

  /// Never [AmountDone] or [AmountSessionRejected].
  final AmountEntryState amount;
  final DcaBuyFrequency? frequency;

  /// Continue was pressed with no frequency.
  final bool frequencyMissing;

  const DcaSetup(
    this.open,
    this.amount,
    this.frequency, {
    this.frequencyMissing = false,
  });

  @override
  List<Object?> get _props => [open, amount, frequency, frequencyMissing];
}

/// Where the runs pay out.
final class DcaPayoutPick extends DcaFlowState {
  final DcaOpen open;
  final EnteredAmount amount;
  final DcaBuyFrequency frequency;

  /// The last default wallets read asked for; older answers are dropped.
  final int walletsTicket;

  const DcaPayoutPick(
    this.open,
    this.amount,
    this.frequency, {
    this.walletsTicket = 0,
  });

  @override
  List<Object?> get _props => [open, amount, frequency, walletsTicket];
}

final class DcaReview extends DcaFlowState {
  final DcaOpen open;
  final DcaPlan plan;

  const DcaReview(this.open, this.plan);

  @override
  List<Object?> get _props => [open, plan];
}

final class DcaConfirming extends DcaFlowState {
  final DcaOpen open;
  final DcaPlan plan;

  /// Never [ConfirmConfirmed], [ConfirmSessionEnded] or [ConfirmLeft].
  final DcaConfirmState confirm;

  const DcaConfirming(this.open, this.plan, this.confirm);

  @override
  List<Object?> get _props => [open, plan, confirm];
}

/// The recurring buy is active.
final class DcaDone extends DcaFlowState {
  final DcaOpen open;
  final DcaPlan plan;

  const DcaDone(this.open, this.plan);

  @override
  List<Object?> get _props => [open, plan];
}

final class DcaSessionEnded extends DcaFlowState {
  const DcaSessionEnded();

  @override
  List<Object?> get _props => const [];
}

final class DcaClosed extends DcaFlowState {
  const DcaClosed();

  @override
  List<Object?> get _props => const [];
}

typedef DcaFlowNext = StepNext<DcaFlowState, DcaFlowEffect>;

const _ended = DcaFlowNext(DcaSessionEnded());

const _closed = DcaFlowNext(DcaClosed());

DcaFlowNext dcaFlowStart(ExchangeSession? session) => switch (session) {
  final session? => DcaFlowNext(DcaLoading(session, const ContextLoading(1)), [
    const DcaLoadContext(1),
  ]),
  null => _ended,
};

DcaFlowNext _loading(DcaLoading state, DcaFlowEvent event) {
  final ContextLoadEvent<DcaContext> loadEvent;
  switch (event) {
    case DcaContextLoaded(:final attempt, :final read):
      loadEvent = ContextLoaded(attempt, read);
    case DcaRetryPressed():
      loadEvent = const ContextRetryPressed();
    case DcaBackPressed() || DcaDonePressed():
      return _closed;
    case DcaAmountChanged() ||
        DcaFrequencyPicked() ||
        DcaContinuePressed() ||
        DcaFundingReturned() ||
        DcaKycReturned() ||
        DcaDetourLoaded() ||
        DcaPayoutChosen() ||
        DcaDefaultWalletsReturned() ||
        DcaDefaultWalletsLoaded() ||
        DcaConfirmPressed() ||
        DcaConfirmChanged() ||
        DcaSessionChanged():
      return DcaFlowNext.stay(state);
  }
  final next = state.load.next(loadEvent);
  if (identical(next.state, state.load)) return DcaFlowNext.stay(state);
  return switch (next.state) {
    ContextReady(:final context) => _setupOf(
      DcaOpen(state.session, context),
      amountEntryStart(
        dcaAmountPolicy,
        context.amountContext,
        preferred: context.preferredMarket,
      ),
      null,
    ),
    ContextSessionRejected() => _ended,
    ContextLoading() || ContextFailed() => DcaFlowNext(
      DcaLoading(state.session, next.state),
      [
        for (final effect in next.effects)
          switch (effect) {
            ContextFetch(:final attempt) => DcaLoadContext(attempt),
          },
      ],
    ),
  };
}

/// The setup after its amount answered [amount]; an amount that is done
/// goes on to the payout with [frequency].
DcaFlowNext _setupOf(
  DcaOpen open,
  AmountEntryNext amount,
  DcaBuyFrequency? frequency,
) {
  final effects = <DcaFlowEffect>[
    for (final effect in amount.effects)
      ...switch (effect) {
        AmountFetchRate(:final market) => [DcaFetchRate(market)],
        // The shell opens KYC and funding on the detour states; their
        // return is DcaKycReturned / DcaFundingReturned.
        AmountOpenKyc() || AmountOpenFunding() => const <DcaFlowEffect>[],
      },
  ];
  return switch (amount.state) {
    AmountSessionRejected() => _ended,
    AmountDone(amount: final entered) => switch (frequency) {
      final frequency? => DcaFlowNext(
        DcaPayoutPick(open, entered, frequency),
        effects,
      ),
      null => DcaFlowNext(
        DcaSetup(open, _editing(open, entered), null, frequencyMissing: true),
        effects,
      ),
    },
    AmountNoMarket() ||
    AmountEditing() ||
    AmountKycDetour() ||
    AmountFundingDetour() => DcaFlowNext(
      DcaSetup(open, amount.state, frequency),
      effects,
    ),
  };
}

AmountEditing _editing(DcaOpen open, EnteredAmount entered) => AmountEditing(
  draft: entered.draft,
  quote: RateReady(entered.rate),
  context: open.context.amountContext,
);

DcaFlowNext _stepped(
  DcaSetup state,
  AmountEntryNext next,
  DcaBuyFrequency? frequency,
) => identical(next.state, state.amount) && next.effects.isEmpty
    ? DcaFlowNext.stay(state)
    : _setupOf(state.open, next, frequency);

DcaFlowNext _setup(DcaSetup state, DcaFlowEvent event) => switch (event) {
  DcaAmountChanged(event: AmountContinuePressed()) ||
  DcaContinuePressed() => _stepped(
    state,
    state.amount.next(dcaAmountPolicy, const AmountContinuePressed()),
    state.frequency,
  ),
  DcaAmountChanged(:final event) => _stepped(
    state,
    state.amount.next(dcaAmountPolicy, event),
    state.frequency,
  ),
  DcaFrequencyPicked(:final frequency) =>
    frequency == state.frequency && !state.frequencyMissing
        ? DcaFlowNext.stay(state)
        : DcaFlowNext(DcaSetup(state.open, state.amount, frequency)),
  DcaFundingReturned() => switch (state.amount) {
    AmountFundingDetour() || AmountNoMarket() => DcaFlowNext(
      DcaSetup(
        state.open,
        state.amount,
        state.frequency,
        frequencyMissing: state.frequencyMissing,
      ),
      const [DcaReloadForDetour()],
    ),
    AmountKycDetour() ||
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => DcaFlowNext.stay(state),
  },
  DcaKycReturned() => switch (state.amount) {
    AmountKycDetour() => DcaFlowNext(
      DcaSetup(
        state.open,
        state.amount,
        state.frequency,
        frequencyMissing: state.frequencyMissing,
      ),
      const [DcaReloadForDetour()],
    ),
    AmountFundingDetour() ||
    AmountNoMarket() ||
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => DcaFlowNext.stay(state),
  },
  DcaDetourLoaded(:final read) => switch (state.amount) {
    AmountFundingDetour() ||
    AmountNoMarket() ||
    AmountKycDetour() => switch (read) {
      Ok(value: final loaded) => _detourReturned(
        state,
        DcaOpen(state.open.session, state.open.context.withAccount(loaded)),
      ),
      Err(failure: ExchangeSessionRejectedFailure()) => _ended,
      Err(failure: ExchangeMissingFailure()) ||
      Err(failure: ExchangeUnreachableFailure()) ||
      Err(failure: ExchangeMalformedFailure()) => DcaFlowNext.stay(state),
    },
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => DcaFlowNext.stay(state),
  },
  DcaBackPressed() => switch (state.amount) {
    AmountFundingDetour() ||
    AmountKycDetour() => _detourReturned(state, state.open),
    AmountNoMarket() ||
    AmountEditing() ||
    AmountDone() ||
    AmountSessionRejected() => _closed,
  },
  DcaContextLoaded() ||
  DcaRetryPressed() ||
  DcaPayoutChosen() ||
  DcaDefaultWalletsReturned() ||
  DcaDefaultWalletsLoaded() ||
  DcaConfirmPressed() ||
  DcaConfirmChanged() ||
  DcaDonePressed() ||
  DcaSessionChanged() => DcaFlowNext.stay(state),
};

DcaFlowNext _detourReturned(DcaSetup state, DcaOpen open) => _setupOf(
  open,
  state.amount.next(
    dcaAmountPolicy,
    AmountDetourReturned(open.context.amountContext),
  ),
  state.frequency,
);

/// Back to the setup with the draft and the frequency kept.
DcaSetup dcaSetupUnder(DcaOpen open, EnteredAmount amount, DcaBuyFrequency f) =>
    DcaSetup(open, _editing(open, amount), f);

DcaFlowNext _payout(DcaPayoutPick state, DcaFlowEvent event) => switch (event) {
  DcaPayoutChosen(:final payout) => DcaFlowNext(
    DcaReview(state.open, DcaPlan(state.amount, state.frequency, payout)),
  ),
  DcaDefaultWalletsReturned() => DcaFlowNext(
    DcaPayoutPick(
      state.open,
      state.amount,
      state.frequency,
      walletsTicket: state.walletsTicket + 1,
    ),
    [DcaLoadDefaultWallets(state.walletsTicket + 1)],
  ),
  // A failed read keeps the wallets shown; the user can still type an
  // address or open the editor again.
  DcaDefaultWalletsLoaded(:final ticket, read: Ok(value: final wallets))
      when ticket == state.walletsTicket =>
    DcaFlowNext(
      DcaPayoutPick(
        DcaOpen(state.open.session, state.open.context.withWallets(wallets)),
        state.amount,
        state.frequency,
        walletsTicket: state.walletsTicket,
      ),
    ),
  DcaBackPressed() => DcaFlowNext(
    dcaSetupUnder(state.open, state.amount, state.frequency),
  ),
  DcaDefaultWalletsLoaded() ||
  DcaContextLoaded() ||
  DcaRetryPressed() ||
  DcaAmountChanged() ||
  DcaFrequencyPicked() ||
  DcaContinuePressed() ||
  DcaFundingReturned() ||
  DcaKycReturned() ||
  DcaDetourLoaded() ||
  DcaConfirmPressed() ||
  DcaConfirmChanged() ||
  DcaDonePressed() ||
  DcaSessionChanged() => DcaFlowNext.stay(state),
};

DcaFlowNext _review(DcaReview state, DcaFlowEvent event) => switch (event) {
  DcaConfirmPressed() => _confirmNext(
    state.open,
    state.plan,
    serverConfirmStart<DcaPlan, DcaPlan>(
      state.plan,
      openEntry: openEntryFor(
        dcaConfirmPolicy,
        state.plan,
        state.open.context.openEntries,
      ),
    ),
  ),
  DcaBackPressed() => DcaFlowNext(
    DcaPayoutPick(state.open, state.plan.amount, state.plan.frequency),
  ),
  DcaContextLoaded() ||
  DcaRetryPressed() ||
  DcaAmountChanged() ||
  DcaFrequencyPicked() ||
  DcaContinuePressed() ||
  DcaFundingReturned() ||
  DcaKycReturned() ||
  DcaDetourLoaded() ||
  DcaPayoutChosen() ||
  DcaDefaultWalletsReturned() ||
  DcaDefaultWalletsLoaded() ||
  DcaConfirmChanged() ||
  DcaDonePressed() ||
  DcaSessionChanged() => DcaFlowNext.stay(state),
};

DcaFlowNext _confirmNext(
  DcaOpen open,
  DcaPlan plan,
  ServerConfirmNext<DcaPlan, DcaPlan> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => DcaFlowNext(
    DcaDone(open, confirmed),
    const [DcaActivated()],
  ),
  ConfirmSessionEnded() => _ended,
  // Back from a refused or failed create: nothing took effect.
  ConfirmLeft() => DcaFlowNext(DcaReview(open, plan)),
  ConfirmConfirming() ||
  ConfirmWriteRefused() ||
  ConfirmFailed() ||
  ConfirmVerifying() ||
  ConfirmUnverified() => DcaFlowNext(DcaConfirming(open, plan, next.state), [
    for (final effect in next.effects) DcaConfirmEffect(effect),
  ]),
};

DcaFlowNext _confirming(DcaConfirming state, DcaFlowEvent event) {
  final DcaConfirmEvent stepEvent;
  switch (event) {
    case DcaConfirmChanged(:final event):
      stepEvent = event;
    case DcaConfirmPressed():
      stepEvent = const ConfirmCommitPressed();
    case DcaRetryPressed():
      stepEvent = const ConfirmRetryPressed();
    case DcaBackPressed():
      // A create that may have gone through: leave, never back to Confirm.
      if (state.confirm is ConfirmUnverified) return _closed;
      stepEvent = const ConfirmBackPressed();
    case DcaContextLoaded() ||
        DcaAmountChanged() ||
        DcaFrequencyPicked() ||
        DcaContinuePressed() ||
        DcaFundingReturned() ||
        DcaKycReturned() ||
        DcaDetourLoaded() ||
        DcaPayoutChosen() ||
        DcaDefaultWalletsReturned() ||
        DcaDefaultWalletsLoaded() ||
        DcaDonePressed() ||
        DcaSessionChanged():
      return DcaFlowNext.stay(state);
  }
  final next = state.confirm.next(dcaConfirmPolicy, stepEvent);
  if (identical(next.state, state.confirm) && next.effects.isEmpty) {
    return DcaFlowNext.stay(state);
  }
  return _confirmNext(state.open, state.plan, next);
}
