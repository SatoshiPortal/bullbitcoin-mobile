import 'package:bb_mobile/features/lightning_address/domain/usecases/ensure_lightning_address_registration_live_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/lightning_address_locator.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('registers only the public facade and presentation cubit', () {
    final getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);

    LightningAddressLocator.setup(getIt);

    expect(getIt.isRegistered<LightningAddressFacade>(), isTrue);
    expect(getIt.isRegistered<LightningAddressActivationCubit>(), isTrue);
    expect(getIt.isRegistered<PrepareLightningAddressWalletUsecase>(), isFalse);
    expect(getIt.isRegistered<RegisterLightningAddressUsecase>(), isFalse);
    expect(
      getIt.isRegistered<RegisterWalletOwnedLightningAddressUsecase>(),
      isFalse,
    );
    expect(
      getIt
          .isRegistered<LookupWalletOwnedLightningAddressRegistrationUsecase>(),
      isFalse,
    );
    expect(
      getIt.isRegistered<EnsureLightningAddressRegistrationLiveUsecase>(),
      isFalse,
    );
  });
}
