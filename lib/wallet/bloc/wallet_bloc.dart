import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required WalletSync walletSync,
    required InternalWalletsRepository walletsRepository,
    required Wallet wallet,
    required AppWalletsRepository appWalletsRepository,
  })  : _walletSync = walletSync,
        _walletsRepository = walletsRepository,
        _appWalletsRepository = appWalletsRepository,
        super(WalletState(wallet: wallet)) {
    on<SyncWallet>(_syncWallet, transformer: droppable());
    on<RemoveInternalWallet>(_removeInternalWallet);
    on<KillSync>(_killSync);
    on<WalletSubscribe>((event, emit) async {
      await emit.forEach(
        _appWalletsRepository.walletService(event.walletId),
        onData: (WalletService w) {
          print('wallet updated: ${w.wallet.id}');
          return state.copyWith(
            wallet: w.wallet,
            syncing: w.syncing,
          );
        },
      );
    });

    add(WalletSubscribe(wallet.id));
  }

  final InternalWalletsRepository _walletsRepository;
  final WalletSync _walletSync;
  final AppWalletsRepository _appWalletsRepository;

  FutureOr<void> _removeInternalWallet(
    RemoveInternalWallet event,
    Emitter<WalletState> emit,
  ) {
    _walletsRepository.removeBdkWallet(state.wallet.id);
  }

  FutureOr<void> _killSync(KillSync event, Emitter<WalletState> emit) {
    _walletSync.cancelSync();
    emit(state.copyWith(syncing: false));
  }

  Future _syncWallet(SyncWallet event, Emitter<WalletState> emit) async {
    if (state.syncing) return;

    await _appWalletsRepository
        .getWalletServiceById(state.wallet.id)
        ?.syncWallet();
  }

  @override
  Future<void> close() {
    _blocCount -= 1;
    print('blocCount close: $_blocCount');
    return super.close();
  }
}

WalletBloc createWalletBloc(Wallet wallet) {
  _blocCount += 1;
  // final trace = StackTrace.current;
  print('blocCount: $_blocCount');
  return WalletBloc(
    walletSync: locator<WalletSync>(),
    walletsRepository: locator<InternalWalletsRepository>(),
    appWalletsRepository: locator<AppWalletsRepository>(),
    wallet: wallet,
  );
}

int _blocCount = 0;
