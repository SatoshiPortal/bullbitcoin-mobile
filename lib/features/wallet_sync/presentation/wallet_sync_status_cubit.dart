import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/usecases/watch_wallet_sync_status_usecase.dart';
import '../domain/usecases/start_wallet_sync_usecase.dart';
import '../domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import '../domain/wallet_sync_status.dart';

class WalletSyncStatusCubit extends Cubit<WalletSyncStatus?> {
  final String walletId;
  final StartWalletSyncUsecase _start;
  final WatchWalletSyncStatusUsecase _watch;
  final ContinueCbfOnMobileDataUsecase? _continueOnMobileData;
  late StreamSubscription<WalletSyncStatus> _subscription;
  bool _refreshing = false;
  bool _closing = false;

  WalletSyncStatusCubit({
    required this.walletId,
    required this._watch,
    required this._start,
    this._continueOnMobileData,
  }) : super(null) {
    _subscription = _watch.execute(walletId).listen((status) {
      if (!isClosed) emit(status);
    });
  }
  Future<void> refresh() async {
    if (isClosed || _closing || _refreshing) return;
    _refreshing = true;
    try {
      await _subscription.cancel();
      if (isClosed || _closing) return;
      _subscription = _watch.execute(walletId).listen((status) {
        if (!isClosed && !_closing) emit(status);
      });
    } finally {
      _refreshing = false;
    }
  }

  void retry() => _start.execute(walletId);
  void continueOnMobileData() => _continueOnMobileData?.execute();
  @override
  Future<void> close() async {
    _closing = true;
    await _subscription.cancel();
    return super.close();
  }
}
