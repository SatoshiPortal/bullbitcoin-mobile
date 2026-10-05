import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockGetFundedPredecessor extends Mock
    implements GetBullVaultFundedPredecessorUsecase {}

void main() {
  test('retains alerts only within their current wallet context', () async {
    final lookup = _MockGetFundedPredecessor();
    final mainnet = testBullVaultCreateResult(walletId: 'mainnet').wallet;
    final testnet = testBullVaultCreateResult(
      walletId: 'testnet',
      network: Network.bitcoinTestnet,
    ).wallet;
    when(() => lookup.execute(any())).thenAnswer((_) async => Ok(mainnet.id));
    final cubit = BullVaultHomeAlertCubit(lookup);
    addTearDown(cubit.close);
    await cubit.load([mainnet]);
    expect(cubit.state, mainnet.id);

    when(
      () => lookup.execute(any()),
    ).thenAnswer((_) async => const Err(BullVaultRenewalFailure()));
    await cubit.load([mainnet]);
    expect(cubit.state, mainnet.id);
    await cubit.load([testnet]);
    expect(cubit.state, isNull);
  });

  test('keeps the latest deposit alert when loads overlap', () async {
    final getFundedPredecessor = _MockGetFundedPredecessor();
    final first = Completer<Result<String?, BullVaultFailure>>();
    var calls = 0;
    when(() => getFundedPredecessor.execute(any())).thenAnswer(
      (_) =>
          calls++ == 0 ? first.future : Future.value(const Ok('active-wallet')),
    );
    final cubit = BullVaultHomeAlertCubit(getFundedPredecessor);
    final stale = cubit.load([]);
    await cubit.load([]);
    first.complete(const Ok(null));
    await stale;
    expect(cubit.state, 'active-wallet');
    await cubit.close();
  });
}
