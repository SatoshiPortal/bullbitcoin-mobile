import 'package:bb_mobile/core/bip85/domain/activate_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_derivations_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/revoke_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_entropy/errors.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip85EntropyCubit extends Cubit<Bip85EntropyState> {
  final FetchAllBip85DerivationsUsecase _fetchAllBip85DerivationsUsecase;
  final DeriveNextBip85MnemonicFromDefaultWalletUsecase
  _deriveNextBip85MnemonicFromDefaultWalletUsecase;
  final DeriveNextBip85HexFromDefaultWalletUsecase
  _deriveNextBip85HexFromDefaultWalletUsecase;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final AliasBip85DerivationUsecase _aliasBip85DerivationUsecase;
  final RevokeBip85DerivationUsecase _revokeBip85DerivationUsecase;
  final ActivateBip85DerivationUsecase _activateBip85DerivationUsecase;

  Bip85EntropyCubit({
    required FetchAllBip85DerivationsUsecase fetchAllBip85DerivationsUsecase,
    required DeriveNextBip85MnemonicFromDefaultWalletUsecase
    deriveNextBip85MnemonicFromDefaultWalletUsecase,
    required DeriveNextBip85HexFromDefaultWalletUsecase
    deriveNextBip85HexFromDefaultWalletUsecase,
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
    required AliasBip85DerivationUsecase aliasBip85DerivationUsecase,
    required RevokeBip85DerivationUsecase revokeBip85DerivationUsecase,
    required ActivateBip85DerivationUsecase activateBip85DerivationUsecase,
  }) : _fetchAllBip85DerivationsUsecase = fetchAllBip85DerivationsUsecase,
       _deriveNextBip85MnemonicFromDefaultWalletUsecase =
           deriveNextBip85MnemonicFromDefaultWalletUsecase,
       _deriveNextBip85HexFromDefaultWalletUsecase =
           deriveNextBip85HexFromDefaultWalletUsecase,
       _getDefaultSeedUsecase = getDefaultSeedUsecase,
       _aliasBip85DerivationUsecase = aliasBip85DerivationUsecase,
       _revokeBip85DerivationUsecase = revokeBip85DerivationUsecase,
       _activateBip85DerivationUsecase = activateBip85DerivationUsecase,
       super(const Bip85EntropyState()) {
    init();
  }

  Future<void> init() async {
    try {
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> fetchAllDerivations() async {
    emit(state.copyWith(isLoading: true));
    final defaultSeed = await _getDefaultSeedUsecase.execute();
    final xprvBase58 = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      Network.bitcoinMainnet,
    );
    final derivations = await _fetchAllBip85DerivationsUsecase.execute();
    final derivationsWithEntropy = derivations.map((e) {
      final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: xprvBase58,
        path: bip85.Bip85HardenedPath(e.path),
      );
      return (derivation: e, entropy: entropy);
    }).toList();
    emit(state.copyWith(derivations: derivationsWithEntropy, isLoading: false));
  }

  Future<void> deriveNextMnemonic() async {
    try {
      emit(state.copyWith(isLoading: true));
      await _deriveNextBip85MnemonicFromDefaultWalletUsecase.execute();
      await fetchAllDerivations();
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> deriveNextHex() async {
    try {
      emit(state.copyWith(isLoading: true));
      await _deriveNextBip85HexFromDefaultWalletUsecase.execute(length: 30);
      await fetchAllDerivations();
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> aliasDerivation(
    Bip85DerivationEntity derivation,
    String alias,
  ) async {
    try {
      await _aliasBip85DerivationUsecase.execute(
        derivation: derivation,
        alias: alias,
      );
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> revokeDerivation(Bip85DerivationEntity derivation) async {
    try {
      await _revokeBip85DerivationUsecase.execute(derivation);
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> activateDerivation(Bip85DerivationEntity derivation) async {
    try {
      await _activateBip85DerivationUsecase.execute(derivation);
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const Bip85EntropyState());
}
