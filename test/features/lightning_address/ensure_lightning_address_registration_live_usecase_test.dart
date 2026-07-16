import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration_liveness.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/ensure_lightning_address_registration_live_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live registration does not re-register', () async {
    final register = _FakeRegister();
    final usecase = EnsureLightningAddressRegistrationLiveUsecase(
      lookup: _FakeLookup(
        status: const LightningAddressStatus(
          nym: 'alice',
          active: true,
          lightningAddress: 'alice@example.invalid',
        ),
      ),
      register: register,
    );

    final outcome = await usecase.execute();

    expect(outcome.liveness, LightningAddressRegistrationLiveness.live);
    expect(register.nyms, isEmpty);
  });

  test('inactive registration silently re-registers without backup', () async {
    final register = _FakeRegister();
    final usecase = EnsureLightningAddressRegistrationLiveUsecase(
      lookup: _FakeLookup(
        status: const LightningAddressStatus(nym: 'alice', active: false),
      ),
      register: register,
    );

    final outcome = await usecase.execute();

    expect(outcome.liveness, LightningAddressRegistrationLiveness.reregistered);
    expect(register.nyms, ['alice']);
    expect(register.publishFlags, [false]);
  });

  test('missing registration needs reactivation without blind heal', () async {
    final register = _FakeRegister();
    final usecase = EnsureLightningAddressRegistrationLiveUsecase(
      lookup: _FakeLookup(
        error: const LightningAddressServerRejectedRequestException(
          code: 'NymNotFound',
          retryable: false,
        ),
      ),
      register: register,
    );

    final outcome = await usecase.execute();

    expect(
      outcome.liveness,
      LightningAddressRegistrationLiveness.needsReactivation,
    );
    expect(register.nyms, isEmpty);
  });

  test('lookup failure reports unreachable without blind heal', () async {
    final register = _FakeRegister();
    final usecase = EnsureLightningAddressRegistrationLiveUsecase(
      lookup: _FakeLookup(
        error: const LightningAddressNetworkException(
          code: 'NetworkError',
          retryable: true,
        ),
      ),
      register: register,
    );

    final outcome = await usecase.execute();

    expect(outcome.liveness, LightningAddressRegistrationLiveness.unreachable);
    expect(register.nyms, isEmpty);
  });
}

final class _FakeLookup
    implements LookupWalletOwnedLightningAddressRegistrationUsecase {
  final LightningAddressStatus? status;
  final Object? error;

  const _FakeLookup({this.status, this.error});

  @override
  Future<LightningAddressStatus> execute() async {
    final error = this.error;
    if (error != null) throw error;
    return status!;
  }
}

final class _FakeRegister
    implements RegisterWalletOwnedLightningAddressUsecase {
  final List<String> nyms = [];
  final List<bool> publishFlags = [];

  @override
  Future<WalletOwnedLightningAddressRegistration> execute({
    required String nym,
    bool publishBackupSnapshot = true,
  }) async {
    nyms.add(nym);
    publishFlags.add(publishBackupSnapshot);
    return WalletOwnedLightningAddressRegistration(
      registration: LightningAddressRegistration(
        nym: nym,
        lightningAddress: '$nym@example.invalid',
      ),
      walletId: 'la-wallet',
      walletCreated: false,
    );
  }
}
