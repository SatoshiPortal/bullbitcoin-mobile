import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payjoin/payjoin.dart';

// A valid, statically-generated OHTTP key config (offline test fixture, no
// real relay behind it). Generated once via the vendored `bitcoin-ohttp`
// crate sources (`KeyConfig::new(...).encode()`) so it decodes with
// `OhttpKeys.decode` without any network access; see the PR description for
// how to regenerate it if the wire format ever changes.
final _ohttpKeysBytes = Uint8List.fromList([
  0x01,
  0x00,
  0x16,
  0x04,
  0x52,
  0x73,
  0xda,
  0xa8,
  0xf6,
  0x4c,
  0xdf,
  0x80,
  0x8f,
  0x1e,
  0x94,
  0x03,
  0x98,
  0x09,
  0xf6,
  0x47,
  0xfc,
  0x21,
  0xca,
  0x68,
  0xb2,
  0xbd,
  0x31,
  0xe7,
  0x30,
  0xa9,
  0xc5,
  0x7d,
  0xf3,
  0x68,
  0x84,
  0xb2,
  0xe7,
  0x82,
  0x6e,
  0x2f,
  0xa1,
  0xad,
  0x2b,
  0x9f,
  0x23,
  0x88,
  0x15,
  0x76,
  0x5a,
  0xa6,
  0x7b,
  0x1f,
  0x56,
  0xcc,
  0x72,
  0xc6,
  0x69,
  0x83,
  0x40,
  0x69,
  0x89,
  0x86,
  0x87,
  0x80,
  0xee,
  0x59,
  0x9b,
  0x1f,
  0x00,
  0x04,
  0x00,
  0x01,
  0x00,
  0x03,
]);

OhttpKeys _fakeOhttpKeys() => OhttpKeys.decode(bytes: _ohttpKeysBytes);

void main() {
  group('InMemoryJsonReceiverSessionPersister', () {
    test('save appends events and load returns them in order', () {
      final persister = InMemoryJsonReceiverSessionPersister();

      persister.save('a');
      persister.save('b');

      expect(persister.load(), ['a', 'b']);
      expect(persister.events, ['a', 'b']);
    });

    test('events is unmodifiable', () {
      final persister = InMemoryJsonReceiverSessionPersister();
      persister.save('a');

      expect(() => persister.events.add('b'), throwsUnsupportedError);
    });

    test('close marks the persister as closed', () {
      final persister = InMemoryJsonReceiverSessionPersister();

      expect(persister.isClosed, isFalse);
      persister.close();
      expect(persister.isClosed, isTrue);
    });

    test('toJson/fromJson round-trips the event log', () {
      final persister = InMemoryJsonReceiverSessionPersister();
      persister.save('a');
      persister.save('b');

      final restored = InMemoryJsonReceiverSessionPersister.fromJson(
        persister.toJson(),
      );

      expect(restored.load(), ['a', 'b']);
    });

    test('fromJson(null) starts with an empty event log', () {
      final persister = InMemoryJsonReceiverSessionPersister.fromJson(null);

      expect(persister.load(), isEmpty);
    });

    test('fromJson gracefully handles malformed input', () {
      final notJson = InMemoryJsonReceiverSessionPersister.fromJson(
        'not valid json',
      );
      final notAList = InMemoryJsonReceiverSessionPersister.fromJson(
        jsonEncode({'not': 'a list'}),
      );

      expect(notJson.load(), isEmpty);
      expect(notAList.load(), isEmpty);
    });
  });

  group('InMemoryJsonSenderSessionPersister', () {
    test('save appends events and load returns them in order', () {
      final persister = InMemoryJsonSenderSessionPersister();

      persister.save('x');
      persister.save('y');

      expect(persister.load(), ['x', 'y']);
      expect(persister.events, ['x', 'y']);
    });

    test('events is unmodifiable', () {
      final persister = InMemoryJsonSenderSessionPersister();
      persister.save('x');

      expect(() => persister.events.add('y'), throwsUnsupportedError);
    });

    test('close marks the persister as closed', () {
      final persister = InMemoryJsonSenderSessionPersister();

      expect(persister.isClosed, isFalse);
      persister.close();
      expect(persister.isClosed, isTrue);
    });

    test('toJson/fromJson round-trips the event log', () {
      final persister = InMemoryJsonSenderSessionPersister();
      persister.save('x');
      persister.save('y');

      final restored = InMemoryJsonSenderSessionPersister.fromJson(
        persister.toJson(),
      );

      expect(restored.load(), ['x', 'y']);
    });

    test('fromJson(null) starts with an empty event log', () {
      final persister = InMemoryJsonSenderSessionPersister.fromJson(null);

      expect(persister.load(), isEmpty);
    });

    test('fromJson gracefully handles malformed input', () {
      final notJson = InMemoryJsonSenderSessionPersister.fromJson(
        'not valid json',
      );
      final notAList = InMemoryJsonSenderSessionPersister.fromJson(
        jsonEncode({'not': 'a list'}),
      );

      expect(notJson.load(), isEmpty);
      expect(notAList.load(), isEmpty);
    });
  });

  group('PdkPayjoinDatasource.fetchOhttpKeyAndRelay', () {
    // These exercise the multi-relay fallback loop with an injected fetcher,
    // entirely offline: PayjoinConstants.ohttpRelayUrls is shuffled on every
    // access (see lib/core/utils/constants.dart), so the loop's *order* isn't
    // asserted here, only its "try until one works, else give up" contract.

    test('returns the keys and relay for the relay that succeeds', () async {
      final keys = _fakeOhttpKeys();
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              if (ohttpRelayUrl != 'https://pj.bobspacebkk.com') {
                throw Exception('relay unavailable: $ohttpRelayUrl');
              }
              return keys;
            },
      );

      final (resultKeys, resultRelay) = await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://payjo.in',
      );

      expect(resultKeys, same(keys));
      expect(resultRelay, 'https://pj.bobspacebkk.com');
    });

    test('returns (null, null) when every relay fails', () async {
      final attemptedRelays = <String>{};
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              attemptedRelays.add(ohttpRelayUrl);
              throw Exception('relay unavailable: $ohttpRelayUrl');
            },
      );

      final (resultKeys, resultRelay) = await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://payjo.in',
      );

      expect(resultKeys, isNull);
      expect(resultRelay, isNull);
      // Every known relay must have been attempted before giving up.
      expect(attemptedRelays, {
        'https://ohttp.achow101.com',
        'https://pj.bobspacebkk.com',
        'https://ohttp.cakewallet.com',
      });
    });

    test('passes the requested directory URL through to the fetcher', () async {
      final seenDirectories = <String>{};
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              seenDirectories.add(directoryUrl);
              throw Exception('relay unavailable: $ohttpRelayUrl');
            },
      );

      await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://my-directory.example',
      );

      expect(seenDirectories, {'https://my-directory.example'});
    });
  });
}
