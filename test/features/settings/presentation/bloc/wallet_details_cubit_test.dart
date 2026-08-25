import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletPolicyUsecase extends Mock
    implements GetWalletPolicyUsecase {}

void main() {
  late _MockGetWalletPolicyUsecase getWalletPolicy;
  late WalletDetailsCubit cubit;

  setUp(() {
    getWalletPolicy = _MockGetWalletPolicyUsecase();
    cubit = WalletDetailsCubit(getWalletPolicyUsecase: getWalletPolicy);
  });

  tearDown(() => cubit.close());

  test('loads the wallet policy', () async {
    final policy = _policy();
    when(
      () => getWalletPolicy.execute('wallet-id'),
    ).thenAnswer((_) async => Ok(policy));

    await cubit.loadPolicy('wallet-id');

    expect(cubit.state.policy, same(policy));
    expect(cubit.state.isLoadingPolicy, isFalse);
    expect(cubit.state.failure, isNull);
  });

  test('holds a typed failure so policy loading can be retried', () async {
    when(
      () => getWalletPolicy.execute('wallet-id'),
    ).thenAnswer((_) async => const Err(SettingsWalletPolicyFailure()));

    await cubit.loadPolicy('wallet-id');

    expect(cubit.state.policy, isNull);
    expect(cubit.state.isLoadingPolicy, isFalse);
    expect(cubit.state.failure, isA<SettingsWalletPolicyFailure>());
  });
}

BitcoinWalletPolicy _policy() {
  final spendingPolicy = BitcoinSpendingPolicy(
    root: BitcoinSignaturePolicyNode(
      id: 'key',
      key: BitcoinPolicyKey(
        kind: BitcoinPolicyKeyKind.fingerprint,
        value: '12345678',
      ),
    ),
    requiresPath: false,
  );
  return BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );
}
