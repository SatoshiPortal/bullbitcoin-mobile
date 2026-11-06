import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

final class NetworkWalletSetupState {
  final NetworkWalletSetup? options;
  final WalletFailure? failure;
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
  final LoadNetworkWalletSetupUsecase _load;
  final CreateNetworkWalletUsecase _create;

  NetworkWalletSetupCubit(this._load, this._create)
    : super(const NetworkWalletSetupState());

  Future<void> load() async {
    if (state.working) return;
    emit(const NetworkWalletSetupState(working: true));
    final result = await _load.execute();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => NetworkWalletSetupState(options: value),
      Err(:final failure) => NetworkWalletSetupState(failure: failure),
    });
  }

  Future<void> create({Fingerprint? reuse}) async {
    final options = state.options;
    if (options == null || state.working) return;
    emit(NetworkWalletSetupState(options: options, working: true));
    final result = await _create.execute(
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
