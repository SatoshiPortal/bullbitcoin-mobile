import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_service_port.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_wallet_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymRecoveryAddressLookupResult;
import 'package:meta/meta.dart';

/// Ensures one immutable, merchant-signed Bitcoin fallback destination.
///
/// The server is read before any address is selected. Existing commitments are
/// verified and relabeled; an unregistered merchant reuses one locally pending
/// candidate or selects one fresh external address, labels it, registers it,
/// and requires an exact authenticated readback. No descriptor or key crosses
/// either port.
class EnsureAutomaticFallbackAddressUsecase {
  final AutomaticFallbackWalletPort _wallet;
  final AutomaticFallbackServicePort _service;

  const EnsureAutomaticFallbackAddressUsecase({
    required this._wallet,
    required this._service,
  });

  @useResult
  Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  execute() async {
    try {
      final contextResult = await _wallet.loadCurrentDefaultBitcoinWallet();
      final AutomaticFallbackWalletContext context;
      switch (contextResult) {
        case Ok(:final value):
          context = value;
        case Err(:final failure):
          return Err(failure);
      }

      final lookupResult = await _service.lookup(signer: context.signer);
      final BullnymRecoveryAddressLookupResult lookup;
      switch (lookupResult) {
        case Ok(:final value):
          lookup = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (lookup.isRegistered) {
        return _verifyAndLabel(
          context: context,
          lookup: lookup,
          registeredNow: false,
        );
      }

      final pendingResult = await _wallet.findPendingAddress(context);
      final String? pendingAddress;
      switch (pendingResult) {
        case Ok(:final value):
          pendingAddress = value;
        case Err(:final failure):
          return Err(failure);
      }

      final String candidate;
      if (pendingAddress != null) {
        candidate = pendingAddress;
      } else {
        final freshResult = await _wallet.generateFreshAddress(context);
        switch (freshResult) {
          case Ok(:final value):
            candidate = value;
          case Err(:final failure):
            return Err(failure);
        }
      }

      final prepared = await _verifyOwnershipAndLabel(context, candidate);
      if (prepared case Err(:final failure)) return Err(failure);

      final registration = await _service.register(
        signer: context.signer,
        btcAddress: candidate,
      );
      if (registration case Err(:final failure)) return Err(failure);

      final readbackResult = await _service.lookup(signer: context.signer);
      final BullnymRecoveryAddressLookupResult readback;
      switch (readbackResult) {
        case Ok(:final value):
          readback = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (!readback.isRegistered || readback.btcAddress != candidate) {
        return const Err(AutomaticFallbackFailure.integrityMismatch());
      }
      return _verifyAndLabel(
        context: context,
        lookup: readback,
        registeredNow: true,
      );
    } on Exception {
      return const Err(AutomaticFallbackFailure.unexpected());
    }
  }

  Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  _verifyAndLabel({
    required AutomaticFallbackWalletContext context,
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
    final prepared = await _verifyOwnershipAndLabel(context, address);
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
    AutomaticFallbackWalletContext context,
    String address,
  ) async {
    final ownership = await _wallet.ownsAddress(context, address);
    switch (ownership) {
      case Ok(value: true):
        break;
      case Ok(value: false):
        return const Err(AutomaticFallbackFailure.addressNotOwned());
      case Err(:final failure):
        return Err(failure);
    }
    return _wallet.ensureLabel(context, address);
  }
}
