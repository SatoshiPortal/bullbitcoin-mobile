import 'package:bb_mobile/features/bip85_entropy/domain/with_default_bip85_wallet_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/activate_bip85_derivation_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/revoke_bip85_derivation_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip85EntropyCubit extends Cubit<Bip85EntropyState> {
  bool _derivationInProgress = false;
  final WithDefaultBip85WalletUsecase _withDefaultWallet;
  final FetchAllBip85DerivationsWithEntropyUsecase
  _fetchAllBip85DerivationsWithEntropyUsecase;
  final DeriveNextBip85MnemonicFromDefaultWalletUsecase
  _deriveNextBip85MnemonicFromDefaultWalletUsecase;
  final DeriveNextBip85HexFromDefaultWalletUsecase
  _deriveNextBip85HexFromDefaultWalletUsecase;
  final AliasBip85DerivationUsecase _aliasBip85DerivationUsecase;
  final RevokeBip85DerivationUsecase _revokeBip85DerivationUsecase;
  final ActivateBip85DerivationUsecase _activateBip85DerivationUsecase;

  Bip85EntropyCubit({
    required this._withDefaultWallet,
    required this._fetchAllBip85DerivationsWithEntropyUsecase,
    required this._deriveNextBip85MnemonicFromDefaultWalletUsecase,
    required this._deriveNextBip85HexFromDefaultWalletUsecase,
    required this._aliasBip85DerivationUsecase,
    required this._revokeBip85DerivationUsecase,
    required this._activateBip85DerivationUsecase,
  }) : super(const Bip85EntropyState()) {
    init();
  }

  Future<void> init() async {
    await fetchAllDerivations();
  }

  Future<void> fetchAllDerivations() async {
    emit(state.copyWith(isLoading: true));
    switch (await _withDefaultWallet.execute(
      (fingerprint) => _fetchAllBip85DerivationsWithEntropyUsecase.execute(
        fingerprint: fingerprint,
      ),
    )) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
      case Ok(:final value):
        emit(
          state.copyWith(derivations: value, isLoading: false, failure: null),
        );
    }
  }

  Future<void> deriveNextMnemonic() async {
    if (_derivationInProgress) return;
    _derivationInProgress = true;
    emit(state.copyWith(isLoading: true, failure: null));
    switch (await _withDefaultWallet.execute(
      (fingerprint) => _deriveNextBip85MnemonicFromDefaultWalletUsecase.execute(
        fingerprint: fingerprint,
      ),
    )) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
      case Ok():
        await fetchAllDerivations();
    }
    _derivationInProgress = false;
  }

  Future<void> deriveNextHex() async {
    if (_derivationInProgress) return;
    _derivationInProgress = true;
    emit(state.copyWith(isLoading: true, failure: null));
    switch (await _withDefaultWallet.execute(
      (fingerprint) => _deriveNextBip85HexFromDefaultWalletUsecase.execute(
        fingerprint: fingerprint,
        length: 30,
      ),
    )) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
      case Ok():
        await fetchAllDerivations();
    }
    _derivationInProgress = false;
  }

  Future<void> aliasDerivation(
    Bip85DerivationEntity derivation,
    String alias,
  ) async {
    switch (await _aliasBip85DerivationUsecase.execute(
      derivation: derivation,
      alias: alias,
    )) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok():
        emit(state.copyWith(failure: null));
        await fetchAllDerivations();
    }
  }

  Future<void> revokeDerivation(Bip85DerivationEntity derivation) async {
    switch (await _revokeBip85DerivationUsecase.execute(derivation)) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok():
        emit(state.copyWith(failure: null));
        await fetchAllDerivations();
    }
  }

  Future<void> activateDerivation(Bip85DerivationEntity derivation) async {
    switch (await _activateBip85DerivationUsecase.execute(derivation)) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok():
        emit(state.copyWith(failure: null));
        await fetchAllDerivations();
    }
  }

  void clearFailure() => emit(state.copyWith(failure: null));

  void reset() => emit(const Bip85EntropyState());
}
