import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import 'create_ark_receive_usecase.dart';

final class RequestArkReceiveUsecase {
  final CreateArkReceiveUsecase _create;
  const RequestArkReceiveUsecase(this._create);
  Future<Result<ArkReceiveDestination, ArkFailure>> execute(
    ArkAccountId account, {
    required bool lightning,
    required String amount,
  }) {
    if (!lightning) {
      return _create.execute(account, ArkReceiveRequest.arkAddress());
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(amount)) {
      return Future.value(const Err(ArkInvalidRequestFailure()));
    }
    final value = BigInt.tryParse(amount);
    if (value == null ||
        value <= BigInt.zero ||
        value > BigInt.from(2100000000000000)) {
      return Future.value(const Err(ArkInvalidRequestFailure()));
    }
    return _create.execute(
      account,
      ArkReceiveRequest.bolt11(amount: Sats(value)),
    );
  }
}
