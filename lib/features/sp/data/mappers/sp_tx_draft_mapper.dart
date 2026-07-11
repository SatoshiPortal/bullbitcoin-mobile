import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_recipient_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps a bwk FFI `TxSimulation` to the domain [SpTxDraft].
///
/// The simulation itself never leaves `data/`: the repository pins it under
/// [id] and the draft carries only that handle. The typed input/output/fee
/// fields are display copies read off the same simulation.
abstract final class SpTxDraftMapper {
  static SpTxDraft toDomain(bwk.TxSimulation simulation, String id) =>
      SpTxDraft(
        id: id,
        inputs: simulation.inputs.map(SpCoinMapper.toDomain).toList(),
        outputs: simulation.outputs.map(SpRecipientMapper.toDomain).toList(),
        feeSat: simulation.feeSat,
        changeSat: simulation.changeSat,
      );
}
