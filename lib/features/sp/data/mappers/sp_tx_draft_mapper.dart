import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_recipient_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Wraps a bwk FFI `TxSimulation` in the opaque domain [SpTxDraft].
///
/// The simulation is stored verbatim as the draft's `handle`; the typed
/// input/output/fee fields are display copies. [rawSimulation] extracts the
/// exact same object for finalize, so the pin invariant holds byte-for-byte.
abstract final class SpTxDraftMapper {
  static SpTxDraft toDomain(bwk.TxSimulation simulation) => SpTxDraft(
    handle: simulation,
    inputs: simulation.inputs.map(SpCoinMapper.toDomain).toList(),
    outputs: simulation.outputs.map(SpRecipientMapper.toDomain).toList(),
    feeSat: simulation.feeSat,
    changeSat: simulation.changeSat,
  );

  static bwk.TxSimulation rawSimulation(SpTxDraft draft) =>
      draft.handle as bwk.TxSimulation;
}
