import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show ReadProblem, StepNext;
import 'package:meta/meta.dart';

import 'default_wallets_failure.dart';

import 'package:primitives/primitives.dart';

/// What checking a typed address said.
@immutable
sealed class WalletAddressCheck {
  const WalletAddressCheck();
}

/// The address is valid for the slot's payout rail; [address] is the
/// normalised form that is saved.
final class WalletAddressValid extends WalletAddressCheck {
  final String address;

  const WalletAddressValid(this.address);

  @override
  bool operator ==(Object other) =>
      other is WalletAddressValid && other.address == address;

  @override
  int get hashCode => Object.hash(WalletAddressValid, address);
}

final class WalletAddressInvalid extends WalletAddressCheck {
  const WalletAddressInvalid();
}

/// The check itself failed (not an answer about the address).
final class WalletAddressCheckFailed extends WalletAddressCheck {
  const WalletAddressCheckFailed();
}

/// The write a slot may have sent without a readable answer.
@immutable
sealed class SlotIntent {
  const SlotIntent();
}

final class SlotSaveIntent extends SlotIntent {
  final String draft;
  final String address;

  const SlotSaveIntent({required this.draft, required this.address});

  @override
  bool operator ==(Object other) =>
      other is SlotSaveIntent &&
      other.draft == draft &&
      other.address == address;

  @override
  int get hashCode => Object.hash(SlotSaveIntent, draft, address);
}

final class SlotUnsetIntent extends SlotIntent {
  const SlotUnsetIntent();
}

/// What the slot shows once after a mutation ends.
@immutable
sealed class SlotNotice {
  const SlotNotice();
}

final class SlotNoticeSaved extends SlotNotice {
  const SlotNoticeSaved();
}

final class SlotNoticeUnset extends SlotNotice {
  const SlotNoticeUnset();
}

final class SlotNoticeFailed extends SlotNotice {
  final DefaultWalletsFailure failure;

  const SlotNoticeFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is SlotNoticeFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(SlotNoticeFailed, failure);
}

/// One payout rail's editor. Each slot keeps its own draft (DW-5).
@immutable
sealed class WalletSlot {
  const WalletSlot();
}

/// Shows the saved address (or none).
final class SlotShowing extends WalletSlot {
  final SlotNotice? notice;

  const SlotShowing({this.notice});

  @override
  bool operator ==(Object other) =>
      other is SlotShowing && other.notice == notice;

  @override
  int get hashCode => Object.hash(SlotShowing, notice);
}

final class SlotEditing extends WalletSlot {
  final String draft;
  final DefaultWalletsFailure? problem;

  const SlotEditing(this.draft, {this.problem});

  @override
  bool operator ==(Object other) =>
      other is SlotEditing && other.draft == draft && other.problem == problem;

  @override
  int get hashCode => Object.hash(SlotEditing, draft, problem);
}

/// The typed address is being checked before it is saved.
final class SlotChecking extends WalletSlot {
  final String draft;
  final int attempt;

  const SlotChecking(this.draft, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is SlotChecking && other.draft == draft && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(SlotChecking, draft, attempt);
}

final class SlotSaving extends WalletSlot {
  final String draft;
  final String address;
  final int attempt;

  const SlotSaving(this.draft, this.address, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is SlotSaving &&
      other.draft == draft &&
      other.address == address &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(SlotSaving, draft, address, attempt);
}

final class SlotUnsetting extends WalletSlot {
  final int attempt;

  const SlotUnsetting(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is SlotUnsetting && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(SlotUnsetting, attempt);
}

/// A write of this slot may have reached the exchange: the wallets are read
/// again (and the journal reconciled) before anything else is offered.
final class SlotVerifying extends WalletSlot {
  final SlotIntent intent;
  final int attempt;

  const SlotVerifying(this.intent, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is SlotVerifying &&
      other.intent == intent &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(SlotVerifying, intent, attempt);
}

/// The re-read failed: only a new check is offered, never the write.
final class SlotUnverified extends WalletSlot {
  final SlotIntent intent;
  final ReadProblem problem;

  const SlotUnverified(this.intent, this.problem);

  @override
  bool operator ==(Object other) =>
      other is SlotUnverified &&
      other.intent == intent &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(SlotUnverified, intent, problem);
}

/// The three slots, one per payout rail.
@immutable
final class WalletSlots {
  final WalletSlot bitcoin;
  final WalletSlot lightning;
  final WalletSlot liquid;

  const WalletSlots({
    this.bitcoin = const SlotShowing(),
    this.lightning = const SlotShowing(),
    this.liquid = const SlotShowing(),
  });

  WalletSlot of(BtcNetwork network) => switch (network) {
    BtcNetwork.bitcoin => bitcoin,
    BtcNetwork.lightning => lightning,
    BtcNetwork.liquid => liquid,
  };

  WalletSlots withSlot(BtcNetwork network, WalletSlot slot) => WalletSlots(
    bitcoin: network == BtcNetwork.bitcoin ? slot : bitcoin,
    lightning: network == BtcNetwork.lightning ? slot : lightning,
    liquid: network == BtcNetwork.liquid ? slot : liquid,
  );

  /// A write is running or unsettled in some slot: no other is started.
  bool get mutating => BtcNetwork.values.any((n) => slotMutating(of(n)));

  @override
  bool operator ==(Object other) =>
      other is WalletSlots &&
      other.bitcoin == bitcoin &&
      other.lightning == lightning &&
      other.liquid == liquid;

  @override
  int get hashCode => Object.hash(bitcoin, lightning, liquid);
}

bool slotMutating(WalletSlot slot) => switch (slot) {
  SlotShowing() || SlotEditing() => false,
  SlotChecking() ||
  SlotSaving() ||
  SlotUnsetting() ||
  SlotVerifying() ||
  SlotUnverified() => true,
};

@immutable
sealed class DefaultWalletsState {
  const DefaultWalletsState();
}

final class WalletsLoading extends DefaultWalletsState {
  final ExchangeSession session;
  final int attempt;

  const WalletsLoading(this.session, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is WalletsLoading &&
      other.session == session &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(WalletsLoading, session, attempt);
}

/// The wallets could not be read: never shown as "no wallets".
final class WalletsLoadFailed extends DefaultWalletsState {
  final ExchangeSession session;
  final int attempt;
  final ReadProblem problem;

  const WalletsLoadFailed(this.session, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is WalletsLoadFailed &&
      other.session == session &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(WalletsLoadFailed, session, attempt, problem);
}

/// [attempts] is the last attempt number handed out; every effect result
/// carries its attempt, and a result for another one is a stay.
final class WalletsReady extends DefaultWalletsState {
  final ExchangeSession session;
  final DefaultWallets saved;
  final WalletSlots slots;
  final int attempts;

  const WalletsReady(
    this.session,
    this.saved, {
    this.slots = const WalletSlots(),
    required this.attempts,
  });

  WalletsReady copyWith({
    DefaultWallets? saved,
    WalletSlots? slots,
    int? attempts,
  }) => WalletsReady(
    session,
    saved ?? this.saved,
    slots: slots ?? this.slots,
    attempts: attempts ?? this.attempts,
  );

  @override
  bool operator ==(Object other) =>
      other is WalletsReady &&
      other.session == session &&
      other.saved == saved &&
      other.slots == slots &&
      other.attempts == attempts;

  @override
  int get hashCode =>
      Object.hash(WalletsReady, session, saved, slots, attempts);
}

/// The session the screen was opened for ended (or there was none).
final class WalletsSessionEnded extends DefaultWalletsState {
  const WalletsSessionEnded();

  @override
  bool operator ==(Object other) => other is WalletsSessionEnded;

  @override
  int get hashCode => (WalletsSessionEnded).hashCode;
}

@immutable
sealed class DefaultWalletsEvent {
  const DefaultWalletsEvent();
}

final class WalletsLoaded extends DefaultWalletsEvent {
  final int attempt;
  final Result<DefaultWallets, ExchangeReadFailure> read;

  const WalletsLoaded(this.attempt, this.read);
}

final class WalletsRetryPressed extends DefaultWalletsEvent {
  const WalletsRetryPressed();
}

final class SlotTyped extends DefaultWalletsEvent {
  final BtcNetwork network;
  final String text;

  const SlotTyped(this.network, this.text);
}

final class SlotCancelPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotCancelPressed(this.network);
}

final class SlotSavePressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotSavePressed(this.network);
}

final class SlotChecked extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final WalletAddressCheck check;

  const SlotChecked(this.network, this.attempt, this.check);
}

final class SlotSaveAnswered extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>> answer;

  const SlotSaveAnswered(this.network, this.attempt, this.answer);
}

final class SlotUnsetPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotUnsetPressed(this.network);
}

final class SlotUnsetAnswered extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final GatedWrite<Result<void, ExchangeWriteFailure>> answer;

  const SlotUnsetAnswered(this.network, this.attempt, this.answer);
}

final class SlotVerified extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final Result<DefaultWallets, ExchangeReadFailure> read;

  const SlotVerified(this.network, this.attempt, this.read);
}

final class SlotVerifyRetryPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotVerifyRetryPressed(this.network);
}

@immutable
sealed class DefaultWalletsEffect {
  const DefaultWalletsEffect();
}

final class FetchDefaultWallets extends DefaultWalletsEffect {
  final ExchangeSession session;
  final int attempt;

  const FetchDefaultWallets(this.session, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FetchDefaultWallets &&
      other.session == session &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FetchDefaultWallets, session, attempt);
}

final class CheckWalletAddress extends DefaultWalletsEffect {
  final BtcNetwork network;
  final int attempt;
  final String text;

  const CheckWalletAddress(this.network, this.attempt, this.text);

  @override
  bool operator ==(Object other) =>
      other is CheckWalletAddress &&
      other.network == network &&
      other.attempt == attempt &&
      other.text == text;

  @override
  int get hashCode => Object.hash(CheckWalletAddress, network, attempt, text);
}

final class SaveDefaultWallet extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;
  final String address;
  final String? existingRecipientId;

  const SaveDefaultWallet(
    this.session,
    this.network,
    this.attempt,
    this.address, {
    this.existingRecipientId,
  });

  @override
  bool operator ==(Object other) =>
      other is SaveDefaultWallet &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt &&
      other.address == address &&
      other.existingRecipientId == existingRecipientId;

  @override
  int get hashCode => Object.hash(
    SaveDefaultWallet,
    session,
    network,
    attempt,
    address,
    existingRecipientId,
  );
}

final class UnsetDefaultWallet extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;
  final String recipientId;
  final String address;

  const UnsetDefaultWallet(
    this.session,
    this.network,
    this.attempt, {
    required this.recipientId,
    required this.address,
  });

  @override
  bool operator ==(Object other) =>
      other is UnsetDefaultWallet &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt &&
      other.recipientId == recipientId &&
      other.address == address;

  @override
  int get hashCode => Object.hash(
    UnsetDefaultWallet,
    session,
    network,
    attempt,
    recipientId,
    address,
  );
}

/// Reconciles the journal, then reads the wallets again.
final class VerifyDefaultWallets extends DefaultWalletsEffect {
  final ExchangeSession session;
  final BtcNetwork network;
  final int attempt;

  const VerifyDefaultWallets(this.session, this.network, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is VerifyDefaultWallets &&
      other.session == session &&
      other.network == network &&
      other.attempt == attempt;

  @override
  int get hashCode =>
      Object.hash(VerifyDefaultWallets, session, network, attempt);
}

typedef DefaultWalletsNext =
    StepNext<DefaultWalletsState, DefaultWalletsEffect>;

/// The screen opened for [session]; no session is [WalletsSessionEnded].
DefaultWalletsNext defaultWalletsStart(ExchangeSession? session) =>
    switch (session) {
      null => StepNext(const WalletsSessionEnded()),
      final session => StepNext(WalletsLoading(session, 1), [
        FetchDefaultWallets(session, 1),
      ]),
    };

DefaultWallets withDefaultWallet(
  DefaultWallets wallets,
  BtcNetwork network,
  DefaultWallet? wallet,
) => DefaultWallets(
  bitcoin: network == BtcNetwork.bitcoin ? wallet : wallets.bitcoin,
  lightning: network == BtcNetwork.lightning ? wallet : wallets.lightning,
  liquid: network == BtcNetwork.liquid ? wallet : wallets.liquid,
);

DefaultWalletsNext transitionDefaultWallets(
  DefaultWalletsState state,
  DefaultWalletsEvent event,
) => switch ((state, event)) {
  (
    WalletsSessionEnded(),
    WalletsLoaded() ||
        WalletsRetryPressed() ||
        SlotTyped() ||
        SlotCancelPressed() ||
        SlotSavePressed() ||
        SlotChecked() ||
        SlotSaveAnswered() ||
        SlotUnsetPressed() ||
        SlotUnsetAnswered() ||
        SlotVerified() ||
        SlotVerifyRetryPressed(),
  ) =>
    StepNext.stay(state),
  (WalletsLoading(:final session, :final attempt), WalletsLoaded loaded)
      when loaded.attempt == attempt =>
    switch (loaded.read) {
      Ok(:final value) => StepNext(
        WalletsReady(session, value, attempts: attempt),
      ),
      Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
        const WalletsSessionEnded(),
      ),
      Err(failure: ExchangeMissingFailure()) ||
      Err(failure: ExchangeUnreachableFailure()) ||
      Err(failure: ExchangeMalformedFailure()) => StepNext(
        WalletsLoadFailed(session, attempt, ReadProblem.of(loaded.read)!),
      ),
    },
  (
    WalletsLoading(),
    WalletsLoaded() ||
        WalletsRetryPressed() ||
        SlotTyped() ||
        SlotCancelPressed() ||
        SlotSavePressed() ||
        SlotChecked() ||
        SlotSaveAnswered() ||
        SlotUnsetPressed() ||
        SlotUnsetAnswered() ||
        SlotVerified() ||
        SlotVerifyRetryPressed(),
  ) =>
    StepNext.stay(state),
  (WalletsLoadFailed(:final session, :final attempt), WalletsRetryPressed()) =>
    StepNext(WalletsLoading(session, attempt + 1), [
      FetchDefaultWallets(session, attempt + 1),
    ]),
  (
    WalletsLoadFailed(),
    WalletsLoaded() ||
        SlotTyped() ||
        SlotCancelPressed() ||
        SlotSavePressed() ||
        SlotChecked() ||
        SlotSaveAnswered() ||
        SlotUnsetPressed() ||
        SlotUnsetAnswered() ||
        SlotVerified() ||
        SlotVerifyRetryPressed(),
  ) =>
    StepNext.stay(state),
  (WalletsReady(), WalletsLoaded() || WalletsRetryPressed()) => StepNext.stay(
    state,
  ),
  (final WalletsReady ready, SlotTyped(:final network, :final text)) =>
    switch (ready.slots.of(network)) {
      SlotShowing() ||
      SlotEditing() => _slot(ready, network, SlotEditing(text)),
      SlotChecking() ||
      SlotSaving() ||
      SlotUnsetting() ||
      SlotVerifying() ||
      SlotUnverified() => StepNext.stay(state),
    },
  (final WalletsReady ready, SlotCancelPressed(:final network)) => switch (ready
      .slots
      .of(network)) {
    SlotEditing() => _slot(ready, network, const SlotShowing()),
    SlotShowing() ||
    SlotChecking() ||
    SlotSaving() ||
    SlotUnsetting() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotSavePressed(:final network)) => switch (ready
      .slots
      .of(network)) {
    SlotEditing(:final draft) => _savePressed(ready, network, draft),
    SlotShowing() ||
    SlotChecking() ||
    SlotSaving() ||
    SlotUnsetting() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotChecked checked) => switch (ready.slots.of(
    checked.network,
  )) {
    SlotChecking(:final draft, :final attempt)
        when attempt == checked.attempt =>
      _checked(ready, checked.network, draft, attempt, checked.check),
    SlotChecking() ||
    SlotShowing() ||
    SlotEditing() ||
    SlotSaving() ||
    SlotUnsetting() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotSaveAnswered answered) => switch (ready.slots
      .of(answered.network)) {
    SlotSaving(:final draft, :final address, :final attempt)
        when attempt == answered.attempt =>
      _saveAnswered(ready, answered.network, draft, address, answered.answer),
    SlotSaving() ||
    SlotShowing() ||
    SlotEditing() ||
    SlotChecking() ||
    SlotUnsetting() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotUnsetPressed(:final network)) => switch (ready
      .slots
      .of(network)) {
    SlotShowing() => _unsetPressed(ready, network),
    SlotEditing() ||
    SlotChecking() ||
    SlotSaving() ||
    SlotUnsetting() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotUnsetAnswered answered) => switch (ready.slots
      .of(answered.network)) {
    SlotUnsetting(:final attempt) when attempt == answered.attempt =>
      _unsetAnswered(ready, answered.network, answered.answer),
    SlotUnsetting() ||
    SlotShowing() ||
    SlotEditing() ||
    SlotChecking() ||
    SlotSaving() ||
    SlotVerifying() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotVerified verified) => switch (ready.slots.of(
    verified.network,
  )) {
    SlotVerifying(:final intent, :final attempt)
        when attempt == verified.attempt =>
      _verified(ready, verified.network, intent, verified.read),
    SlotVerifying() ||
    SlotShowing() ||
    SlotEditing() ||
    SlotChecking() ||
    SlotSaving() ||
    SlotUnsetting() ||
    SlotUnverified() => StepNext.stay(state),
  },
  (final WalletsReady ready, SlotVerifyRetryPressed(:final network)) =>
    switch (ready.slots.of(network)) {
      SlotUnverified(:final intent) => _verify(ready, network, intent),
      SlotShowing() ||
      SlotEditing() ||
      SlotChecking() ||
      SlotSaving() ||
      SlotUnsetting() ||
      SlotVerifying() => StepNext.stay(state),
    },
};

DefaultWalletsNext _savePressed(
  WalletsReady ready,
  BtcNetwork network,
  String draft,
) {
  if (draft.trim().isEmpty) {
    return _slot(
      ready,
      network,
      SlotEditing(draft, problem: const DefaultWalletsEmptyAddressFailure()),
    );
  }
  if (ready.slots.mutating) return StepNext.stay(ready);
  final attempt = ready.attempts + 1;
  return StepNext(
    ready.copyWith(
      slots: ready.slots.withSlot(network, SlotChecking(draft, attempt)),
      attempts: attempt,
    ),
    [CheckWalletAddress(network, attempt, draft)],
  );
}

DefaultWalletsNext _checked(
  WalletsReady ready,
  BtcNetwork network,
  String draft,
  int attempt,
  WalletAddressCheck check,
) => switch (check) {
  WalletAddressValid(:final address) => StepNext(
    ready.copyWith(
      slots: ready.slots.withSlot(network, SlotSaving(draft, address, attempt)),
    ),
    [
      SaveDefaultWallet(
        ready.session,
        network,
        attempt,
        address,
        existingRecipientId: ready.saved.getWallet(network)?.recipientId,
      ),
    ],
  ),
  WalletAddressInvalid() => _slot(
    ready,
    network,
    SlotEditing(draft, problem: DefaultWalletsInvalidAddressFailure(network)),
  ),
  WalletAddressCheckFailed() => _slot(
    ready,
    network,
    SlotEditing(draft, problem: const DefaultWalletsSaveFailure()),
  ),
};

DefaultWalletsNext _unsetPressed(WalletsReady ready, BtcNetwork network) {
  final wallet = ready.saved.getWallet(network);
  final recipientId = wallet?.recipientId;
  if (wallet == null ||
      recipientId == null ||
      wallet.address.isEmpty ||
      ready.slots.mutating) {
    return StepNext.stay(ready);
  }
  final attempt = ready.attempts + 1;
  return StepNext(
    ready.copyWith(
      slots: ready.slots.withSlot(network, SlotUnsetting(attempt)),
      attempts: attempt,
    ),
    [
      UnsetDefaultWallet(
        ready.session,
        network,
        attempt,
        recipientId: recipientId,
        address: wallet.address,
      ),
    ],
  );
}

DefaultWalletsNext _slot(
  WalletsReady ready,
  BtcNetwork network,
  WalletSlot slot, {
  DefaultWallets? saved,
}) => StepNext(
  ready.copyWith(slots: ready.slots.withSlot(network, slot), saved: saved),
);

DefaultWalletsNext _verify(
  WalletsReady ready,
  BtcNetwork network,
  SlotIntent intent,
) {
  final attempt = ready.attempts + 1;
  return StepNext(
    ready.copyWith(
      slots: ready.slots.withSlot(network, SlotVerifying(intent, attempt)),
      attempts: attempt,
    ),
    [VerifyDefaultWallets(ready.session, network, attempt)],
  );
}

DefaultWalletsNext _saveAnswered(
  WalletsReady ready,
  BtcNetwork network,
  String draft,
  String address,
  GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>> answer,
) => switch (answer) {
  GateAdmitted(result: Ok(:final value)) => _slot(
    ready,
    network,
    const SlotShowing(notice: SlotNoticeSaved()),
    saved: withDefaultWallet(ready.saved, network, value),
  ),
  GateAdmitted(result: Err(failure: ExchangeWriteOutcomeUnknownFailure())) ||
  GateRefused(
    refusal: WriteGateUnsettled(),
  ) => _verify(ready, network, SlotSaveIntent(draft: draft, address: address)),
  GateAdmitted(
    result: Err(failure: ExchangeSessionRejectedFailure()) ||
        Err(
          failure: ExchangeWriteNotSentFailure(
            reason: ExchangeNotSentReason.sessionChanged,
          ),
        ),
  ) =>
    StepNext(const WalletsSessionEnded()),
  GateAdmitted(
    result: Err(failure: ExchangeWriteRefusedFailure()) ||
        Err(failure: ExchangeWriteNotSentFailure()),
  ) =>
    _slot(
      ready,
      network,
      SlotEditing(draft, problem: const DefaultWalletsSaveFailure()),
    ),
  GateRefused(refusal: WriteGateBusy() || WriteGateJournalUnreadable()) =>
    _slot(
      ready,
      network,
      SlotEditing(draft, problem: const DefaultWalletsBusyFailure()),
    ),
};

DefaultWalletsNext _unsetAnswered(
  WalletsReady ready,
  BtcNetwork network,
  GatedWrite<Result<void, ExchangeWriteFailure>> answer,
) => switch (answer) {
  GateAdmitted(result: Ok()) => _slot(
    ready,
    network,
    const SlotShowing(notice: SlotNoticeUnset()),
    saved: withDefaultWallet(ready.saved, network, null),
  ),
  GateAdmitted(result: Err(failure: ExchangeWriteOutcomeUnknownFailure())) ||
  GateRefused(
    refusal: WriteGateUnsettled(),
  ) => _verify(ready, network, const SlotUnsetIntent()),
  GateAdmitted(
    result: Err(failure: ExchangeSessionRejectedFailure()) ||
        Err(
          failure: ExchangeWriteNotSentFailure(
            reason: ExchangeNotSentReason.sessionChanged,
          ),
        ),
  ) =>
    StepNext(const WalletsSessionEnded()),
  GateAdmitted(
    result: Err(failure: ExchangeWriteRefusedFailure()) ||
        Err(failure: ExchangeWriteNotSentFailure()),
  ) =>
    _slot(
      ready,
      network,
      const SlotShowing(
        notice: SlotNoticeFailed(DefaultWalletsDeleteFailure()),
      ),
    ),
  GateRefused(refusal: WriteGateBusy() || WriteGateJournalUnreadable()) =>
    _slot(
      ready,
      network,
      const SlotShowing(notice: SlotNoticeFailed(DefaultWalletsBusyFailure())),
    ),
};

DefaultWalletsNext _verified(
  WalletsReady ready,
  BtcNetwork network,
  SlotIntent intent,
  Result<DefaultWallets, ExchangeReadFailure> read,
) => switch (read) {
  Ok(:final value) => switch (intent) {
    SlotSaveIntent(:final draft, :final address) =>
      value.getWallet(network)?.address == address
          ? _slot(
              ready,
              network,
              const SlotShowing(notice: SlotNoticeSaved()),
              saved: value,
            )
          : _slot(
              ready,
              network,
              SlotEditing(draft, problem: const DefaultWalletsSaveFailure()),
              saved: value,
            ),
    SlotUnsetIntent() =>
      (value.getWallet(network)?.address ?? '').isEmpty
          ? _slot(
              ready,
              network,
              const SlotShowing(notice: SlotNoticeUnset()),
              saved: value,
            )
          : _slot(
              ready,
              network,
              const SlotShowing(
                notice: SlotNoticeFailed(DefaultWalletsDeleteFailure()),
              ),
              saved: value,
            ),
  },
  Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
    const WalletsSessionEnded(),
  ),
  Err(failure: ExchangeMissingFailure()) ||
  Err(failure: ExchangeUnreachableFailure()) ||
  Err(
    failure: ExchangeMalformedFailure(),
  ) => _slot(ready, network, SlotUnverified(intent, ReadProblem.of(read)!)),
};
