import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import 'ark_display_data_port.dart';
import 'ark_failure.dart';

/// Explicit ordinary Board-form scan; passive display reads never scan.
abstract interface class ArkBoardSourcePort implements ArkDisplayDataPort {
  Future<Result<ArkDisplayData, ArkFailure>> refresh(ArkAccountId account);

  /// Synchronous invalidation guard, not permission to spend funds.
  bool accepts(ArkDisplayData observation);
}
