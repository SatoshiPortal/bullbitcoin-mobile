import 'dart:async';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

void main() {
  // The first English BIP39 vector. The expected seed is not hardcoded here: it
  // comes from `bip39_mnemonic`, whose own suite already checks that API against
  // the official vectors. These tests cover our use of it, not BIP39 itself.
  const words = [
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
  const passphrase = 'TREZOR';

  late _MockSeedDatasource datasource;
  late SeedRepository repository;
  late List<int> expectedSeedBytes;
  late List<MnemonicSeedModel> storedSeeds;
  late List<String> storedFingerprints;

  setUpAll(() {
    registerFallbackValue(const SeedModel.mnemonic(mnemonicWords: <String>[]));
  });

  setUp(() {
    datasource = _MockSeedDatasource();
    repository = SeedRepository(source: datasource);
    expectedSeedBytes = bip39.Mnemonic.fromWords(
      words: words,
      passphrase: passphrase,
    ).seed;
    storedSeeds = [];
    storedFingerprints = [];
  });

  /// Records what reached the datasource, and whether the event loop got a turn
  /// before it did.
  void stubStore({void Function()? onStore}) {
    when(
      () => datasource.store(
        fingerprint: any(named: 'fingerprint'),
        seed: any(named: 'seed'),
      ),
    ).thenAnswer((invocation) async {
      onStore?.call();
      storedFingerprints.add(
        invocation.namedArguments[const Symbol('fingerprint')] as String,
      );
      storedSeeds.add(
        invocation.namedArguments[const Symbol('seed')] as MnemonicSeedModel,
      );
    });
  }

  test('derives the seed without blocking the calling isolate', () async {
    var yielded = false;
    var yieldedBeforeStore = false;
    stubStore(onStore: () => yieldedBeforeStore = yielded);
    // Fires on the next event-loop turn, so it can only have run if the
    // derivation actually suspended instead of hogging the isolate.
    Timer.run(() => yielded = true);

    final seed = await repository.createFromMnemonic(
      mnemonicWords: words,
      passphrase: passphrase,
    );

    expect(yieldedBeforeStore, isTrue);
    expect(seed.bytes, equals(expectedSeedBytes));
    expect(seed.mnemonicWords, equals(words));
    expect(seed.passphrase, passphrase);
    expect(storedFingerprints, equals([seed.masterFingerprint]));
    expect(storedSeeds.single.mnemonicWords, equals(words));
    expect(storedSeeds.single.passphrase, passphrase);
  });

  test('persists the mnemonic the returned seed was derived from', () async {
    stubStore();
    final callerWords = List<String>.of(words);

    final pending = repository.createFromMnemonic(
      mnemonicWords: callerWords,
      passphrase: passphrase,
    );
    // The caller's list is its own; mutating it while the derivation runs must
    // not change what is persisted under the returned fingerprint.
    callerWords[0] = 'zoo';
    final seed = await pending;

    expect(seed.bytes, equals(expectedSeedBytes));
    expect(seed.mnemonicWords, equals(words));
    expect(storedSeeds.single.mnemonicWords, equals(words));
    expect(storedFingerprints, equals([seed.masterFingerprint]));
  });
}
