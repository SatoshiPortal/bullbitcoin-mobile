import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

const _words = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'legal',
  'winner',
  'thank',
  'yellow',
];

void main() {
  late Logger previous;
  late Directory directory;

  setUp(() async {
    previous = log;
    directory = await Directory.systemTemp.createTemp('logger-sanitize-');
    log = Logger.replace(directory: directory);
  });

  tearDown(() async {
    await log.flush();
    log = Logger.replace(directory: previous.dir);
    await directory.delete(recursive: true);
  });

  Future<String> written(String message) async {
    log.warning(message);
    final lines = await log.readLogs();
    return lines.lastWhere((line) => line.contains('WARNING'));
  }

  for (final (name, message) in [
    ('spaces', 'words: ${_words.join(' ')}'),
    ('a JSON array', '{"mnemonicWords":["${_words.join('","')}"]}'),
    ('a freezed toString', 'Seed(mnemonicWords: [${_words.join(', ')}])'),
  ]) {
    test('redacts a mnemonic separated by $name', () async {
      final line = await written(message);
      expect(line, contains('[REDACTED]'));
      expect(line, isNot(contains('sausage')));
    });
  }

  test('redacts all of a 24 word mnemonic that follows other words', () async {
    final mnemonic = [..._words, ..._words.take(11), 'zebra'].join(' ');
    final line = await written('Failed while importing the wallet $mnemonic');
    expect(line, contains('Failed while importing [REDACTED]'));
    expect(line, isNot(contains('zebra')));
  });

  test('keeps an ordinary log sentence', () async {
    const sentence = 'Failed to sync wallet, retrying in a few seconds';
    expect(await written(sentence), contains(sentence));
  });

  test('keeps a sentence whose contractions would chain it', () async {
    const sentence =
        "The wallet didn't sync because the node wasn't reachable and the "
        "server couldn't respond either";
    expect(await written(sentence), contains(sentence));
  });
}
