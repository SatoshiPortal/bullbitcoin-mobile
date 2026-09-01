import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

// Obviously-fake fixture: the all-zero BIP39 test vector.
const _words = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];

/// The first twelve entries of the English wordlist. Used where the fixture
/// has to survive a `Set` (which would collapse the repeated `abandon`s).
const _distinctWords = [
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
  'absurd',
  'abuse',
  'access',
  'accident',
];

void main() {
  late Directory dir;
  late Logger logger;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bb_logger_sanitize');
    logger = Logger.replace(directory: dir);
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  /// Writes [message] through the real logging pipeline and returns what
  /// landed on disk, which is the sanitized form.
  Future<String> written(Object? message) async {
    await logger.ensureLogsExist();
    logger.warning(message);
    await logger.flush();
    return logger.logsFile.readAsString();
  }

  test('redacts a mnemonic written as a sentence', () async {
    expect(await written(_words.join(' ')), isNot(contains('abandon')));
  });

  test('redacts a mnemonic dumped as a list', () async {
    // The sentence rule needs whitespace-separated words, so a `List<String>`
    // dump — `[abandon, abandon, ..., about]` — used to go through verbatim.
    final line = await written('seed words: $_words');
    expect(line, isNot(contains('abandon')));
    expect(line, isNot(contains('about')));
    expect(line, contains('[REDACTED]'));
  });

  test('redacts a mnemonic dumped as a set or a record', () async {
    expect(
      await written(_distinctWords.toSet().toString()),
      isNot(contains('accident')),
    );
    expect(
      await written('(${_distinctWords.join(', ')})'),
      isNot(contains('accident')),
    );
  });

  test('redacts a mnemonic nested inside a longer list', () async {
    // The closing delimiter is not part of the rule, so a wordlist that is
    // only part of a bigger dump is still caught.
    final line = await written('${['wallet-id', ..._words, 'trailing']}');
    expect(line, isNot(contains('abandon')));
    expect(line, isNot(contains('about')));
  });

  test('leaves ordinary collection dumps alone', () async {
    // False-positive guards: the rule needs twelve or more bare lowercase
    // 3-8 letter words behind a collection delimiter, which ordinary log
    // content does not produce.
    expect(await written('[bitcoin, liquid, lightning]'), contains('bitcoin'));
    expect(
      await written('${{'network': 'bitcoin', 'label': 'savings'}}'),
      contains('savings'),
    );
    expect(
      await written('[Network.bitcoinMainnet, Network.liquidMainnet]'),
      contains('Network.bitcoinMainnet'),
    );
    final longEnough = List.generate(14, (index) => 'Item$index');
    expect(await written('$longEnough'), contains('Item0'));
  });
}
