import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/legacy_seed.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails every read, with a reason shaped like the worst thing this path
/// could quote back: a keychain error naming a seed key and its words.
class _FailingSecureStorage implements KeyValueStorageDatasource<String> {
  _FailingSecureStorage(this._error);

  final Object _error;

  @override
  Future<Map<String, String>> getAll() async => throw _error;

  @override
  Future<String?> getValue(String key) async => throw _error;

  @override
  Future<void> saveValue({required String key, required String value}) async =>
      throw _error;

  @override
  Future<bool> hasValue(String key) async => throw _error;

  @override
  Future<void> deleteValue(String key) async => throw _error;

  @override
  Future<void> deleteAll() async => throw _error;
}

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

/// The two use-cases return Result now. These unwrap the success value so the
/// assertions stay about the parsing rules, which is what these tests are for.
Future<bool> _legacy(CheckLegacyInstallUsecase usecase) async =>
    (await usecase.execute() as Ok<bool, AppStartupFailure>).value;

Future<List<LegacySeed>> _seeds(GetLegacySeedsUsecase usecase) async =>
    (await usecase.execute() as Ok<List<LegacySeed>, AppStartupFailure>).value;

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
      expect(await _legacy(usecase), isFalse);
    });

    test('returns false when no version marker exists', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage(),
        isAndroid: true,
      );
      expect(await _legacy(usecase), isFalse);
    });

    for (final version in ['0.1.5', '0.2.1', '0.3.0', '0.4.2']) {
      test('returns true for legacy version $version', () async {
        final usecase = CheckLegacyInstallUsecase(
          secureStorage: _InMemorySecureStorage({'version': version}),
          isAndroid: true,
        );
        expect(await _legacy(usecase), isTrue);
      });
    }

    test('returns false for a current version', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage({'version': '6.13.0'}),
        isAndroid: true,
      );
      expect(await _legacy(usecase), isFalse);
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
        expect(await _legacy(usecase), isTrue);
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
      expect(await _legacy(usecase), isFalse);
    });

    test('returns false on a legacy seed when not on Android', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _InMemorySecureStorage({'a1b2c3d4e5f60708': seedJson}),
        isAndroid: false,
      );
      expect(await _legacy(usecase), isFalse);
    });
  });

  // What the l10n test cannot prove: the REAL construction sites hand the
  // failure no reason at all. Startup reads secure storage and the seed
  // repository, so a driver message can name the key it choked on, and these
  // failures are stored in bloc state.
  group('failures carry no reason from the real construction sites', () {
    const leakyReason =
        'PlatformException(-25308, seed_a1b2c3d4 legal winner thank year)';

    test('CheckLegacyInstallUsecase', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _FailingSecureStorage(Exception(leakyReason)),
        isAndroid: true,
      );

      final result = await usecase.execute();

      switch (result) {
        case Ok():
          fail('a failed storage read must not be reported as an answer');
        case Err(:final failure):
          expect(failure, isA<AppStartupLegacyCheckFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('GetLegacySeedsUsecase', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _FailingSecureStorage(Exception(leakyReason)),
      );

      final result = await usecase.execute();

      switch (result) {
        case Ok():
          fail('a failed storage read must not be reported as seeds');
        case Err(:final failure):
          expect(failure, isA<AppStartupLegacySeedsFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('a locked keychain is told apart from a broken read, so the caller '
        'can hold the splash instead of failing', () async {
      final usecase = CheckLegacyInstallUsecase(
        secureStorage: _FailingSecureStorage(const KeychainLockedException()),
        isAndroid: true,
      );

      final result = await usecase.execute();

      expect(
        (result as Err<bool, AppStartupFailure>).failure,
        isA<AppStartupKeychainLockedFailure>(),
      );
    });
  });

  group('GetLegacySeedsUsecase', () {
    test('parses a valid seed and keeps only non-empty passphrases', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _InMemorySecureStorage({'a1b2c3d4e5f60708': seedJson}),
      );

      final seeds = await _seeds(usecase);

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

      final seeds = await _seeds(usecase);

      expect(seeds, hasLength(1));
      expect(seeds.single.fingerprint, 'a1b2c3d4e5f60708');
    });

    test('returns an empty list when the store is empty', () async {
      final usecase = GetLegacySeedsUsecase(
        secureStorage: _InMemorySecureStorage(),
      );
      expect(await _seeds(usecase), isEmpty);
    });
  });
}
