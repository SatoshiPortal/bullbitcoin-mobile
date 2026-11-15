import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ScanHistory history;
  final time = DateTime(2026);

  setUp(() => history = ScanHistory());

  test('keeps the newest entry first', () {
    history.add(const TransactionIdContent(txid: 'a'), time: time);
    history.add(const TransactionIdContent(txid: 'b'), time: time);

    expect(history.entries.map((entry) => entry.content.copyText), ['b', 'a']);
  });

  test('a repeated scan moves to the top without a duplicate', () {
    history.add(const TransactionIdContent(txid: 'a'), time: time);
    history.add(const TransactionIdContent(txid: 'b'), time: time);
    history.add(const TransactionIdContent(txid: 'a'), time: DateTime(2027));

    expect(history.entries.map((entry) => entry.content.copyText), ['a', 'b']);
    expect(history.entries.first.time, DateTime(2027));
  });

  test('the same text of another type is a separate entry', () {
    history.add(const TransactionIdContent(txid: 'a'), time: time);
    history.add(const PsbtContent(psbt: 'a'), time: time);

    expect(history.entries, hasLength(2));
  });

  test('keeps at most twenty entries', () {
    for (var i = 0; i < 25; i++) {
      history.add(TransactionIdContent(txid: '$i'), time: time);
    }

    expect(history.entries, hasLength(ScanHistory.maxEntries));
    expect(history.entries.first.content.copyText, '24');
    expect(history.entries.last.content.copyText, '5');
  });

  test('never keeps a secret or a label export', () {
    history.add(const RecoveryPhraseContent(), time: time);
    history.add(const PrivateKeyContent(), time: time);
    history.add(const LabelsExportContent(jsonl: '{}', count: 1), time: time);

    expect(history.entries, isEmpty);
  });

  test('clear removes every entry', () {
    history.add(const TransactionIdContent(txid: 'a'), time: time);
    history.clear();

    expect(history.entries, isEmpty);
  });
}
