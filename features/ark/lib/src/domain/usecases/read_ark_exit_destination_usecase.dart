import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_exit_destination_port.dart';
import '../ark_failure.dart';

final class ReadArkExitDestinationUsecase {
  final ArkExitDestinationPort _destination;

  const ReadArkExitDestinationUsecase(this._destination);

  Future<Result<String, ArkFailure>> execute(ArkAccountId account) =>
      _destination.secureBitcoinAddress(account);
}
