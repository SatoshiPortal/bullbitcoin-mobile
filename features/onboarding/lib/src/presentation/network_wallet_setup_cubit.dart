import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';

final class NetworkWalletSetupState {
  final NetworkWalletSetup? options;
  final NetworkWalletSetupFailure? failure;
  final bool working;
  final bool completed;

  const NetworkWalletSetupState({
    this.options,
    this.failure,
    this.working = false,
    this.completed = false,
  });
}

final class NetworkWalletSetupCubit extends Cubit<NetworkWalletSetupState> {
  final NetworkWalletProvisioning _provisioning;
  StreamSubscription<bool>? _refreshSubscription;

  NetworkWalletSetupCubit(this._provisioning)
    : super(const NetworkWalletSetupState());

  void reloadAfterRefresh(
    Stream<bool> refreshing, {
    required bool initiallyRefreshing,
  }) {
    var wasRefreshing = initiallyRefreshing;
    _refreshSubscription = refreshing.listen((isRefreshing) {
      final finished = wasRefreshing && !isRefreshing;
      wasRefreshing = isRefreshing;
      if (finished) unawaited(load());
    });
  }

  @override
  Future<void> close() async {
    await _refreshSubscription?.cancel();
    return super.close();
  }

  Future<void> load() async {
    if (state.working) return;
    emit(const NetworkWalletSetupState(working: true));
    final result = await _provisioning.load();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => NetworkWalletSetupState(options: value),
      Err(:final failure) => NetworkWalletSetupState(failure: failure),
    });
  }

  Future<void> create({Fingerprint? reuse}) async {
    final options = state.options;
    if (options == null || state.working || state.completed) return;
    emit(NetworkWalletSetupState(options: options, working: true));
    final result = await _provisioning.create(
      network: options.network,
      reuse: reuse,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => NetworkWalletSetupState(options: options, completed: true),
      Err(:final failure) => NetworkWalletSetupState(
        options: options,
        failure: failure,
      ),
    });
  }
}
