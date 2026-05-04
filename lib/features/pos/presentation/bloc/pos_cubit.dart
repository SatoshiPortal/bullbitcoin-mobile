import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/application/usecases/init_pos_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/pair_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/publish_pos_profile_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/revoke_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_profile_settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosState {
  const PosState({
    this.isLoading = false,
    this.wallets = const [],
    this.identity,
    this.terminals = const [],
    this.cashierUrl,
    this.error,
  });

  final bool isLoading;
  final List<Wallet> wallets;
  final PosIdentity? identity;
  final List<AuthorizedTerminal> terminals;
  final String? cashierUrl;
  final String? error;

  PosState copyWith({
    bool? isLoading,
    List<Wallet>? wallets,
    PosIdentity? identity,
    bool clearIdentity = false,
    List<AuthorizedTerminal>? terminals,
    String? cashierUrl,
    bool clearCashierUrl = false,
    String? error,
    bool clearError = false,
  }) {
    return PosState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      identity: clearIdentity ? null : identity ?? this.identity,
      terminals: terminals ?? this.terminals,
      cashierUrl: clearCashierUrl ? null : cashierUrl ?? this.cashierUrl,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PosCubit extends Cubit<PosState> {
  PosCubit({
    required PosStoragePort storage,
    required GetWalletsUsecase getWalletsUsecase,
    required InitPosUsecase initPosUsecase,
    required PublishPosProfileUsecase publishPosProfileUsecase,
    required PairTerminalUsecase pairTerminalUsecase,
    required RevokeTerminalUsecase revokeTerminalUsecase,
  }) : _storage = storage,
       _getWalletsUsecase = getWalletsUsecase,
       _initPosUsecase = initPosUsecase,
       _publishPosProfileUsecase = publishPosProfileUsecase,
       _pairTerminalUsecase = pairTerminalUsecase,
       _revokeTerminalUsecase = revokeTerminalUsecase,
       super(const PosState());

  final PosStoragePort _storage;
  final GetWalletsUsecase _getWalletsUsecase;
  final InitPosUsecase _initPosUsecase;
  final PublishPosProfileUsecase _publishPosProfileUsecase;
  final PairTerminalUsecase _pairTerminalUsecase;
  final RevokeTerminalUsecase _revokeTerminalUsecase;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final identity = await _storage.getLatestProfile();
      final wallets = await _loadLiquidWallets();
      final terminals = identity == null
          ? <AuthorizedTerminal>[]
          : await _storage.listAuthorizedTerminals(identity.ref);
      emit(
        state.copyWith(
          isLoading: false,
          wallets: wallets,
          identity: identity,
          clearIdentity: identity == null,
          terminals: terminals,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  Future<void> setup({
    required Wallet wallet,
    required String name,
    required String currency,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final identity = await _initPosUsecase.execute(
        liquidWallet: wallet,
        settings: PosProfileSettings(name: name, currency: currency),
      );
      final published = await _publishPosProfileUsecase.execute(identity);
      final terminals = await _storage.listAuthorizedTerminals(identity.ref);
      emit(
        state.copyWith(
          isLoading: false,
          identity: identity,
          terminals: terminals,
          cashierUrl: published.cashierUrl,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  Future<void> publish() async {
    final identity = state.identity;
    if (identity == null) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final published = await _publishPosProfileUsecase.execute(identity);
      emit(state.copyWith(isLoading: false, cashierUrl: published.cashierUrl));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  Future<void> pair(String pairingCode) async {
    final identity = state.identity;
    if (identity == null) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _pairTerminalUsecase.execute(
        ref: identity.ref,
        pairingCode: pairingCode.trim().toUpperCase(),
      );
      final terminals = await _storage.listAuthorizedTerminals(identity.ref);
      emit(state.copyWith(isLoading: false, terminals: terminals));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  Future<void> revoke(String terminalPubkey) async {
    final identity = state.identity;
    if (identity == null) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _revokeTerminalUsecase.execute(
        ref: identity.ref,
        terminalPubkey: terminalPubkey,
      );
      final terminals = await _storage.listAuthorizedTerminals(identity.ref);
      emit(state.copyWith(isLoading: false, terminals: terminals));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }

  Future<List<Wallet>> _loadLiquidWallets() async {
    try {
      return await _getWalletsUsecase.execute(onlyLiquid: true);
    } catch (_) {
      return const [];
    }
  }
}
