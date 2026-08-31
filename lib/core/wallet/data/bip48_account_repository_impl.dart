import 'dart:async';
import 'dart:math';

import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bip48_account_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';

final class Bip48AccountRepositoryImpl implements Bip48AccountRepository {
  final Bip48AccountDatasource _datasource;
  final Bip48AccountUsagePort _usagePort;
  final SeedVerificationPort _seedVerification;
  final Map<(String, int, int), String> _claims = {};
  Future<void> _lock = Future.value();

  Bip48AccountRepositoryImpl(
    this._datasource,
    this._usagePort,
    this._seedVerification,
  );

  @override
  Future<Result<int, Bip48AccountAllocationFailure>> nextAvailable({
    required String seedFingerprint,
    required int coinType,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      final account = _nextAvailable({
        ...accounts,
        ..._claimedAccounts(seedFingerprint, coinType),
      });
      return account == null
          ? const Err(Bip48AccountAllocationFailure())
          : Ok(account);
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<bool, Bip48AccountAllocationFailure>> isReserved({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType) || !_validAccount(account)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      return Ok(accounts.contains(account));
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<int, Bip48AccountAllocationFailure>> reserveNext({
    required String seedFingerprint,
    required int coinType,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      final account = _nextAvailable({
        ...accounts,
        ..._claimedAccounts(seedFingerprint, coinType),
      });
      if (account == null) {
        return const Err(Bip48AccountAllocationFailure());
      }
      accounts.add(account);
      await _datasource.write(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        accounts: accounts,
      );
      return Ok(account);
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claimNext({
    required String seedFingerprint,
    required int coinType,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      final account = _nextAvailable({
        ...accounts,
        ..._claimedAccounts(seedFingerprint, coinType),
      });
      if (account == null) {
        return const Err(Bip48AccountAllocationFailure());
      }
      final token = _claimToken(_claims.values.toSet());
      _claims[_claimKey(seedFingerprint, coinType, account)] = token;
      return Ok(Bip48AccountClaim(account: account, token: token));
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claim({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType) || !_validAccount(account)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      final key = _claimKey(seedFingerprint, coinType, account);
      if (accounts.contains(account) || _claims.containsKey(key)) {
        return const Err(Bip48AccountAllocationFailure());
      }
      final token = _claimToken(_claims.values.toSet());
      _claims[key] = token;
      return Ok(Bip48AccountClaim(account: account, token: token));
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> commitClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType) ||
        !_validAccount(claim.account) ||
        claim.token.isEmpty) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final key = _claimKey(seedFingerprint, coinType, claim.account);
      if (_claims[key] != claim.token) {
        return const Err(Bip48AccountAllocationFailure());
      }
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      accounts.add(claim.account);
      await _datasource.write(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        accounts: accounts,
      );
      _claims.remove(key);
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> releaseClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType) ||
        !_validAccount(claim.account) ||
        claim.token.isEmpty) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final key = _claimKey(seedFingerprint, coinType, claim.account);
      if (_claims[key] == claim.token) {
        _claims.remove(key);
      }
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> reserve({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) => _serialized(() async {
    if (!_validScope(seedFingerprint, coinType) || !_validAccount(account)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    try {
      final accounts = await _readAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      if (_claims.containsKey(_claimKey(seedFingerprint, coinType, account))) {
        return const Err(Bip48AccountAllocationFailure());
      }
      if (!accounts.add(account)) return const Ok(null);
      await _datasource.write(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        accounts: accounts,
      );
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Err(Bip48AccountAllocationFailure());
    }
  });

  bool _validScope(String seedFingerprint, int coinType) =>
      RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(seedFingerprint) &&
      (coinType == 0 || coinType == 1);

  bool _validAccount(int account) =>
      account >= 0 && account <= Bip48Derivation.maxAccount;

  Future<Set<int>> _readAccounts({
    required String seedFingerprint,
    required int coinType,
  }) async {
    final accounts = await _datasource.read(
      seedFingerprint: seedFingerprint,
      coinType: coinType,
    );
    final usages = await _usagePort.getBip48AccountUsages();
    var changed = false;
    for (final usage in usages) {
      if (usage.seedFingerprint.toLowerCase() !=
              seedFingerprint.toLowerCase() ||
          usage.coinType != coinType ||
          accounts.contains(usage.account)) {
        continue;
      }
      final matches = await _seedVerification.matchesXpubs(
        fingerprint: usage.seedFingerprint,
        keys: [(derivationPath: usage.derivationPath, xpub: usage.xpub)],
      );
      if (matches) changed = accounts.add(usage.account) || changed;
    }
    if (changed) {
      await _datasource.write(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        accounts: accounts,
      );
    }
    return accounts;
  }

  int? _nextAvailable(Set<int> accounts) {
    var account = 0;
    while (accounts.contains(account) &&
        account <= Bip48Derivation.maxAccount) {
      account++;
    }
    return account > Bip48Derivation.maxAccount ? null : account;
  }

  Set<int> _claimedAccounts(String seedFingerprint, int coinType) => {
    for (final key in _claims.keys)
      if (key.$1 == seedFingerprint.toLowerCase() && key.$2 == coinType) key.$3,
  };

  (String, int, int) _claimKey(
    String seedFingerprint,
    int coinType,
    int account,
  ) => (seedFingerprint.toLowerCase(), coinType, account);

  String _claimToken(Set<String> existing) {
    final random = Random.secure();
    while (true) {
      final token = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      if (!existing.contains(token)) return token;
    }
  }

  void _logFailure(Object error, StackTrace stackTrace) => log.warning(
    'Failed to access BIP48 account reservations',
    error: error.runtimeType,
    trace: stackTrace,
  );

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _lock;
    _lock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }
}
