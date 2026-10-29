import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import '../domain/usecases/set_cbf_wifi_only_usecase.dart';
import '../domain/usecases/watch_cbf_network_policy_usecase.dart';
import '../domain/wallet_sync_options_failure.dart';

final class WalletSyncNetworkState {
  final CbfNetworkPolicyState policy;
  final bool saving;
  final WalletSyncOptionsFailure? failure;

  const WalletSyncNetworkState({
    this.policy = const CbfNetworkPolicyState(),
    this.saving = false,
    this.failure,
  });
}

final class WalletSyncNetworkCubit extends Cubit<WalletSyncNetworkState> {
  final SetCbfWifiOnlyUsecase _set;
  final ContinueCbfOnMobileDataUsecase _continue;
  late final StreamSubscription<CbfNetworkPolicyState> _subscription;

  WalletSyncNetworkCubit({
    required WatchCbfNetworkPolicyUsecase watch,
    required this._set,
    required ContinueCbfOnMobileDataUsecase continueOnMobileData,
  }) : _continue = continueOnMobileData,
       super(const WalletSyncNetworkState()) {
    _subscription = watch.execute().listen((policy) {
      if (!isClosed) {
        emit(
          WalletSyncNetworkState(
            policy: policy,
            saving: state.saving,
            failure: state.failure,
          ),
        );
      }
    });
  }

  Future<void> setWifiOnly(bool enabled) async {
    if (state.saving || isClosed) return;
    emit(WalletSyncNetworkState(policy: state.policy, saving: true));
    final result = await _set.execute(enabled);
    if (isClosed) return;
    emit(
      WalletSyncNetworkState(
        policy: state.policy,
        failure: switch (result) {
          Ok() => null,
          Err(:final failure) => failure,
        },
      ),
    );
  }

  void continueOnMobileData() => _continue.execute();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
