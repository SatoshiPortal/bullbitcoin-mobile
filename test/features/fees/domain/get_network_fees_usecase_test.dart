import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Fees extends Mock implements FeesRepository {}

class _Settings extends Mock implements SettingsRepository {}

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
    when(
      () => fees.getNetworkFees(network: Network.bitcoinRegtest),
    ).thenAnswer((_) async => options);
    final usecase = GetNetworkFeesUsecase(
      feesRepository: fees,
      settingsRepository: settings,
    );
    expect(
      await usecase.execute(isLiquid: false, network: Network.bitcoinRegtest),
      options,
    );
    verifyZeroInteractions(settings);
  });
  test('mismatched asset refuses before settings or backend IO', () async {
    final fees = _Fees();
    final settings = _Settings();
    final usecase = GetNetworkFeesUsecase(
      feesRepository: fees,
      settingsRepository: settings,
    );
    await expectLater(
      usecase.execute(isLiquid: true, network: Network.bitcoinRegtest),
      throwsA(isA<GetNetworkFeesException>()),
    );
    verifyZeroInteractions(settings);
    verifyZeroInteractions(fees);
  });
}
