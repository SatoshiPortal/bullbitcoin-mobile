import 'dart:async';

import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

const _main = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _test = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 2,
  sessionId: 'b',
);

final class _BrokenJournal implements UnknownWriteJournal {
  @override
  Future<Result<List<UnknownWrite>, UnknownWriteJournalFailure>> open(
    ExchangeEnvironment environment,
  ) async => const Err(UnknownWriteJournalFailure('read failed'));

  @override
  Future<Result<UnknownWrite, UnknownWriteJournalFailure>> record(
    UnknownWriteDraft draft,
  ) => throw StateError('Unexpected record');

  @override
  Future<Result<void, UnknownWriteJournalFailure>> settle(
    String id,
    UnknownWriteSettlement settlement,
  ) => throw StateError('Unexpected settle');
}

Future<UnknownWrite> _record(
  InMemoryUnknownWriteJournal journal,
  UnknownWriteKind kind, {
  ExchangeEnvironment environment = ExchangeEnvironment.mainnet,
}) async {
  final recorded = await journal.record(
    UnknownWriteDraft(
      kind: kind,
      environment: environment,
      request: const {'orderId': 'o-1'},
      orderId: 'o-1',
    ),
  );
  return (recorded as Ok<UnknownWrite, UnknownWriteJournalFailure>).value;
}

void main() {
  test('a write runs when the gate is free and releases it', () async {
    final gate = ExchangeWriteGate();
    final answer = await gate.run(
      _main,
      FinancialWriteKind.orderConfirm,
      () async => 'done',
    );
    expect((answer as GateAdmitted<String>).result, 'done');
    expect(gate.inFlight(ExchangeEnvironment.mainnet), isNull);
  });

  test(
    'a second write while one is in flight is refused, not queued',
    () async {
      final gate = ExchangeWriteGate();
      final first = Completer<String>();
      final running = gate.run(
        _main,
        FinancialWriteKind.orderCreate,
        () => first.future,
      );
      var secondSent = false;
      final second = await gate.run(_main, FinancialWriteKind.payin, () async {
        secondSent = true;
        return 'second';
      });
      expect(secondSent, isFalse);
      expect(
        (second as GateRefused<String>).refusal,
        const WriteGateBusy(FinancialWriteKind.orderCreate),
      );
      expect(
        gate.inFlight(ExchangeEnvironment.mainnet),
        FinancialWriteKind.orderCreate,
      );

      first.complete('first');
      expect((await running as GateAdmitted<String>).result, 'first');
      expect(gate.inFlight(ExchangeEnvironment.mainnet), isNull);
      final third = await gate.run(
        _main,
        FinancialWriteKind.payin,
        () async => 'third',
      );
      expect(third, isA<GateAdmitted<String>>());
    },
  );

  test('the other environment is another account', () async {
    final gate = ExchangeWriteGate();
    final first = Completer<String>();
    final running = gate.run(
      _main,
      FinancialWriteKind.orderCreate,
      () => first.future,
    );
    final other = await gate.run(
      _test,
      FinancialWriteKind.withdrawal,
      () async => 'other',
    );
    expect((other as GateAdmitted<String>).result, 'other');
    first.complete('first');
    await running;
  });

  test('an unsettled journal entry of the account refuses the write', () async {
    final journal = InMemoryUnknownWriteJournal();
    final entry = await _record(journal, UnknownWriteKind.buyConfirm);
    final gate = ExchangeWriteGate(journal: journal);
    var sent = false;
    final answer = await gate.run(
      _main,
      FinancialWriteKind.dcaCreate,
      () async {
        sent = true;
        return 'dca';
      },
    );
    expect(sent, isFalse);
    expect((answer as GateRefused<String>).refusal, WriteGateUnsettled(entry));
    expect(gate.inFlight(ExchangeEnvironment.mainnet), isNull);
  });

  test('a settled entry, or one of another environment, does not', () async {
    final journal = InMemoryUnknownWriteJournal();
    final settled = await _record(journal, UnknownWriteKind.withdrawConfirm);
    await journal.settle(settled.id, UnknownWriteSettlement.applied);
    await _record(
      journal,
      UnknownWriteKind.accelerate,
      environment: ExchangeEnvironment.testnet,
    );
    final gate = ExchangeWriteGate(journal: journal);
    final answer = await gate.run(
      _main,
      FinancialWriteKind.withdrawal,
      () async => 'sent',
    );
    expect((answer as GateAdmitted<String>).result, 'sent');
  });

  group('entry age', () {
    final recordedAt = DateTime.utc(2026, 11, 24, 8);

    Future<GatedWrite<String>> runAt(
      InMemoryUnknownWriteJournal journal,
      Duration after,
    ) => withClock(
      Clock.fixed(recordedAt.add(after)),
      () =>
          ExchangeWriteGate(journal: journal)
              .run(_main, FinancialWriteKind.payin, () async => 'paid'),
    );

    Future<InMemoryUnknownWriteJournal> journalWithEntry() async {
      final journal = InMemoryUnknownWriteJournal();
      await withClock(
        Clock.fixed(recordedAt),
        () => _record(journal, UnknownWriteKind.buyConfirm),
      );
      return journal;
    }

    test('an open entry up to maxAge holds the gate', () async {
      final answer = await runAt(await journalWithEntry(), UnknownWrite.maxAge);
      expect(answer, isA<GateRefused<String>>());
    });

    test('an open entry older than maxAge no longer holds it', () async {
      final answer = await runAt(
        await journalWithEntry(),
        UnknownWrite.maxAge + const Duration(seconds: 1),
      );
      expect((answer as GateAdmitted<String>).result, 'paid');
    });

    test('a settled entry never holds it, whatever its age', () async {
      final journal = await journalWithEntry();
      final entry = journal.entries.single.$1;
      await journal.settle(entry.id, UnknownWriteSettlement.expired);
      final answer = await runAt(journal, Duration.zero);
      expect((answer as GateAdmitted<String>).result, 'paid');
    });
  });

  test('an unknown recipient create does not hold the gate', () async {
    final journal = InMemoryUnknownWriteJournal();
    await _record(journal, UnknownWriteKind.recipientCreate);
    final gate = ExchangeWriteGate(journal: journal);
    final answer = await gate.run(
      _main,
      FinancialWriteKind.orderCreate,
      () async => 'sent',
    );
    expect(answer, isA<GateAdmitted<String>>());
  });

  test(
    'every journaled kind but recipient and order create holds the gate',
    () {
      expect(
        {
          for (final kind in UnknownWriteKind.values)
            kind: journalEntryHoldsGate(kind),
        },
        {
          UnknownWriteKind.buyConfirm: true,
          UnknownWriteKind.withdrawConfirm: true,
          UnknownWriteKind.accelerate: true,
          UnknownWriteKind.dcaCreate: true,
          UnknownWriteKind.limitOrderCreate: true,
          UnknownWriteKind.defaultWalletSave: true,
          UnknownWriteKind.recipientCreate: false,
          UnknownWriteKind.preferencesSave: true,
          UnknownWriteKind.orderCreate: false,
          UnknownWriteKind.payin: true,
        },
      );
    },
  );

  test('an unreadable journal refuses the write', () async {
    final gate = ExchangeWriteGate(journal: _BrokenJournal());
    var sent = false;
    final answer = await gate.run(
      _main,
      FinancialWriteKind.limitOrderCancel,
      () async {
        sent = true;
        return 'sent';
      },
    );
    expect(sent, isFalse);
    expect(
      (answer as GateRefused<String>).refusal,
      const WriteGateJournalUnreadable(),
    );
    expect(gate.inFlight(ExchangeEnvironment.mainnet), isNull);
  });

  test('a write that throws releases the gate', () async {
    final gate = ExchangeWriteGate();
    await expectLater(
      gate.run<String>(
        _main,
        FinancialWriteKind.preferenceWrite,
        () async => throw StateError('bug'),
      ),
      throwsStateError,
    );
    expect(gate.inFlight(ExchangeEnvironment.mainnet), isNull);
  });

  test('Exchange shares one gate over its journal', () async {
    final journal = InMemoryUnknownWriteJournal();
    final exchange = exchangeForTesting(unknownWrites: journal);
    expect(identical(exchange.writeGate, exchange.writeGate), isTrue);
    final entry = await _record(journal, UnknownWriteKind.defaultWalletSave);
    final answer = await exchange.writeGate.run(
      _main,
      FinancialWriteKind.defaultWalletSave,
      () async => 'sent',
    );
    expect((answer as GateRefused<String>).refusal, WriteGateUnsettled(entry));
  });
}
