import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';

/// Unsigned public GET of the Point of Sale row (kind pinned to pos). The
/// terminal URL is constructed client-side from [terminalBaseUrl] + the nym; no
/// server-echoed `public_url` is trusted (DG-P5).
class GetPosUsecase {
  final BullnymFacade _bullnym;
  final String _terminalBaseUrl;

  const GetPosUsecase(this._bullnym, {required this._terminalBaseUrl});

  Future<PosTerminal> execute({required String nym}) async {
    try {
      final result = await _bullnym.getDonationPage(
        nym: nym,
        kind: bullnymDonationPageKindPos,
      );
      return switch (result) {
        Ok(:final value) => PosTerminal.fromBullnym(
          value,
          baseUrl: _terminalBaseUrl,
        ),
        Err(:final failure) => throw PosException.fromBullnym(failure),
      };
    } on PosException {
      rethrow;
    } catch (_) {
      throw const PosException.unexpected();
    }
  }
}
