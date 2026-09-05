import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

typedef SigningKeyAccountSelection = ({
  int account,
  bool isReserved,
  int? markedAccount,
});

final class SigningKeyAccountSession {
  final Bip48AccountRepository _repository;
  Future<void> _lock = Future.value();
  Bip48AccountClaim? _activeClaim;
  String? _activeFingerprint;
  int? _activeCoinType;
  ({String fingerprint, int coinType, int account})? _committedSelection;

  SigningKeyAccountSession(this._repository);

  @useResult
  Future<Result<SigningKeyAccountSelection, Bip48AccountAllocationFailure>>
  select({
    required String seedFingerprint,
    required int coinType,
    int? account,
    bool markUsed = false,
  }) => _serialized(() async {
    if (markUsed && account == null) {
      return const Err(Bip48AccountAllocationFailure());
    }
    if (!markUsed) _committedSelection = null;
    int? markedAccount;
    final selection = account == null
        ? null
        : (
            fingerprint: seedFingerprint.toLowerCase(),
            coinType: coinType,
            account: account,
          );
    if (markUsed && _committedSelection != selection) {
      final claim = _activeClaim;
      if (account == null ||
          claim == null ||
          claim.account != account ||
          _activeFingerprint?.toLowerCase() != seedFingerprint.toLowerCase() ||
          _activeCoinType != coinType) {
        return const Err(Bip48AccountAllocationFailure());
      }
      final reservation = await _repository.commitClaim(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        claim: claim,
      );
      if (reservation case Err()) {
        return const Err(Bip48AccountAllocationFailure());
      }
      _clearActiveClaim();
      _committedSelection = selection;
    }
    if (markUsed) markedAccount = account;

    if (markUsed || account == null) {
      if (!markUsed) {
        final released = await _releaseActiveClaim();
        if (released case Err()) {
          return const Err(Bip48AccountAllocationFailure());
        }
      }
      final claimResult = await _repository.claimNext(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      return switch (claimResult) {
        Ok(:final value) => Ok((
          account: _rememberClaim(
            value,
            fingerprint: seedFingerprint,
            coinType: coinType,
          ),
          isReserved: false,
          markedAccount: markedAccount,
        )),
        Err() => const Err(Bip48AccountAllocationFailure()),
      };
    }

    final released = await _releaseActiveClaim();
    if (released case Err()) return const Err(Bip48AccountAllocationFailure());
    final reservedResult = await _repository.isReserved(
      seedFingerprint: seedFingerprint,
      coinType: coinType,
      account: account,
    );
    switch (reservedResult) {
      case Ok(value: true):
        return Ok((account: account, isReserved: true, markedAccount: null));
      case Ok(value: false):
        final claimResult = await _repository.claim(
          seedFingerprint: seedFingerprint,
          coinType: coinType,
          account: account,
        );
        return switch (claimResult) {
          Ok(:final value) => Ok((
            account: _rememberClaim(
              value,
              fingerprint: seedFingerprint,
              coinType: coinType,
            ),
            isReserved: false,
            markedAccount: null,
          )),
          Err() => const Err(Bip48AccountAllocationFailure()),
        };
      case Err():
        return const Err(Bip48AccountAllocationFailure());
    }
  });

  @useResult
  Future<Result<void, Bip48AccountAllocationFailure>> release() =>
      _serialized(_releaseActiveClaim);

  Future<Result<void, Bip48AccountAllocationFailure>>
  _releaseActiveClaim() async {
    final claim = _activeClaim;
    final fingerprint = _activeFingerprint;
    final coinType = _activeCoinType;
    if (claim == null || fingerprint == null || coinType == null) {
      return const Ok(null);
    }
    final result = await _repository.releaseClaim(
      seedFingerprint: fingerprint,
      coinType: coinType,
      claim: claim,
    );
    if (result case Ok()) _clearActiveClaim();
    return result;
  }

  int _rememberClaim(
    Bip48AccountClaim claim, {
    required String fingerprint,
    required int coinType,
  }) {
    _committedSelection = null;
    _activeClaim = claim;
    _activeFingerprint = fingerprint;
    _activeCoinType = coinType;
    return claim.account;
  }

  void _clearActiveClaim() {
    _activeClaim = null;
    _activeFingerprint = null;
    _activeCoinType = null;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _lock;
    _lock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}
