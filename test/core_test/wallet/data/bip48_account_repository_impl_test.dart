import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/bip48_account_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bip48_account_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_usage.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> values = {};

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<void> deleteValue(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<bool> hasValue(String key) async => values.containsKey(key);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    values[key] = value;
  }
}

final class _UsagePort implements Bip48AccountUsagePort {
  final List<Bip48AccountUsage> usages;

  const _UsagePort([this.usages = const []]);

  @override
  Future<List<Bip48AccountUsage>> getBip48AccountUsages() async => usages;
}

final class _SeedVerification implements SeedVerificationPort {
  final bool matches;

  const _SeedVerification({this.matches = true});

  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) async => matches;
}

void main() {
  const fingerprint = 'deadbeef';

  test('reads the next account without reserving it', () async {
    final repository = _repository(_MemoryStorage());

    expect(
      _account(
        await repository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      0,
    );
    expect(
      _account(
        await repository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      0,
    );
    final reservation = await repository.isReserved(
      seedFingerprint: fingerprint,
      coinType: 0,
      account: 0,
    );
    expect(switch (reservation) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure('$failure'),
    }, isFalse);
  });

  test(
    'commits distinct concurrent claims and preserves them on restart',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);

      final claims = await Future.wait([
        repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
        repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
      ]);
      expect(claims.map((result) => _claim(result).account).toList()..sort(), [
        0,
        1,
      ]);
      for (final result in claims) {
        expect(
          await repository.commitClaim(
            seedFingerprint: fingerprint,
            coinType: 0,
            claim: _claim(result),
          ),
          isA<Ok<void, Bip48AccountAllocationFailure>>(),
        );
      }
      final restored = _repository(storage);

      expect(
        _account(
          await restored.nextAvailable(
            seedFingerprint: fingerprint,
            coinType: 0,
          ),
        ),
        2,
      );
      expect(
        _account(
          await restored.nextAvailable(
            seedFingerprint: fingerprint,
            coinType: 1,
          ),
        ),
        0,
      );
    },
  );

  test(
    'reserves exact accounts without skipping lower free accounts',
    () async {
      final repository = _repository(_MemoryStorage());

      expect(
        await repository.reserve(
          seedFingerprint: fingerprint,
          coinType: 0,
          account: 100,
        ),
        isA<Ok<void, Bip48AccountAllocationFailure>>(),
      );
      expect(
        await repository.reserve(
          seedFingerprint: fingerprint,
          coinType: 0,
          account: 0,
        ),
        isA<Ok<void, Bip48AccountAllocationFailure>>(),
      );
      expect(
        _account(
          await repository.nextAvailable(
            seedFingerprint: fingerprint,
            coinType: 0,
          ),
        ),
        1,
      );
    },
  );

  test('reserving an exact account is idempotent', () async {
    final repository = _repository(_MemoryStorage());

    for (var count = 0; count < 2; count++) {
      expect(
        await repository.reserve(
          seedFingerprint: fingerprint,
          coinType: 0,
          account: 7,
        ),
        isA<Ok<void, Bip48AccountAllocationFailure>>(),
      );
    }
    expect(
      _account(
        await repository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      0,
    );
  });

  test('claims block reuse until they are committed or released', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final first = _claim(
      await repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
    );

    expect(first.account, 0);
    expect(
      _account(
        await repository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      1,
    );

    expect(
      await repository.releaseClaim(
        seedFingerprint: fingerprint,
        coinType: 0,
        claim: first,
      ),
      isA<Ok<void, Bip48AccountAllocationFailure>>(),
    );
    final replacement = _claim(
      await repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
    );
    expect(replacement.account, 0);

    expect(
      await repository.commitClaim(
        seedFingerprint: fingerprint,
        coinType: 0,
        claim: replacement,
      ),
      isA<Ok<void, Bip48AccountAllocationFailure>>(),
    );
    final restored = _repository(storage);
    expect(
      _account(
        await restored.nextAvailable(seedFingerprint: fingerprint, coinType: 0),
      ),
      1,
    );
  });

  test('claims an exact unreserved account without persisting it', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);

    final claim = _claim(
      await repository.claim(
        seedFingerprint: fingerprint,
        coinType: 0,
        account: 7,
      ),
    );

    expect(claim.account, 7);
    expect(
      await repository.claim(
        seedFingerprint: fingerprint,
        coinType: 0,
        account: 7,
      ),
      isA<Err<Bip48AccountClaim, Bip48AccountAllocationFailure>>(),
    );
    final reservation = await repository.isReserved(
      seedFingerprint: fingerprint,
      coinType: 0,
      account: 7,
    );
    expect(switch (reservation) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure('$failure'),
    }, isFalse);

    await repository.releaseClaim(
      seedFingerprint: fingerprint,
      coinType: 0,
      claim: claim,
    );
    expect(
      _claim(
        await repository.claim(
          seedFingerprint: fingerprint,
          coinType: 0,
          account: 7,
        ),
      ).account,
      7,
    );
  });

  test('an exact claim prevents automatic allocation reuse', () async {
    final repository = _repository(_MemoryStorage());

    final exactClaim = _claim(
      await repository.claim(
        seedFingerprint: fingerprint,
        coinType: 0,
        account: 0,
      ),
    );
    final nextClaim = _claim(
      await repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
    );

    expect(exactClaim.account, 0);
    expect(nextClaim.account, 1);
  });

  test('stale claim owners cannot alter a replacement claim', () async {
    final repository = _repository(_MemoryStorage());
    final stale = _claim(
      await repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
    );
    await repository.releaseClaim(
      seedFingerprint: fingerprint,
      coinType: 0,
      claim: stale,
    );
    final current = _claim(
      await repository.claimNext(seedFingerprint: fingerprint, coinType: 0),
    );

    expect(current.account, stale.account);
    expect(current.token, isNot(stale.token));
    expect(
      await repository.releaseClaim(
        seedFingerprint: fingerprint,
        coinType: 0,
        claim: stale,
      ),
      isA<Ok<void, Bip48AccountAllocationFailure>>(),
    );
    expect(
      await repository.commitClaim(
        seedFingerprint: fingerprint,
        coinType: 0,
        claim: stale,
      ),
      isA<Err<void, Bip48AccountAllocationFailure>>(),
    );
    expect(
      await repository.commitClaim(
        seedFingerprint: fingerprint,
        coinType: 0,
        claim: current,
      ),
      isA<Ok<void, Bip48AccountAllocationFailure>>(),
    );
  });

  test('unfinished claims do not consume an account after restart', () async {
    final storage = _MemoryStorage();
    final firstRepository = _repository(storage);
    final claim = _claim(
      await firstRepository.claimNext(
        seedFingerprint: fingerprint,
        coinType: 0,
      ),
    );
    final restartedRepository = _repository(storage);

    expect(claim.account, 0);
    expect(
      _account(
        await restartedRepository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      0,
    );
    expect(
      await restartedRepository.reserve(
        seedFingerprint: fingerprint,
        coinType: 0,
        account: claim.account,
      ),
      isA<Ok<void, Bip48AccountAllocationFailure>>(),
    );
    expect(
      _account(
        await restartedRepository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      1,
    );
  });

  test(
    'reconciles a verified persisted local account before allocation',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(
        storage,
        usages: [
          Bip48AccountUsage(
            seedFingerprint: fingerprint,
            coinType: 0,
            account: 0,
            derivationPath: "m/48'/0'/0'/2'",
            xpub: 'xpub-account-0',
          ),
        ],
      );

      expect(
        _account(
          await repository.nextAvailable(
            seedFingerprint: fingerprint,
            coinType: 0,
          ),
        ),
        1,
      );
      expect(
        _account(
          await _repository(
            storage,
          ).nextAvailable(seedFingerprint: fingerprint, coinType: 0),
        ),
        1,
      );
    },
  );

  test('does not trust an unverified persisted local account', () async {
    final repository = _repository(
      _MemoryStorage(),
      usages: [
        Bip48AccountUsage(
          seedFingerprint: fingerprint,
          coinType: 0,
          account: 0,
          derivationPath: "m/48'/0'/0'/2'",
          xpub: 'xpub-account-0',
        ),
      ],
      matches: false,
    );

    expect(
      _account(
        await repository.nextAvailable(
          seedFingerprint: fingerprint,
          coinType: 0,
        ),
      ),
      0,
    );
  });

  test(
    'reconciles a passphrase account from its verified local seed',
    () async {
      final repository = _repository(
        _MemoryStorage(),
        usages: [
          Bip48AccountUsage(
            seedFingerprint: 'cafebabe',
            localSeedFingerprint: fingerprint,
            coinType: 0,
            account: 0,
            derivationPath: "m/48'/0'/0'/2'",
            xpub: 'xpub-passphrase-account-0',
          ),
        ],
        matches: false,
      );

      expect(
        _account(
          await repository.nextAvailable(
            seedFingerprint: fingerprint,
            coinType: 0,
          ),
        ),
        1,
      );
    },
  );
}

Bip48AccountRepositoryImpl _repository(
  _MemoryStorage storage, {
  List<Bip48AccountUsage> usages = const [],
  bool matches = true,
}) => Bip48AccountRepositoryImpl(
  Bip48AccountDatasource(storage),
  _UsagePort(usages),
  _SeedVerification(matches: matches),
);

int _account(Result<int, Bip48AccountAllocationFailure> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure('$failure'),
    };

Bip48AccountClaim _claim(
  Result<Bip48AccountClaim, Bip48AccountAllocationFailure> result,
) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('$failure'),
};
