import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_board_source_port.dart';
import '../ark_display_data_port.dart';
import '../ark_failure.dart';

final class RefreshArkBoardSourceUsecase {
  final ArkBoardSourcePort _source;
  const RefreshArkBoardSourceUsecase(this._source);

  Future<Result<ArkDisplayData, ArkFailure>> execute(ArkAccountId account) =>
      _source.refresh(account);

  bool accepts(ArkDisplayData observation) => _source.accepts(observation);
}
