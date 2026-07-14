import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';

/// Unsigned public GET of the Point of Sale row (kind pinned to pos). The
/// shared Bullnym client validates and returns the canonical public URL.
class GetPosUsecase {
  final BullnymFacade _bullnym;

  const GetPosUsecase(this._bullnym);

  Future<PosTerminal> execute({required String nym}) async {
    try {
      final result = await _bullnym.getDonationPage(
        nym: nym,
        kind: bullnymDonationPageKindPos,
      );
      return switch (result) {
        Ok(:final value) => switch (PosTerminal.fromBullnym(value)) {
          final terminal when terminal.nym == nym => terminal,
          _ => throw const PosException.invalidServerResponse(),
        },
        Err(:final failure) => throw PosException.fromBullnym(failure),
      };
    } on PosException {
      rethrow;
    } catch (_) {
      throw const PosException.unexpected();
    }
  }
}
