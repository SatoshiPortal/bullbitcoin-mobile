import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_preparation.dart';
import 'ark_failure.dart';

export 'ark_board_preparation.dart';
export 'ark_failure.dart';

/// Required host funding authority, constructed by wallet-owned setup.
/// Preparation never signs. A reviewable result must come from durable facts;
/// uncertain work retains its operation and is not permission to prepare again.
abstract interface class ArkBoardFundingPort {
  @useResult
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  );

  @useResult
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  );

  /// Resolve the original journal binding and recheck current authority before
  /// any seal/sign/broadcast. A caller's display metadata grants nothing.
  @useResult
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  );
}
