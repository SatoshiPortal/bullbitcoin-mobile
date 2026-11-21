import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:bb_mobile/features/fees/public/app_fee_estimates.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Fees extends Mock implements Fees {}

class _Settings extends Mock implements Preferences {}

void main() {
  test('captured regtest bypasses the current active environment', () async {
    final fees = _Fees();
    final settings = _Settings();
    const options = FeeOptions(
      fastest: RelativeFee(250),
      economic: RelativeFee(250),
      slow: RelativeFee(250),
      minRelay: RelativeFee(25),
    );
    when(() => fees.estimate(BitcoinNetwork.regtest))
        .thenAnswer((_) async => const Ok(options));
    final usecase = AppFeeEstimates(fees: fees, settingsRepository: settings);
    expect(
      await usecase.execute(isLiquid: false, network: Network.bitcoinRegtest),
      options,
    );
    verifyZeroInteractions(settings);
  });
  test('mismatched asset refuses before settings or backend IO', () async {
    final fees = _Fees();
    final settings = _Settings();
    final usecase = AppFeeEstimates(fees: fees, settingsRepository: settings);
    await expectLater(
      usecase.execute(isLiquid: true, network: Network.bitcoinRegtest),
      throwsA(isA<AppFeeEstimateException>()),
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(fees);
  });
}
