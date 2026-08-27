import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:meta/meta.dart';

const String automaticFallbackAddressOriginPrefix = 'automatic-fallback:';

/// Ensures that Bullnym has one verified fallback address owned by the current
/// default Bitcoin wallet.
final class EnsureAutomaticFallbackAddressUsecase {
  final GetSettingsUsecase _getSettings;
  final WalletRepository _wallets;
  final WalletAddressRepository _addresses;
  final BitcoinWalletRepository _bitcoinWallet;
  final LabelsFacade _labels;
  final Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  Function()
  _lookupRemote;
  final Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  Function(String address)
  _registerRemote;

  const EnsureAutomaticFallbackAddressUsecase(
    this._getSettings,
    this._wallets,
    this._addresses,
    this._bitcoinWallet,
    this._labels,
    this._lookupRemote,
    this._registerRemote,
  );

  @useResult
  Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  execute() async {
    final walletResult = await _defaultWalletId();
    final String walletId;
    switch (walletResult) {
      case Ok(:final value):
        walletId = value;
      case Err(:final failure):
        return Err(failure);
    }

    final lookupResult = await _lookupRemote();
    final BullnymRecoveryAddressLookupResult lookup;
    switch (lookupResult) {
      case Ok(:final value):
        lookup = value;
      case Err(:final failure):
        return Err(_mapRemoteFailure(failure, lookup: true));
    }
    if (lookup.isRegistered) {
      return _verifyAndLabel(
        walletId: walletId,
        lookup: lookup,
        registeredNow: false,
      );
    }

    final pendingResult = await _findPendingAddress(walletId);
    final String? pending;
    switch (pendingResult) {
      case Ok(:final value):
        pending = value;
      case Err(:final failure):
        return Err(failure);
    }

    final candidateResult = pending == null
        ? await _generateAddress(walletId)
        : Ok<String, AutomaticFallbackFailure>(pending);
    final String candidate;
    switch (candidateResult) {
      case Ok(:final value):
        candidate = value;
      case Err(:final failure):
        return Err(failure);
    }

    final prepared = await _verifyOwnershipAndLabel(walletId, candidate);
    if (prepared case Err(:final failure)) return Err(failure);

    final registration = await _registerRemote(candidate);
    if (registration case Err(:final failure)) {
      return Err(_mapRemoteFailure(failure, lookup: false));
    }

    final readback = await _lookupRemote();
    switch (readback) {
      case Err(:final failure):
        return Err(_mapRemoteFailure(failure, lookup: true));
      case Ok(:final value)
          when !value.isRegistered || value.btcAddress != candidate:
        return const Err(AutomaticFallbackFailure.integrityMismatch());
      case Ok(:final value):
        return _verifyAndLabel(
          walletId: walletId,
          lookup: value,
          registeredNow: true,
        );
    }
  }

  Future<Result<String, AutomaticFallbackFailure>> _defaultWalletId() async {
    try {
      final settings = await _getSettings.execute();
      if (!settings.environment.isMainnet) {
        return const Err(AutomaticFallbackFailure.unsupportedNetwork());
      }
      final ids = await _wallets.getDefaultBitcoinWalletIds(
        environment: settings.environment,
      );
      return switch (ids) {
        [] => const Err(AutomaticFallbackFailure.noDefaultBitcoinWallet()),
        [final id] => Ok(id),
        _ => const Err(
          AutomaticFallbackFailure.ambiguousDefaultBitcoinWallet(),
        ),
      };
    } on Exception {
      return const Err(AutomaticFallbackFailure.walletLookupFailed());
    }
  }

  Future<Result<String?, AutomaticFallbackFailure>> _findPendingAddress(
    String walletId,
  ) async {
    try {
      final expectedOrigin = _origin(walletId);
      final candidates = (await _labels.fetchAll())
          .where(
            (label) =>
                label.type == LabelType.address &&
                label.label == LabelSystem.automaticFallback.label &&
                label.origin == expectedOrigin,
          )
          .map((label) => label.reference)
          .toSet();
      final owned = <String>[];
      for (final candidate in candidates) {
        if (await _bitcoinWallet.isAddressOfWallet(
          candidate,
          walletId: walletId,
        )) {
          owned.add(candidate);
        }
      }
      return switch (owned) {
        [] => const Ok(null),
        [final address] => Ok(address),
        _ => const Err(AutomaticFallbackFailure.conflictingLocalReservations()),
      };
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressSelectionFailed());
    }
  }

  Future<Result<String, AutomaticFallbackFailure>> _generateAddress(
    String walletId,
  ) async {
    try {
      final address = await _addresses.generateNewReceiveAddress(
        walletId: walletId,
      );
      return Ok(address.address);
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressSelectionFailed());
    }
  }

  Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  _verifyAndLabel({
    required String walletId,
    required BullnymRecoveryAddressLookupResult lookup,
    required bool registeredNow,
  }) async {
    final address = lookup.btcAddress;
    final commitmentVersion = lookup.commitmentVersion;
    final signedAtUnix = lookup.signedAtUnix;
    if (address == null ||
        address.isEmpty ||
        commitmentVersion == null ||
        commitmentVersion <= 0 ||
        signedAtUnix == null ||
        signedAtUnix < 0) {
      return const Err(AutomaticFallbackFailure.integrityMismatch());
    }
    final prepared = await _verifyOwnershipAndLabel(walletId, address);
    if (prepared case Err(:final failure)) return Err(failure);
    return Ok(
      AutomaticFallbackSetup(
        btcAddress: address,
        commitmentVersion: commitmentVersion,
        signedAtUnix: signedAtUnix,
        registeredNow: registeredNow,
      ),
    );
  }

  Future<Result<void, AutomaticFallbackFailure>> _verifyOwnershipAndLabel(
    String walletId,
    String address,
  ) async {
    try {
      if (!await _bitcoinWallet.isAddressOfWallet(
        address,
        walletId: walletId,
      )) {
        return const Err(AutomaticFallbackFailure.addressNotOwned());
      }
    } on Exception {
      return const Err(AutomaticFallbackFailure.addressVerificationFailed());
    }

    try {
      final stored = await _labels.store(
        NewLabel.addr(
          address: address,
          label: LabelSystem.automaticFallback.label,
          origin: _origin(walletId),
        ),
      );
      return switch (stored) {
        Ok() => const Ok(null),
        Err() => const Err(AutomaticFallbackFailure.labelPersistenceFailed()),
      };
    } on Exception {
      return const Err(AutomaticFallbackFailure.labelPersistenceFailed());
    }
  }

  AutomaticFallbackFailure _mapRemoteFailure(
    BullnymFailure failure, {
    required bool lookup,
  }) {
    if (failure is BullnymAuthenticationFailure) {
      return const AutomaticFallbackFailure.signingUnavailable();
    }
    final retryable =
        failure is BullnymNetworkFailure ||
        (failure is BullnymServerFailure && failure.retryable);
    final code = failure is BullnymServerFailure
        ? failure.code
        : failure.runtimeType.toString();
    return lookup
        ? AutomaticFallbackFailure.remoteLookupFailed(
            code: code,
            retryable: retryable,
          )
        : AutomaticFallbackFailure.remoteRegistrationFailed(
            code: code,
            retryable: retryable,
          );
  }

  String _origin(String walletId) =>
      '$automaticFallbackAddressOriginPrefix$walletId';
}
