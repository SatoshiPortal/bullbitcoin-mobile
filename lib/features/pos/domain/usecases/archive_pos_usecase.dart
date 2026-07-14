import 'package:bb_mobile/core/utils/result.dart';
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

  const ArchivePosUsecase({
    required this._resolveIdentity,
    required this._bullnym,
  });

  /// Returns the archived terminal, or null when it was already archived /
  /// absent.
  Future<PosTerminal?> execute() async {
    final identity = await _resolveIdentity.execute();
    final result = await _bullnym.archiveDonationPage(
      signer: identity.signer,
      nym: identity.nym,
      kind: bullnymDonationPageKindPos,
    );
    switch (result) {
      case Ok(:final value):
        final terminal = PosTerminal.fromBullnym(value);
        if (terminal.nym != identity.nym) {
          throw const PosException.invalidServerResponse();
        }
        return terminal;
      case Err(:final failure):
        final mapped = PosException.fromBullnym(failure);
        if (mapped.kind == PosErrorKind.notFound) {
          // Double archive / nothing to archive - benign.
          return null;
        }
        throw mapped;
    }
  }
}
