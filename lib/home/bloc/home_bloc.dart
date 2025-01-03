import 'dart:async';

import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required AppWalletsRepository appWalletsRepository,
    required NetworkRepository networkRepository,
  })  : _appWalletsRepository = appWalletsRepository,
        _networkRepository = networkRepository,
        super(const HomeState()) {
    on<LoadWalletsFromStorage>(_onLoadWalletsFromStorage);
    on<ClearWallets>(_onClearWallets);
    on<UpdateErrDeepLink>(_onUpdateErrDeepLink);
    on<UpdatedNotifier>(_onUpdatedNotifier);
    on<LoadWalletsForNetwork>(_onLoadWalletsForNetwork);
    on<WalletUpdated>(_onWalletUpdated);
    // on<WalletsSubscribe>(
    //   (event, emit) async {
    //     print('wallets updated');
    //     await emit.forEach(
    //       _appWalletsRepository.wallets,
    //       onData: (List<WalletServiceData> ws) {
    //         add(UpdatedNotifier());
    //         return state.copyWith(wallets: ws.map((_) => _.wallet).toList());
    //       },
    //     );
    //   },
    // );

    // add(LoadWalletsFromStorage());
    // add(WalletsSubscribe());
  }

  final AppWalletsRepository _appWalletsRepository;
  final NetworkRepository _networkRepository;

  Future<void> _onLoadWalletsFromStorage(
    LoadWalletsFromStorage event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(loadingWallets: true));
    await _appWalletsRepository.getWalletsFromStorage();
    final wallets = _appWalletsRepository.allWallets;
    emit(state.copyWith(wallets: wallets));
    await _appWalletsRepository
        .loadAllInNetwork(_networkRepository.getBBNetwork);
    _appWalletsRepository.syncAllInNetwork(_networkRepository.getBBNetwork);
    emit(state.copyWith(loadingWallets: false));
  }

  void _onClearWallets(
    ClearWallets event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(wallets: []));
  }

  Future<void> _onUpdateErrDeepLink(
    UpdateErrDeepLink event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(errDeepLinking: event.err));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(errDeepLinking: ''));
  }

  Future<void> _onUpdatedNotifier(
    UpdatedNotifier event,
    Emitter<HomeState> emit,
  ) async {
    if (event.fromStart) {
      await Future.delayed(const Duration(seconds: 1));
    }
    emit(state.copyWith(updated: true));
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(updated: false));
  }

  void _onLoadWalletsForNetwork(
    LoadWalletsForNetwork event,
    Emitter<HomeState> emit,
  ) {
    final wallets =
        _appWalletsRepository.walletServiceFromNetwork(event.network);
    if (wallets.isEmpty) return;
    for (final w in wallets) {
      w.loadWallet();
    }
  }

  void _onWalletUpdated(
    WalletUpdated event,
    Emitter<HomeState> emit,
  ) {
    final wallet = event.wallet;
    final wallets = state.wallets.toList();
    final idx = wallets.indexWhere((w) => w.id == wallet.id);
    if (idx == -1) return;
    wallets[idx] = wallet;
    emit(state.copyWith(wallets: wallets));
  }
}
