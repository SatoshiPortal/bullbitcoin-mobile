import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_legacy_seeds_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySecureStorage implements KeyValueStorageDatasource<String> {
  _InMemorySecureStorage([this._entries = const {}]);

  final Map<String, String> _entries;

  @override
  Future<Map<String, String>> getAll() async => Map.of(_entries);

  @override
  Future<String?> getValue(String key) async => _entries[key];

  @override
  Future<void> saveValue({required String key, required String value}) async =>
      _entries[key] = value;

  @override
  Future<bool> hasValue(String key) async => _entries.containsKey(key);

  @override
  Future<void> deleteValue(String key) async => _entries.remove(key);

  @override
  Future<void> deleteAll() async => _entries.clear();
}

void main() {
  const seedJson =
      '{"mnemonic":"zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong",'
      '"mnemonicFingerprint":"a1b2c3d4e5f60708","network":"Mainnet",'
      '"passphrases":['
      '{"passphrase":"secret","sourceFingerprint":"a1b2c3d4e5f60708"},'
      '{"passphrase":"","sourceFingerprint":"bbbbbbbbbbbbbbbb"}'
      ']}';

  group('CheckLegacyInstallUsecase', () {
    test('returns false on non-Android even with a marker', () async {
      final storage = _InMemorySecureStorage({'version': '0.4.2'});
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: storage,
        isAndroid: false,
      );
      expect(await usecase.execute(), isFalse);
    });

    test('returns false when no version marker exists', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage(),
        isAndroid: true,
      );
      expect(await usecase.execute(), isFalse);
    });

    for (final version in ['0.1.5', '0.2.1', '0.3.0', '0.4.2']) {
      test('returns true for legacy version $version', () async {
        final usecase = CheckLegacyInstallUsecase(
          secureStorage: _InMemorySecureStorage({'version': version}),
          isAndroid: true,
        );
        expect(await usecase.execute(), isTrue);
      });
    }

    test('returns false for a current version', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage({'version': '6.13.0'}),
        isAndroid: true,
      );
      expect(await usecase.execute(), isFalse);
    });

    test(
      'returns true on a legacy seed even without a version marker',
      () async {
        // The marker could not be read on a real 0.4.3 → 6.13 upgrade; the seed
        // material is the signal that must not be missed.
        final usecase = CheckLegacyInstallUsecase(
          secureStorage: _InMemorySecureStorage({'a1b2c3d4e5f60708': seedJson}),
          isAndroid: true,
        );
        expect(await usecase.execute(), isTrue);
      },
    );

    test('returns false when only current-format seeds exist', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage({
          // Current seeds are keyed `seed_<fingerprint>`, so they can never
          // parse as legacy (which requires key == fingerprint).
          'seed_a1b2c3d4e5f60708': seedJson,
        }),
        isAndroid: true,
      );
      expect(await usecase.execute(), isFalse);
    });

    test('returns false on a legacy seed when not on Android', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage({'a1b2c3d4e5f60708': seedJson}),
        isAndroid: false,
      );
      expect(await usecase.execute(), isFalse);
    });
  });

  group('GetLegacySeedsUsecase', () {
    test('parses a valid seed and keeps only non-empty passphrases', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _InMemorySecureStorage({'a1b2c3d4e5f60708': seedJson}),
      );

      final seeds = await usecase.execute();

      expect(seeds, hasLength(1));
      expect(seeds.single.fingerprint, 'a1b2c3d4e5f60708');
      expect(seeds.single.words, hasLength(12));
      expect(seeds.single.passphrases, ['secret']);
    });

    test('skips entries that are not legacy seeds', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _InMemorySecureStorage({
          'a1b2c3d4e5f60708': seedJson,
          'notJson': 'plain-string-value',
          'noMnemonic': '{"mnemonicFingerprint":"a1b2c3d4e5f60708"}',
          'wrongKey': seedJson, // key != fingerprint
          'emptyMnemonic':
              '{"mnemonic":"","mnemonicFingerprint":"cccccccccccccccc"}',
        }),
      );

      final seeds = await usecase.execute();

      expect(seeds, hasLength(1));
      expect(seeds.single.fingerprint, 'a1b2c3d4e5f60708');
    });

    test('returns an empty list when the store is empty', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _InMemorySecureStorage(),
      );
      expect(await usecase.execute(), isEmpty);
    });
  });
}
