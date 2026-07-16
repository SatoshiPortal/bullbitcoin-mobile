import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/adapters/wallet_freeze_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final class _MockWalletUtxoRepository extends Mock
    implements WalletUtxoRepository {}

void main() {
  late _MockWalletUtxoRepository repository;
  late WalletFreezeAdapter adapter;

  setUpAll(() {
    registerFallbackValue(<FrozenWalletOutpoint>[]);
  });

  setUp(() {
    repository = _MockWalletUtxoRepository();
    adapter = WalletFreezeAdapter(repository);
  });

  test('exports exact attributed freezes through the repository', () async {
    final freeze = FrozenWalletOutpoint(
      walletId: 'wallet-a',
      txId: 'a' * 64,
      vout: 2,
    );
    when(
      () => repository.getAllFrozenWalletOutpoints(),
    ).thenAnswer((_) async => [freeze]);

    final result = await adapter.getAllFrozen();

    expect(result, [(walletId: 'wallet-a', txId: 'a' * 64, vout: 2)]);
  });

  test('imports freezes atomically and normalizes transaction ids', () async {
    when(
      () => repository.restoreFrozenWalletOutpoints(any()),
    ).thenAnswer((_) async {});

    await adapter.freeze([
      (walletId: null, txId: 'A' * 64, vout: 3),
      (walletId: 'wallet-b', txId: 'b' * 64, vout: 4),
    ]);

    final captured =
        verify(
              () => repository.restoreFrozenWalletOutpoints(captureAny()),
            ).captured.single
            as List<FrozenWalletOutpoint>;
    expect(captured, hasLength(2));
    expect(captured.first.walletId, isEmpty);
    expect(captured.first.txId, 'a' * 64);
    expect(captured.last.walletId, 'wallet-b');
  });
}
