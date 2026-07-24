import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';

/// Whether [walletId] currently has a running compact block filter (CBF)
/// sync. A synchronous, point-in-time check — see
/// [AwaitCbfSyncInactiveUsecase] to defer until an active session settles.
class CheckCbfSyncActiveUsecase {
  final CbfSyncActivityPort _cbfSyncActivity;

  CheckCbfSyncActiveUsecase({required CbfSyncActivityPort cbfSyncActivityPort})
    : _cbfSyncActivity = cbfSyncActivityPort;

  bool execute({required String walletId}) =>
      _cbfSyncActivity.isActive(walletId: walletId);
}
