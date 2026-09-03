import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockGetDetails extends Mock implements GetBullVaultDetailsUsecase {}

void main() {
  test('exposes BullVault details for the wallet settings action', () async {
    final getDetails = _MockGetDetails();
    final details = testBullVaultDetails();
    when(
      () => getDetails.execute(details.record.walletId),
    ).thenAnswer((_) async => Ok(details));
    final cubit = BullVaultWalletSettingsCubit(getDetails);

    await cubit.load(details.record.walletId);

    expect(cubit.state, same(details));
    await cubit.close();
  });

  test('hides the action when BullVault details are unavailable', () async {
    final getDetails = _MockGetDetails();
    when(
      () => getDetails.execute('wallet'),
    ).thenAnswer((_) async => const Err(BullVaultCreationFailure()));
    final cubit = BullVaultWalletSettingsCubit(getDetails);

    await cubit.load('wallet');

    expect(cubit.state, isNull);
    await cubit.close();
  });
}
