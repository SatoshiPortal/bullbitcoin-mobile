import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration_liveness.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';

/// DG-3 server-liveness check.
///
/// Run on recovery for the bullnym-backed Lightning Address product. It looks
/// the registration up by the seed-derived npub and:
/// - active:true            -> [live] (no prompt, no re-register);
/// - permanent name + offline -> [needsReactivation] without a write, because
///                                offline is an intentional product state;
/// - active:false + nym     -> silent re-register -> [reregistered], or a
///                             rejection -> [needsReactivation] for legacy
///                             servers only. With [allowReregister] false the
///                             re-register write is skipped and the outcome is
///                             [needsReactivation] instead (read-only mode);
/// - NymNotFound             -> [needsReactivation] (the nym is not recoverable
///                             locally — it is not in the frozen manifest);
/// - network/timeout/server  -> [unreachable] (liveness UNKNOWN; never [live]).
class EnsureLightningAddressRegistrationLiveUsecase {
  // Server-provided error code (bullnym passes it through as the rejection
  // code); a genuinely-missing registration is distinguished from an
  // unreachable server so the UI never blind-heals.
  static const _nymNotFoundCode = 'NymNotFound';

  final LookupWalletOwnedLightningAddressRegistrationUsecase _lookup;
  final RegisterWalletOwnedLightningAddressUsecase _register;

  const EnsureLightningAddressRegistrationLiveUsecase(
    this._lookup,
    this._register,
  );

  /// [allowReregister] governs the single write this check can make: the legacy
  /// active:false + nym silent re-register. Restoration passes it false so
  /// recovery never modifies a Bullnym product (UX-1 / master-doc contract #4);
  /// a lapsed-but-known legacy registration is then reported as
  /// [needsReactivation] for the user-driven flows to reactivate.
  Future<LightningAddressHealOutcome> execute({
    DateTime? deadline,
    bool allowReregister = true,
  }) async {
    if (_deadlineReached(deadline)) return _timedOut;

    final Result<LightningAddressStatus, LightningAddressFailure> lookupResult;
    try {
      final lookup = _lookup.execute();
      lookupResult = deadline == null
          ? await lookup
          : await lookup.timeout(_remaining(deadline));
    } on TimeoutException {
      return _timedOut;
    }
    final LightningAddressStatus status;
    switch (lookupResult) {
      case Ok(:final value):
        status = value;
      case Err(:final failure):
        return LightningAddressHealOutcome(
          liveness: failure.code == _nymNotFoundCode
              ? LightningAddressRegistrationLiveness.needsReactivation
              : LightningAddressRegistrationLiveness.unreachable,
        );
    }
    if (_deadlineReached(deadline)) return _timedOut;

    if (status.active) {
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.live,
        nym: status.nym,
        lightningAddress: status.lightningAddress,
      );
    }

    // Under permanent_names_v1, inactive means the Lightning Address product
    // is deliberately offline; ownership remains on the server. Recovery must
    // reconstruct that state and wait for an explicit user action, never turn
    // the product back on as a side effect of restoring local wallet data.
    final permanentName = status.permanentNameStatus;
    if (permanentName != null) {
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.needsReactivation,
        nym: permanentName.nym,
      );
    }

    // Read-only mode (restoration): never re-register. A lapsed-but-known
    // legacy registration is surfaced for user-driven reactivation instead of
    // being silently turned back on, because recovery must not write to a
    // Bullnym product.
    if (!allowReregister) {
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.needsReactivation,
        nym: status.nym,
      );
    }

    // Preserve the existing legacy-server recovery behavior. Permanent-name
    // servers never enter this path because the typed lookup status above is
    // present only for the exact permanent_names_v1 policy.
    try {
      final registrationRequest = _register.executeFromRecovery(
        nym: status.nym,
      );
      final registrationResult = deadline == null
          ? await registrationRequest
          : await registrationRequest.timeout(_remaining(deadline));
      return switch (registrationResult) {
        Ok(:final value) => LightningAddressHealOutcome(
          liveness: LightningAddressRegistrationLiveness.reregistered,
          nym: value.registration.nym,
          lightningAddress: value.registration.lightningAddress,
        ),
        Err(:final failure) => _needsReactivation(status, failure),
      };
    } on TimeoutException {
      return _timedOut;
    }
  }

  LightningAddressHealOutcome _needsReactivation(
    LightningAddressStatus status,
    LightningAddressFailure failure,
  ) {
    log.warning(
      'Lightning Address silent re-registration failed',
      error: failure.runtimeType,
    );
    return LightningAddressHealOutcome(
      liveness: LightningAddressRegistrationLiveness.needsReactivation,
      nym: status.nym,
    );
  }

  bool _deadlineReached(DateTime? deadline) {
    return deadline != null && !DateTime.now().isBefore(deadline);
  }

  Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static const _timedOut = LightningAddressHealOutcome(
    liveness: LightningAddressRegistrationLiveness.timedOut,
  );
}
