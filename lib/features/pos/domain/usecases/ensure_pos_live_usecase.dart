import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_liveness.dart';
import 'package:bb_mobile/features/pos/domain/usecases/find_pos_usecase.dart';

/// DG-3 recovery heal for the Point of Sale (§3.12). READ-ONLY: it looks the
/// registration up (shared LA registration), GETs the pos row (kind-scoped), and
/// classifies. It NEVER issues a PUT (a save would clear `archived_at` - a
/// resurrect/clobber hazard) and NEVER re-registers. The recovery cubit is the
/// sole backup publisher, so this path publishes nothing (T-NOCLOBBER).
///
/// - pos present & not archived -> [live] (silent);
/// - pos archived               -> [archivedByUser] (respect the archive);
/// - registration live, pos absent (or no nym) -> [needsReactivation]
///   (one-tap recreate - label/currency are unknowable client-side);
/// - network/timeout/server      -> [unreachable] (liveness UNKNOWN; loud).
class EnsurePosLiveUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final LightningAddressFacade _lightningAddress;
  final FindPosUsecase _findPos;

  const EnsurePosLiveUsecase({
    required this._lightningAddress,
    required this._findPos,
  });

  Future<PosHealOutcome> execute() async {
    final String nym;
    try {
      final status = await _lightningAddress.lookupWalletOwnedRegistration();
      nym = status.nym;
    } on LightningAddressException catch (e) {
      if (e.code == _nymNotFoundCode) {
        // No registration for this seed - the pos cannot exist; route to
        // re-activation rather than reporting a fake-live terminal.
        return const PosHealOutcome(liveness: PosLiveness.needsReactivation);
      }
      return const PosHealOutcome(liveness: PosLiveness.unreachable);
    } catch (_) {
      return const PosHealOutcome(liveness: PosLiveness.unreachable);
    }

    try {
      final pos = await _findPos.execute(nym: nym);
      if (pos == null) {
        return const PosHealOutcome(liveness: PosLiveness.needsReactivation);
      }
      return PosHealOutcome(
        liveness: pos.isArchived
            ? PosLiveness.archivedByUser
            : PosLiveness.live,
      );
    } on PosException {
      // Liveness UNKNOWN - never fake-live on a failure.
      return const PosHealOutcome(liveness: PosLiveness.unreachable);
    } catch (_) {
      return const PosHealOutcome(liveness: PosLiveness.unreachable);
    }
  }
}
