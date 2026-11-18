import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_wallet_failure.dart';
import 'entities/ark_sql_exit.dart';

/// Independent per-call guarded snapshots; no retained handles or native wallet.
abstract interface class ArkSqlExitRepository {
  @useResult
  Future<Result<ArkSqlRead<ArkSqlExitState>, ArkWalletFailure>> readExitState({
    required String vtxoId,
  });
  @useResult
  Future<Result<ArkSqlRead<ArkSqlExitChild>, ArkWalletFailure>> readExitChild({
    required String parentTxid,
  });
  @useResult
  Future<Result<ArkSqlRead<ArkSqlVtxoComponents>, ArkWalletFailure>> readVtxo({
    required String vtxoId,
  });
}
