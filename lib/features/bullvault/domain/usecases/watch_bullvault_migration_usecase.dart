import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';

class WatchBullVaultMigrationUsecase {
  final SendFacade _sendFacade;

  const WatchBullVaultMigrationUsecase(this._sendFacade);

  Stream<Result<String?, BullVaultFailure>> execute({
    required String previousWalletId,
    required String migrationAddress,
  }) => _sendFacade.watchPending(previousWalletId).map((result) {
    switch (result) {
      case Err(:final failure):
        return Err(BullVaultRenewalFailure(failure.runtimeType.toString()));
      case Ok(:final value):
        final migrations =
            value.transactions
                .where(
                  (transaction) =>
                      transaction.recipients.length == 1 &&
                      transaction.recipients.single.recipient ==
                          migrationAddress,
                )
                .toList()
              ..sort(
                (first, second) => second.updatedAt.compareTo(first.updatedAt),
              );
        if (migrations.isEmpty) return const Ok(null);
        return Ok(migrations.first.id);
    }
  });
}
