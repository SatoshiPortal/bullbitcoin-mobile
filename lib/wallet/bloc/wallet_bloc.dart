import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/home/home_page.dart';
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
    on<WalletSubscribe>(
      (event, emit) async {
        final walletService = _appWalletsRepository.getWalletServiceById(
          event.walletId,
        );
        if (walletService == null) {
          _walletServiceFromTempWallets = createWalletService(wallet: wallet)
            ..loadWallet(syncAfter: true);

          await emit.forEach(
            _walletServiceFromTempWallets!.dataStream,
            onData: (WalletServiceData data) {
              return state.copyWith(
                wallet: data.wallet,
                syncing: data.syncing,
              );
            },
          );
          return;
        }

        await emit.forEach(
          walletService.dataStream,
          onData: (WalletServiceData data) {
            return state.copyWith(
              wallet: data.wallet,
              syncing: data.syncing,
            );
          },
          onError: (error, stackTrace) {
            return state.copyWith(errSyncing: error.toString());
          },
        );
      },
    );

    add(WalletSubscribe(wallet.id));
  }

  final InternalWalletsRepository _walletsRepository;
  final WalletSync _walletSync;
  final AppWalletsRepository _appWalletsRepository;
  WalletService? _walletServiceFromTempWallets;

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
}

WalletBloc createOrRetreiveWalletBloc(String walletId, {Wallet? wallet}) {
  final existIdx = locator<AppWalletBlocs>()
      .state
      .indexWhere((_) => _.state.wallet.id == walletId);

  if (existIdx != -1) return locator<AppWalletBlocs>().state[existIdx];

  final w = wallet ?? locator<AppWalletsRepository>().getWalletById(walletId);
  return WalletBloc(
    walletSync: locator<WalletSync>(),
    walletsRepository: locator<InternalWalletsRepository>(),
    appWalletsRepository: locator<AppWalletsRepository>(),
    wallet: w!,
  );
}
