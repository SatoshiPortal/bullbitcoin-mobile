import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_display_data_port.dart';
import '../ark_failure.dart';

final class ReadArkDisplayDataUsecase {
  final ArkDisplayDataPort _source;

  const ReadArkDisplayDataUsecase(this._source);

  Stream<void> changes(ArkAccountId account) => _source.changes(account);

  Future<Result<ArkDisplayData, ArkFailure>> execute(ArkAccountId account) =>
      _source.read(account);
}
