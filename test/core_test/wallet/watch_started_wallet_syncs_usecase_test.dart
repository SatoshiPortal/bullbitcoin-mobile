import 'dart:async';

import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  test('delivers raw start IDs without loading wallets', () async {
    final repository = _MockWalletRepository();
    final starts = StreamController<String>.broadcast();
    addTearDown(starts.close);
    when(
      () => repository.walletSyncStartedIdsStream,
    ).thenAnswer((_) => starts.stream);
    final usecase = WatchStartedWalletSyncsUsecase(
      walletRepository: repository,
    );

    final observed = usecase.execute(walletId: 'wallet-1').first;
    starts.add('wallet-1');

    expect(await observed, 'wallet-1');
    verify(() => repository.walletSyncStartedIdsStream).called(1);
    verifyNever(() => repository.getWallet(any()));
  });
}
