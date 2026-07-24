import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';

/// Resolves immediately if [walletId] has no active compact block filter
/// (CBF) sync; otherwise waits for the running attempt to settle on its
/// own before resolving. Never requests cancellation — see
/// [CbfSyncActivityPort] for the product rule this enforces.
class AwaitCbfSyncInactiveUsecase {
  final CbfSyncActivityPort _cbfSyncActivity;

  AwaitCbfSyncInactiveUsecase({
    required CbfSyncActivityPort cbfSyncActivityPort,
  }) : _cbfSyncActivity = cbfSyncActivityPort;

  Future<void> execute({required String walletId}) =>
      _cbfSyncActivity.waitUntilInactive(walletId: walletId);
}
