import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_registration_options_usecase.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_registration_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletRegistrationOptionsUsecase extends Mock
    implements GetWalletRegistrationOptionsUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockGetWalletRegistrationOptionsUsecase getOptions;
  late WalletRegistrationCubit cubit;

  setUp(() {
    getOptions = _MockGetWalletRegistrationOptionsUsecase();
    cubit = WalletRegistrationCubit(getOptions);
  });

  tearDown(() => cubit.close());

  test('loads registration options', () async {
    final wallet = _MockWallet();
    const options = [
      ConnectedWalletRegistration(device: SignerDeviceEntity.ledgerNanoX),
    ];
    when(
      () => getOptions.execute(wallet),
    ).thenAnswer((_) async => const Ok(options));

    await cubit.load(wallet);

    expect(cubit.state.options, same(options));
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.failure, isNull);
  });

  test('holds a typed failure so loading can be retried', () async {
    final wallet = _MockWallet();
    when(
      () => getOptions.execute(wallet),
    ).thenAnswer((_) async => const Err(SettingsWalletRegistrationFailure()));

    await cubit.load(wallet);

    expect(cubit.state.options, isEmpty);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.failure, isA<SettingsWalletRegistrationFailure>());
  });
}
