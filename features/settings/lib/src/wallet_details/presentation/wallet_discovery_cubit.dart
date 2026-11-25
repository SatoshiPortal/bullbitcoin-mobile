import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Ok, Err;

import '../domain/discover_wallet_usecase.dart';
import '../domain/wallet_details_failure.dart';

sealed class WalletDiscoveryState {
  const WalletDiscoveryState();
}

final class WalletDiscoveryIdle extends WalletDiscoveryState {
  const WalletDiscoveryIdle();
}

final class WalletDiscoveryRunning extends WalletDiscoveryState {
  const WalletDiscoveryRunning();
}

final class WalletDiscoverySucceeded extends WalletDiscoveryState {
  const WalletDiscoverySucceeded();
}

final class WalletDiscoveryFailed extends WalletDiscoveryState {
  final WalletDetailsFailure failure;
  const WalletDiscoveryFailed(this.failure);
}

class WalletDiscoveryCubit extends Cubit<WalletDiscoveryState> {
  final DiscoverWalletUsecase _discover;

  WalletDiscoveryCubit(this._discover) : super(const WalletDiscoveryIdle());

  Future<void> discover(String walletId) async {
    if (state is WalletDiscoveryRunning) return;
    emit(const WalletDiscoveryRunning());
    final result = await _discover.execute(walletId);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const WalletDiscoverySucceeded(),
      Err(:final failure) => WalletDiscoveryFailed(failure),
    });
  }
}
