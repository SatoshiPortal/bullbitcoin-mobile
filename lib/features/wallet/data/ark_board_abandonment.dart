import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart'
    show ArkBoardAbandonmentPort, ArkNeverSignedBoard;
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show SyncFailure;

import 'sqlite_ark_funding_reservations.dart';

/// A configured read-only journal authority. It never enters the source
/// wallet lifecycle/gate, custody or Secrets while Ark owns its own lock.
final class WalletArkBoardAbandonment implements ArkBoardAbandonmentPort {
  final Result<SqliteArkFundingReservations, SyncFailure> _authority;
  const WalletArkBoardAbandonment(this._authority);

  @override
  Future<Result<ArkNeverSignedBoard?, ArkWalletFailure>> readNeverSigned({
    required ArkAccountId account,
    required String operationId,
    required String fundingTxid,
  }) async {
    final authority = switch (_authority) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (authority == null) return const Err(ArkStorageFailure());
    return switch (await authority.readNeverSignedBoard(
      accountIdentity: account.canonical,
      sourceParent: account.parent,
      network: account.network,
      operationId: operationId,
      fundingTxid: fundingTxid,
    )) {
      Ok(value: final ArkNeverSignedBoardFacts facts) => Ok(
        ArkNeverSignedBoard(
          account: account,
          operationId: facts.operationId,
          fundingTxid: facts.fundingTxid,
          address: facts.address,
          keypairIndex: facts.keypairIndex,
          expiryHeight: facts.expiryHeight,
          grossAmount: facts.grossAmount,
          netAmount: facts.netAmount,
        ),
      ),
      Ok() => const Ok(null),
      Err() => const Err(ArkStorageFailure()),
    };
  }
}
