import 'package:silent/src/domain/entities/sp_header_checkpoint.dart';
import 'package:rust_bindings/bwk.dart' as bwk;

/// Maps the domain [SpHeaderCheckpoint] into the bwk FFI `SpHeaderCheckpoint`.
abstract final class SpHeaderCheckpointMapper {
  static bwk.SpHeaderCheckpoint toFfi(SpHeaderCheckpoint checkpoint) =>
      bwk.SpHeaderCheckpoint(height: checkpoint.height, hash: checkpoint.hash);
}
