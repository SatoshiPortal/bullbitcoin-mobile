import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/secret_repository.dart';
import 'package:secrets/src/domain/failures.dart';

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bullbitcoin.secrets/legacy_reader');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SecretRepository repository;
  late FakeSecureStoragePlatform normal;
  late Map<String, String> entries;
  late List<String> calls;

  setUp(() {
    normal = FakeSecureStoragePlatform()..install();
    repository = SecretRepository(legacyReadOnly: true);
    calls = [];
    // Published BIP39 vector; never a wallet used for funds.
    entries = {
      'seed_73c5da0a': jsonEncode({
        'runtimeType': 'mnemonic',
        'mnemonicWords': [...List.filled(11, 'abandon'), 'about'],
        'passphrase': null,
      }),
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'format': 'cbc', 'entries': entries};
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'validated legacy material is read without opening the normal plugin',
    () async {
      final listing = ok(await repository.describeAll());
      expect(listing.unreadable, isEmpty);
      final info = listing.secrets.single;
      expect(info.id.hex, '73c5da0a');
      expect(
        ok(await repository.use(info, (material) => material.id)),
        info.id,
      );
      expect(calls, everyElement('readLegacy'));
      expect(normal.entries, isEmpty);
      expect(normal.reads, 0);
    },
  );

  test(
    'CBC plaintext with a valid checksum but a wrong fingerprint is refused',
    () async {
      entries['seed_deadbeef'] = entries.remove('seed_73c5da0a')!;
      final info = ok(await repository.describeAll()).secrets.single;
      expect(
        await repository.use(info, (_) => true),
        isA<Err<bool, SecretFailure>>(),
      );
      final result = await repository.use(info, (_) => true);
      expect((result as Err).failure, isA<FingerprintMismatchFailure>());
      expect(normal.entries, isEmpty);
      expect(normal.reads, 0);
    },
  );

  test(
    'invalid stored envelopes remain unreadable and deletion is refused',
    () async {
      entries['seed_73c5da0a'] =
          '{"runtimeType":"mnemonic","mnemonicWords":[]}';
      final listing = ok(await repository.describeAll());
      expect(listing.secrets, isEmpty);
      expect(listing.unreadable, hasLength(1));
      expect(
        await repository.trash(Fingerprint('73c5da0a')),
        isA<Err<void, SecretFailure>>(),
      );
      expect(normal.entries, isEmpty);
      expect(normal.reads, 0);
      expect(calls, everyElement('readLegacy'));
    },
  );
}
