import 'package:bb_mobile/features/sp/domain/entities/sp_header_checkpoint.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps the domain [SpHeaderCheckpoint] into the bwk FFI `SpHeaderCheckpoint`.
abstract final class SpHeaderCheckpointMapper {
  static bwk.SpHeaderCheckpoint toFfi(SpHeaderCheckpoint checkpoint) =>
      bwk.SpHeaderCheckpoint(height: checkpoint.height, hash: checkpoint.hash);
}
