import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  const legacyFunding = {'address': 'board-address', 'index': 7, 'expiry': 42};
  const scuttleFunding = {
    'address': 'board-address',
    'scuttleToken': 'opaque-funding-token',
    'expiry': 42,
  };

  Map<String, Object?> record(Map<String, Object?> funding) => {
    'id': 'board-operation',
    'kind': 'board',
    'status': 'prepared',
    'source': 'https://esplora.example',
    'configGeneration': 1,
    'actual': <String>[],
    'skipped': <String>[],
    'funding': funding,
  };

  test('keeps legacy Bark funding readable without rewriting the index', () {
    final operation = operationFromJson(record(legacyFunding));
    expect(operation.boardFunding?.keypairIndex, 7);
    expect(operation.boardFunding?.scuttleToken, isNull);
    expect(operationToJson(operation)['funding'], legacyFunding);
  });

  test('round-trips Scuttle funding unchanged through durable JSON', () {
    final operation = ArkOperation(
      id: 'board-operation',
      kind: ArkOperationKind.board,
      status: ArkOperationStatus.prepared,
      chainSource: Uri.parse('https://esplora.example'),
      configGeneration: 1,
      boardFunding: ArkBoardFundingDetails.scuttle(
        address: 'board-address',
        token: 'opaque-funding-token',
        expiryHeight: 42,
      ),
    );
    final encoded = operationToJson(operation);
    expect(encoded['funding'], scuttleFunding);
    final reloaded = operationFromJson(
      jsonDecode(jsonEncode(encoded)) as Map<String, Object?>,
    );
    expect(reloaded.boardFunding?.keypairIndex, isNull);
    expect(reloaded.boardFunding?.scuttleToken, 'opaque-funding-token');
  });

  test('rejects mixed, missing and empty funding identities', () {
    for (final funding in [
      {...legacyFunding, 'scuttleToken': 'token'},
      {'address': 'board-address', 'expiry': 42},
      {...scuttleFunding, 'scuttleToken': ''},
    ]) {
      expect(() => operationFromJson(record(funding)), throwsFormatException);
    }
  });

  test('persists board-only evidence with the quoted fees and tip', () {
    final evidence = ArkBoardQuoteEvidence(
      serverKey: '02${'a' * 64}',
      tipHash: 'b' * 64,
      requiredConfirmations: 2,
    );
    final quote = ArkQuote(
      id: 'board-quote',
      account: ArkAccountId(
        parent: Fingerprint('12345678'),
        network: BitcoinNetwork.regtest,
        serverIdentity: 'server',
      ),
      generation: 1,
      chainSource: Uri.parse('https://esplora.example'),
      configGeneration: 1,
      kind: ArkOperationKind.board,
      amount: Sats.fromInt(1000),
      fee: Sats.fromInt(10),
      net: Sats.fromInt(990),
      observedTip: 42,
      validUntil: DateTime.utc(2026, 11, 24),
      boardEvidence: evidence,
    );
    final encoded = quoteToJson(quote);
    expect(quoteToJson(quoteFromJson(encoded)), encoded);
    expect(
      () => quoteFromJson({...encoded, 'kind': 'payment'}),
      throwsFormatException,
    );
    expect(
      quoteFromJson({...encoded}..remove('boardEvidence')).boardEvidence,
      isNull,
    );
  });
}
