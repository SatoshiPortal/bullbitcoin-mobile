import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:meta/meta.dart';

/// Creates the Boltz reverse swap whose invoice pays [amountSat] into
/// [wallet]. Returns the engine's failure untranslated so the caller can
/// decide on the exchange fallback before mapping it for display.
class CreateBoltzReceiveSwapUsecase {
  final CreateLightningReceiveSwapUsecase _createLightningReceiveSwapUsecase;

  const CreateBoltzReceiveSwapUsecase(this._createLightningReceiveSwapUsecase);

  @useResult
  Future<Result<LnReceiveSwap, SwapsFailure>> execute({
    required Wallet wallet,
    required int amountSat,
    String? note,
  }) => _createLightningReceiveSwapUsecase.execute(
    walletId: wallet.id,
    amountSat: amountSat,
    toLiquid: wallet.network.isLiquid,
    description: note == null || note.isEmpty ? null : note,
  );
}
