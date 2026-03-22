import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/register_dlc_wallet_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_wallet_auth_state.dart';
part 'dlc_wallet_auth_cubit.freezed.dart';

const _kDlcOptedOutKey = 'dlc_opted_out';
const _kDlcWalletTokenKey = 'dlc_wallet_token';
const _kDlcWalletIdKey = 'dlc_wallet_id';
const _kDlcFundingPubkeyKey = 'dlc_funding_pubkey';

/// Manages the DLC wallet authentication lifecycle:
///   - Persisting the user's opt-in / opt-out decision.
///   - Triggering wallet registration on first opt-in.
///   - Restoring a previously stored [walletToken] on app start.
class DlcWalletAuthCubit extends Cubit<DlcWalletAuthState> {
  DlcWalletAuthCubit({
    required RegisterDlcWalletUsecase registerDlcWalletUsecase,
    required DlcWalletTokenStore tokenStore,
    required KeyValueStorageDatasource<String> secureStorage,
  })  : _registerDlcWalletUsecase = registerDlcWalletUsecase,
        _tokenStore = tokenStore,
        _secureStorage = secureStorage,
        super(const DlcWalletAuthState());

  final RegisterDlcWalletUsecase _registerDlcWalletUsecase;
  final DlcWalletTokenStore _tokenStore;
  final KeyValueStorageDatasource<String> _secureStorage;

  /// Call once when the DLC screen is first opened.
  /// Restores persisted state and determines whether to show the opt-in dialog.
  Future<void> initialize() async {
    if (state.status != DlcWalletAuthStatus.unknown) return;

    final optedOut = await _secureStorage.getValue(_kDlcOptedOutKey);
    if (optedOut == 'true') {
      emit(state.copyWith(status: DlcWalletAuthStatus.optedOut));
      return;
    }

    final savedToken = await _secureStorage.getValue(_kDlcWalletTokenKey);
    if (savedToken != null) {
      final savedWalletId =
          await _secureStorage.getValue(_kDlcWalletIdKey) ?? '';
      final savedPubkey =
          await _secureStorage.getValue(_kDlcFundingPubkeyKey) ?? '';

      _tokenStore.setRegistration(
        walletToken: savedToken,
        fundingPubkeyHex: savedPubkey,
        walletId: savedWalletId,
      );
      emit(state.copyWith(
        status: DlcWalletAuthStatus.registered,
        walletId: savedWalletId,
      ));
      return;
    }

    // No decision persisted — prompt the user.
    emit(state.copyWith(status: DlcWalletAuthStatus.notDecided));
  }

  /// Called when the user taps "Use DLC Options" in the opt-in dialog.
  Future<void> register() async {
    emit(state.copyWith(
      status: DlcWalletAuthStatus.registering,
      error: null,
    ));
    try {
      final result = await _registerDlcWalletUsecase.execute();

      // Persist for future app launches
      await _secureStorage.saveValue(
        key: _kDlcWalletTokenKey,
        value: result.walletToken,
      );
      await _secureStorage.saveValue(
        key: _kDlcWalletIdKey,
        value: result.walletId,
      );
      await _secureStorage.saveValue(
        key: _kDlcFundingPubkeyKey,
        value: result.fundingPubkeyHex,
      );

      emit(state.copyWith(
        status: DlcWalletAuthStatus.registered,
        walletId: result.walletId,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DlcWalletAuthStatus.failed,
        error: e.toString(),
      ));
    }
  }

  /// Called when the user taps "No, skip" in the opt-in dialog.
  Future<void> optOut() async {
    await _secureStorage.saveValue(key: _kDlcOptedOutKey, value: 'true');
    _tokenStore.clear();
    emit(state.copyWith(status: DlcWalletAuthStatus.optedOut));
  }

  /// Retry after a failed registration.
  void retryAfterFailure() {
    emit(state.copyWith(
      status: DlcWalletAuthStatus.notDecided,
      error: null,
    ));
  }

  /// Clear all persisted DLC auth data (used for sign-out / wallet change).
  Future<void> signOut() async {
    await _secureStorage.deleteValue(_kDlcWalletTokenKey);
    await _secureStorage.deleteValue(_kDlcWalletIdKey);
    await _secureStorage.deleteValue(_kDlcFundingPubkeyKey);
    await _secureStorage.deleteValue(_kDlcOptedOutKey);
    _tokenStore.clear();
    emit(const DlcWalletAuthState());
  }
}
