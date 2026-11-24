import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'exchange_access.dart';
import 'exchange_environment.dart';
import 'unknown_write_journal.dart';

/// The financial writes that share one gate per account: at most one of them
/// runs at a time, across every flow.
enum FinancialWriteKind {
  orderCreate,
  orderConfirm,
  payin,
  accelerate,
  dcaCreate,
  limitOrderCreate,
  limitOrderCancel,
  withdrawal,
  defaultWalletSave,
  preferenceWrite,
}

/// Why the gate did not run a write. The write was not sent.
@immutable
sealed class WriteGateRefusal {
  const WriteGateRefusal();
}

/// Another financial write of the same account is in flight.
final class WriteGateBusy extends WriteGateRefusal {
  final FinancialWriteKind inFlight;

  const WriteGateBusy(this.inFlight);

  @override
  bool operator ==(Object other) =>
      other is WriteGateBusy && other.inFlight == inFlight;

  @override
  int get hashCode => Object.hash(WriteGateBusy, inFlight);
}

/// A financial write of the same account may have reached the exchange and is
/// not settled yet: [entry] has to be settled by a re-read first.
final class WriteGateUnsettled extends WriteGateRefusal {
  final UnknownWrite entry;

  const WriteGateUnsettled(this.entry);

  @override
  bool operator ==(Object other) =>
      other is WriteGateUnsettled && other.entry.id == entry.id;

  @override
  int get hashCode => Object.hash(WriteGateUnsettled, entry.id);
}

/// The journal could not be read, so the gate can't tell whether an earlier
/// write is unsettled.
final class WriteGateJournalUnreadable extends WriteGateRefusal {
  const WriteGateJournalUnreadable();

  @override
  bool operator ==(Object other) => other is WriteGateJournalUnreadable;

  @override
  int get hashCode => (WriteGateJournalUnreadable).hashCode;
}

/// What the gate did with a write: ran it and returned its [result], or
/// refused it.
sealed class GatedWrite<T> {
  const GatedWrite();
}

final class GateAdmitted<T> extends GatedWrite<T> {
  final T result;

  const GateAdmitted(this.result);
}

final class GateRefused<T> extends GatedWrite<T> {
  final WriteGateRefusal refusal;

  const GateRefused(this.refusal);
}

/// Whether an open journal entry of [kind] holds the gate. Recipient creates
/// are journaled but move no money, so they don't.
bool journalEntryHoldsGate(UnknownWriteKind kind) => switch (kind) {
  UnknownWriteKind.buyConfirm ||
  UnknownWriteKind.withdrawConfirm ||
  UnknownWriteKind.accelerate ||
  UnknownWriteKind.dcaCreate ||
  UnknownWriteKind.limitOrderCreate ||
  UnknownWriteKind.defaultWalletSave ||
  UnknownWriteKind.preferencesSave => true,
  UnknownWriteKind.recipientCreate => false,
};

/// One financial write at a time per account. A second write while one is in
/// flight, or while the journal holds an unsettled one, is refused, never
/// queued: the flow shows the refusal and the user decides again. Settled
/// entries are not in the open set; an open entry older than
/// [UnknownWrite.maxAge] no longer holds the gate (reconcile closes it).
///
/// The account is the session's environment (one key per environment). The
/// in-flight mark is taken before the journal is read, so two writes started
/// in the same frame can't both pass.
final class ExchangeWriteGate {
  final UnknownWriteJournal? _journal;
  final _inFlight = <ExchangeEnvironment, FinancialWriteKind>{};

  ExchangeWriteGate({UnknownWriteJournal? journal}) : _journal = journal;

  /// The write in flight for [environment], if any.
  FinancialWriteKind? inFlight(ExchangeEnvironment environment) =>
      _inFlight[environment];

  /// Runs [write] for [session]'s account unless the gate is held. An error
  /// thrown by [write] releases the gate and is rethrown.
  Future<GatedWrite<T>> run<T>(
    ExchangeSession session,
    FinancialWriteKind kind,
    Future<T> Function() write,
  ) async {
    final account = session.environment;
    final busy = _inFlight[account];
    if (busy != null) return GateRefused(WriteGateBusy(busy));
    _inFlight[account] = kind;
    try {
      final journal = _journal;
      if (journal != null) {
        switch (await journal.open(account)) {
          case Err():
            return GateRefused(const WriteGateJournalUnreadable());
          case Ok(:final value):
            for (final entry in value) {
              if (journalEntryHoldsGate(entry.kind) &&
                  !entry.isOverAge(clock.now())) {
                return GateRefused(WriteGateUnsettled(entry));
              }
            }
        }
      }
      return GateAdmitted(await write());
    } finally {
      _inFlight.remove(account);
    }
  }
}
