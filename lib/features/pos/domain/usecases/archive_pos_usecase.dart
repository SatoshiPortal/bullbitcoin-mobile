import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';

/// Signed soft-archive of the Point of Sale (kind pinned to pos). The server
/// preserves the row (the terminal URL keeps resolving to a deactivation
/// notice); a later provision revives it. A second archive returns
/// DonationPageNotFound, which is mapped to a benign already-archived outcome
/// (null), not an error.
class ArchivePosUsecase {
  final ResolvePosIdentityUsecase _resolveIdentity;
  final BullnymFacade _bullnym;
  final String _terminalBaseUrl;

  const ArchivePosUsecase({
    required this._resolveIdentity,
    required this._bullnym,
    required this._terminalBaseUrl,
  });

  /// Returns the archived terminal, or null when it was already archived /
  /// absent.
  Future<PosTerminal?> execute() async {
    final identity = await _resolveIdentity.execute();
    try {
      final view = await _bullnym.archiveDonationPage(
        signer: identity.signer,
        nym: identity.nym,
        kind: bullnymDonationPageKindPos,
      );
      return PosTerminal.fromBullnym(view, baseUrl: _terminalBaseUrl);
    } on BullnymException catch (e) {
      final mapped = PosException.fromBullnym(e);
      if (mapped.kind == PosErrorKind.notFound) {
        // Double archive / nothing to archive - benign.
        return null;
      }
      throw mapped;
    }
  }
}
