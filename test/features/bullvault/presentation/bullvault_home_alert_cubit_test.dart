import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockGetDetails extends Mock implements GetBullVaultDetailsUsecase {}

void main() {
  test('reloads late deposits into a previous vault', () async {
    final getDetails = _MockGetDetails();
    final created = testBullVaultCreateResult(
      previousVaultId: 'retired-wallet',
      lineageId: 'lineage',
      generation: 1,
      status: .active,
      network: Network.bitcoinTestnet,
    );
    final wallet = created.wallet;
    var hasLateDeposit = false;
    when(() => getDetails.execute(wallet.id)).thenAnswer(
      (_) async => Ok(
        hasLateDeposit
            ? BullVaultDetails(
                record: created.record,
                timeUntilFirstRecovery: const Duration(days: 365),
                showEarlyRenewalWarning: false,
                migrationAddress: 'bc1qmigration',
                previousVaults: [
                  BullVaultPreviousVault(
                    record: _migratingPrevious(created),
                    wallet: Wallet(
                      origin: 'retired-wallet',
                      network: Network.bitcoinTestnet,
                      signers: const [],
                      scriptType: null,
                      publicDescriptor: 'tr(retired)',
                      balanceSat: BigInt.one,
                      isHidden: true,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
    final cubit = BullVaultHomeAlertCubit(getDetails);

    await cubit.load([wallet]);
    expect(cubit.state, isNull);

    hasLateDeposit = true;
    await cubit.load([wallet]);
    expect(cubit.state, wallet.id);

    verify(() => getDetails.execute(wallet.id)).called(2);
    await cubit.close();
  });

  test('keeps the latest result when loads overlap', () async {
    final getDetails = _MockGetDetails();
    final first = testBullVaultCreateResult(
      walletId: 'first-wallet',
      status: .active,
      network: Network.bitcoinTestnet,
    );
    final second = testBullVaultCreateResult(
      walletId: 'second-wallet',
      previousVaultId: 'retired-wallet',
      lineageId: 'lineage',
      generation: 1,
      status: .active,
      network: Network.bitcoinTestnet,
    );
    final firstResult =
        Completer<Result<BullVaultDetails?, BullVaultFailure>>();
    when(
      () => getDetails.execute(first.wallet.id),
    ).thenAnswer((_) => firstResult.future);
    when(() => getDetails.execute(second.wallet.id)).thenAnswer(
      (_) async => Ok(
        BullVaultDetails(
          record: second.record,
          timeUntilFirstRecovery: const Duration(days: 365),
          showEarlyRenewalWarning: false,
          migrationAddress: 'bc1qmigration',
          previousVaults: [
            BullVaultPreviousVault(
              record: _migratingPrevious(second),
              wallet: Wallet(
                origin: 'retired-wallet',
                network: Network.bitcoinTestnet,
                signers: const [],
                scriptType: null,
                publicDescriptor: 'tr(retired)',
                balanceSat: BigInt.one,
                isHidden: true,
              ),
            ),
          ],
        ),
      ),
    );
    final cubit = BullVaultHomeAlertCubit(getDetails);

    final firstLoad = cubit.load([first.wallet]);
    await cubit.load([second.wallet]);
    firstResult.complete(const Ok(null));
    await firstLoad;

    expect(cubit.state, second.wallet.id);
    await cubit.close();
  });
}

BullVaultRecord _migratingPrevious(BullVaultCreateResult active) =>
    testBullVaultCreateResult(
      walletId: 'retired-wallet',
      lineageId: active.record.lineageId,
      generation: active.record.vaultGeneration - 1,
      status: BullVaultLifecycleStatus.migrating,
      network: active.wallet.network,
    ).record.copyWith(successorWalletId: active.wallet.id);
