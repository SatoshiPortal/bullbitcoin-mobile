import 'package:primitives/primitives.dart';
import 'package:silent/src/data/mappers/sp_coin_mapper.dart';
import 'package:silent/src/data/mappers/sp_recipient_mapper.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:rust_bindings/bwk.dart' as bwk;

/// Maps a bwk FFI `TxSimulation` to the domain [SilentTxDraft].
///
/// The simulation itself never leaves `data/`: the repository pins it under
/// [id] and the draft carries only that handle. The typed input/output/fee
/// fields are display copies read off the same simulation.
abstract final class SpTxDraftMapper {
  static SilentTxDraft toDomain(bwk.TxSimulation simulation, String id) =>
      SilentTxDraft(
        id: id,
        inputs: simulation.inputs.map(SpCoinMapper.toDomain).toList(),
        outputs: simulation.outputs.map(SpRecipientMapper.toDomain).toList(),
        feeSat: Sats(simulation.feeSat),
        changeSat: Sats(simulation.changeSat),
      );
}
