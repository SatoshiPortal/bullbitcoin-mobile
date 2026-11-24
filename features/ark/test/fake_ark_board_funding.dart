import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:primitives/primitives.dart';

/// Test-only scripted authority; never registered by production setup.
final class FakeArkBoardFunding implements ArkBoardFundingPort {
  Result<ArkBoardPreparation, ArkFailure> prepared = const Err(
    ArkServiceUnavailableFailure(),
  );
  Result<ArkBoardPreparation, ArkFailure> observed = const Err(
    ArkServiceUnavailableFailure(),
  );
  Result<ArkOperation, ArkFailure> confirmed = const Err(
    ArkServiceUnavailableFailure(),
  );
  final calls = <String>[];
  final arguments = <Object>[];

  /// When set, prepare and confirm wait for it, to observe the busy screen.
  Completer<void>? gate;

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) async {
    calls.add('prepare');
    arguments.add((config, amount));
    await gate?.future;
    return prepared;
  }

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  ) async {
    calls.add('read');
    arguments.add((account, operationId));
    return observed;
  }

  @override
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) async {
    calls.add('confirm');
    arguments.add((account, operationId, reviewBinding));
    await gate?.future;
    return confirmed;
  }
}
