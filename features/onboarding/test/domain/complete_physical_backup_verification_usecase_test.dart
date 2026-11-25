import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  final fingerprint = Fingerprint('73c5da0a');
  final other = Fingerprint('00000000');

  WalletRegistration wallet(
    String id,
    Network network, {
    WalletSigner signer = WalletSigner.local,
    Fingerprint? secret,
  }) => walletRegistrationForTesting(
    id: id,
    network: network,
    isDefault: true,
    signer: signer,
    masterFingerprint: secret ?? fingerprint,
    secretFingerprint: secret ?? fingerprint,
  );

  // Every refused pair is rejected before any backup record is touched.
  final usecase = CompletePhysicalBackupVerificationUsecase(
    records: (_) => fail('A refused pair must not reach the backup records'),
  );

  final refused = <String, List<WalletRegistration>>{
    'no Bitcoin default': [wallet('liquid', LiquidNetwork.mainnet)],
    'two Bitcoin defaults': [
      wallet('a', BitcoinNetwork.mainnet),
      wallet('b', BitcoinNetwork.mainnet),
    ],
    'a watch-only Bitcoin default': [
      wallet('btc', BitcoinNetwork.mainnet, signer: WalletSigner.none),
    ],
    'a pair from two secrets': [
      wallet('btc', BitcoinNetwork.mainnet),
      wallet('liquid', LiquidNetwork.mainnet, secret: other),
    ],
    'a pair across environments': [
      wallet('btc', BitcoinNetwork.mainnet),
      wallet('liquid', LiquidNetwork.testnet),
    ],
  };

  for (final MapEntry(key: name, value: wallets) in refused.entries) {
    test('$name is a backup-verification failure', () async {
      final result = await usecase.execute(wallets);

      expect(
        result,
        isA<Err<void, OnboardingFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<OnboardingBackupVerificationFailure>(),
        ),
      );
    });
  }
}
