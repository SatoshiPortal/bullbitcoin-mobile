import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('CPFP admission keeps its bytes and absolute debit after reopening', () {
    final temp = Directory.systemTemp.createTempSync('ark-exit-cpfp-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = '${temp.path}/state.sqlite';
    final account = ArkAccountId(
      parent: Fingerprint('12345678'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'server',
    );
    final source = Uri.parse('https://esplora.example');
    final quote = ArkQuote(
      id: 'quote',
      account: account,
      generation: 1,
      chainSource: source,
      configGeneration: 1,
      kind: ArkOperationKind.emergencyExit,
      amount: Sats.fromInt(50000),
      fee: Sats.fromInt(200),
      net: Sats.fromInt(49900),
      selectedIds: const ['vtxo'],
      destination: 'chosen-address',
      maxClaimFee: Sats.fromInt(100),
      observedTip: 42,
      validUntil: DateTime.utc(2026, 11, 24),
    );
    ArkOperation operation(
      String id, {
      ArkOperationStatus status = ArkOperationStatus.pending,
    }) => ArkOperation(
      id: id,
      kind: quote.kind,
      status: status,
      chainSource: source,
      configGeneration: quote.configGeneration,
      actualIds: quote.selectedIds,
    );
    bool admit(
      ArkStore store, {
      String opId = 'exit',
      String parent = 'a',
      String child = 'b',
      String input = 'c',
      String raw = '1234',
      int fee = 140,
    }) => store.admitExitCpfp(
      exitOperationId: opId,
      vtxoId: 'vtxo',
      parentTxid: parent * 64,
      childTxid: child * 64,
      raw: raw,
      fee: Sats.fromInt(fee),
      reserveInputs: ['${input * 64}:0'],
    );
    final first = ArkStore.open(path, create: true);
    try {
      first.saveQuote(quote);
      final start = operation('exit', status: ArkOperationStatus.admitted);
      expect(
        first.admitExit(quote, start, requireInitialReserve: true),
        isFalse,
      );
      expect(
        first.bindInitialExitReserve(
          quote: quote,
          reserveAddress: 'reserve',
          funding: ArkExitReserveFunding(
            txid: 'c' * 64,
            amount: Sats.fromInt(1000),
          ),
        ),
        isTrue,
      );
      expect(
        first.admitExit(quote, start, requireInitialReserve: true),
        isTrue,
      );
      expect(admit(first), isFalse);
      first.saveOperation(operation('exit'), quote.id);
      expect(admit(first), isTrue);
    } finally {
      first.close();
    }
    final reopened = ArkStore.open(path, create: false);
    addTearDown(reopened.close);
    expect(reopened.initialExitReserve(quote)?.funding.txid, 'c' * 64);
    expect(
      reopened.exitCpfpEvidence(exitOperationId: 'exit', parentTxid: 'a' * 64),
      (txid: 'b' * 64, raw: '1234', fee: Sats.fromInt(140)),
    );
    expect(
      reopened.exitCpfpEvidence(exitOperationId: 'other', parentTxid: 'a' * 64),
      isNull,
    );
    expect(admit(reopened), isTrue);
    expect(admit(reopened, raw: '1235'), isFalse);
    expect(admit(reopened, parent: 'd', child: 'e', fee: 60), isFalse);
    expect(
      admit(reopened, parent: 'd', child: 'e', input: 'f', fee: 61),
      isFalse,
    );
    reopened.saveOperation(operation('another-exit'), quote.id);
    expect(admit(reopened, opId: 'another-exit', fee: 1), isFalse);
    expect(
      admit(reopened, parent: 'd', child: 'e', input: 'f', fee: 60),
      isTrue,
    );
    expect(reopened.exitCpfpHistory('exit').map((child) => child.txid), [
      'b' * 64,
      'e' * 64,
    ]);
    expect(reopened.exitCpfpHistory('another-exit'), isEmpty);
  });

  test('a reopened reserve can only resume the same exit and funding', () {
    final temp = Directory.systemTemp.createTempSync('ark-exit-reserve-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = '${temp.path}/state.sqlite';
    final account = ArkAccountId(
      parent: Fingerprint('12345678'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'server',
    );
    ArkQuote quote({
      List<String> ids = const ['first', 'second'],
      String destination = 'chosen-address',
      String id = 'original-quote',
    }) => ArkQuote(
      id: id,
      account: account,
      generation: 1,
      chainSource: Uri.parse('https://esplora.example'),
      configGeneration: 1,
      kind: ArkOperationKind.emergencyExit,
      amount: Sats.fromInt(50000),
      fee: Sats.fromInt(200),
      net: Sats.fromInt(49900),
      selectedIds: ids,
      destination: destination,
      observedTip: 42,
      validUntil: DateTime.utc(2026, 11, 24),
    );
    final funding = ArkExitReserveFunding(
      txid: 'a' * 64,
      amount: Sats.fromInt(1000),
    );
    final first = ArkStore.open(path, create: true);
    try {
      expect(
        first.bindInitialExitReserve(
          quote: quote(),
          reserveAddress: 'reserve',
          funding: funding,
        ),
        isTrue,
      );
    } finally {
      first.close();
    }

    final reopened = ArkStore.open(path, create: false);
    addTearDown(reopened.close);
    bool bind(ArkQuote quote, {ArkExitReserveFunding? candidate}) =>
        reopened.bindInitialExitReserve(
          quote: quote,
          reserveAddress: 'reserve',
          funding: candidate ?? funding,
        );
    expect(bind(quote(ids: ['second', 'first'], id: 'new-quote')), isTrue);
    expect(bind(quote(ids: ['first'])), isFalse);
    expect(bind(quote(destination: 'different-address')), isFalse);
    expect(
      bind(
        quote(),
        candidate: ArkExitReserveFunding(
          txid: 'b' * 64,
          amount: funding.amount,
        ),
      ),
      isFalse,
    );
  });
}
