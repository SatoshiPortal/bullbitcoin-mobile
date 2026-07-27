import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

void main() {
  late _MockLiquidWalletRepository repo;
  late _MockWalletUtxoRepository utxoRepo;
  late CheckLiquidConsolidationUsecase usecase;

  const walletId = 'wallet-1';

  setUp(() {
    repo = _MockLiquidWalletRepository();
    utxoRepo = _MockWalletUtxoRepository();
    usecase = CheckLiquidConsolidationUsecase(
      liquidWalletRepository: repo,
      walletUtxoRepository: utxoRepo,
    );
  });

  group('execute — utxoCount', () {
    test('excludes frozen outpoints from the confirmed count', () async {
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => [
          (txId: 'a', vout: 0),
          (txId: 'b', vout: 0),
          (txId: 'c', vout: 0),
        ],
      );
      when(
        () => utxoRepo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'b', vout: 0)]);

      final status = await usecase.execute(walletId: walletId);

      expect(status.utxoCount, 2);
    });

    test('is null if the underlying call fails', () async {
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('boom'));

      final status = await usecase.execute(walletId: walletId);

      expect(status.utxoCount, isNull);
      expect(status.isRequired, isFalse);
    });
  });

  group('execute — isRequired', () {
    test('is true once the unfrozen count exceeds the threshold', () async {
      final total = kLiquidConsolidationThreshold + 1;
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => List.generate(total, (i) => (txId: 'tx$i', vout: 0)),
      );
      when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer((_) async => []);

      final status = await usecase.execute(walletId: walletId);

      expect(status.isRequired, isTrue);
    });

    test('is false when enough of the confirmed UTXOs are frozen to drop at '
        'or below the threshold', () async {
      final total = kLiquidConsolidationThreshold + 1;
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => List.generate(total, (i) => (txId: 'tx$i', vout: 0)),
      );
      when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer(
        (_) async => List.generate(total - 1, (i) => (txId: 'tx$i', vout: 0)),
      );

      final status = await usecase.execute(walletId: walletId);

      // total - (total-1) frozen = 1 unfrozen, not > threshold.
      expect(status.isRequired, isFalse);
    });
  });
}
