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

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) async {
    calls.add('prepare');
    arguments.add((config, amount));
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
    return confirmed;
  }
}
