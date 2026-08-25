import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  late _MockBitcoinSigningPort bitcoinSigningPort;
  late GetWalletPolicyUsecase usecase;

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
  final policy = BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );

  setUp(() {
    bitcoinSigningPort = _MockBitcoinSigningPort();
    usecase = GetWalletPolicyUsecase(bitcoinSigningPort: bitcoinSigningPort);
  });

  test('returns the analyzed wallet policy', () async {
    when(
      () => bitcoinSigningPort.getPolicy(walletId: 'wallet-id'),
    ).thenAnswer((_) async => Ok(policy));

    final result = await usecase.execute('wallet-id');

    expect(result, isA<Ok<BitcoinWalletPolicy, SettingsFailure>>());
    expect(
      (result as Ok<BitcoinWalletPolicy, SettingsFailure>).value,
      same(policy),
    );
  });

  test('maps policy analysis failures to a settings failure', () async {
    when(() => bitcoinSigningPort.getPolicy(walletId: 'wallet-id')).thenAnswer(
      (_) async => const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.invalidPsbt),
      ),
    );

    final result = await usecase.execute('wallet-id');

    expect(result, isA<Err<BitcoinWalletPolicy, SettingsFailure>>());
    expect(
      (result as Err<BitcoinWalletPolicy, SettingsFailure>).failure,
      isA<SettingsWalletPolicyFailure>(),
    );
  });
}
