import 'package:bb_mobile/core/blockchain/domain/bitcoin_chain_tip_port.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/get_bitcoin_chain_tip_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinChainTipPort extends Mock implements BitcoinChainTipPort {}

void main() {
  test('returns the selected network chain tip', () async {
    final repository = _MockBitcoinChainTipPort();
    when(
      () => repository.getChainTip(isTestnet: false),
    ).thenAnswer((_) async => (height: 900_000, medianTimePast: 1_788_000_000));
    final usecase = GetBitcoinChainTipUsecase(repository);

    expect(await usecase.execute(isTestnet: false), (
      height: 900_000,
      medianTimePast: 1_788_000_000,
    ));
    verify(() => repository.getChainTip(isTestnet: false)).called(1);
  });
}
