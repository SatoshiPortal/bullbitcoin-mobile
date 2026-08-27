import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

void main() {
  late _MockLiquidWalletRepository repo;
  late CheckLiquidConsolidationUsecase usecase;

  const walletId = 'wallet-1';

  setUp(() {
    repo = _MockLiquidWalletRepository();
    usecase = CheckLiquidConsolidationUsecase(liquidWalletRepository: repo);
  });

  group('count', () {
    test('returns the repository\'s L-BTC UTXO count', () async {
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 42);

      final count = await usecase.count(walletId: walletId);

      expect(count, 42);
    });

    test('returns null if the underlying read fails', () async {
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('boom'));

      final count = await usecase.count(walletId: walletId);

      expect(count, isNull);
    });
  });

  group('execute — isRequired against kLiquidConsolidationThreshold', () {
    test('is true once the count exceeds the threshold', () async {
      final total = kLiquidConsolidationThreshold + 1;
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => total);

      final required = await usecase.execute(walletId: walletId);

      expect(required, isTrue);
    });

    test('is false at exactly the threshold (boundary)', () async {
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => kLiquidConsolidationThreshold);

      final required = await usecase.execute(walletId: walletId);

      expect(required, isFalse);
    });

    test('is false for a normal, small wallet well under the threshold — '
        'the no-regression acceptance criterion', () async {
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 5);

      final required = await usecase.execute(walletId: walletId);

      expect(required, isFalse);
    });

    test('is false when the count could not be read', () async {
      when(
        () => repo.getLbtcUtxoCount(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('boom'));

      final required = await usecase.execute(walletId: walletId);

      expect(required, isFalse);
    });
  });
}
