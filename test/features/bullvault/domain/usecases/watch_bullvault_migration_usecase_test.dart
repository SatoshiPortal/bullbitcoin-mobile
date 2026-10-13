import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_migration_usecase.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendFacade extends Mock implements SendFacade {}

void main() {
  test('resumes the newest transaction targeting the current vault', () async {
    final facade = _MockSendFacade();
    final migration = _transaction(
      id: 'migration',
      recipient: 'tb1qcurrent',
      updatedAt: DateTime.utc(2028, 1, 2),
    );
    when(() => facade.watchPending('wallet-0')).thenAnswer(
      (_) => Stream.value(
        Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: [
              _transaction(
                id: 'older-migration',
                recipient: 'tb1qcurrent',
                updatedAt: DateTime.utc(2028, 1, 1),
              ),
              _transaction(
                id: 'other',
                recipient: 'tb1qother',
                updatedAt: DateTime.utc(2028, 1, 3),
              ),
              migration,
            ],
          ),
        ),
      ),
    );

    final result = await WatchBullVaultMigrationUsecase(facade)
        .execute(previousWalletId: 'wallet-0', migrationAddress: 'tb1qcurrent')
        .first;

    expect(result, isA<Ok<String?, BullVaultFailure>>());
    expect((result as Ok<String?, BullVaultFailure>).value, migration.id);
  });
}

PendingBitcoinTransaction _transaction({
  required String id,
  required String recipient,
  required DateTime updatedAt,
}) => PendingBitcoinTransaction(
  id: id,
  walletId: 'wallet-0',
  stage: PendingBitcoinTransactionStage.draft,
  recipient: recipient,
  amount: '',
  amountCurrencyCode: 'sats',
  sendMax: true,
  feeSelection: FeeSelection.fastest,
  replaceByFee: true,
  createdAt: DateTime.utc(2028),
  updatedAt: updatedAt,
);
