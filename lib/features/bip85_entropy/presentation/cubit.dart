import 'package:bb_mobile/core/bip85/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_derivations_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_entropy/errors.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip85EntropyCubit extends Cubit<Bip85EntropyState> {
  final FetchAllBip85DerivationsUsecase _fetchAllBip85DerivationsUsecase;
  final DeriveNextBip85MnemonicFromDefaultWalletUsecase
  _deriveNextBip85MnemonicFromDefaultWalletUsecase;
  final DeriveNextBip85HexFromDefaultWalletUsecase
  _deriveNextBip85HexFromDefaultWalletUsecase;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final AliasBip85DerivationUsecase _aliasBip85DerivationUsecase;

  Bip85EntropyCubit({
    required FetchAllBip85DerivationsUsecase fetchAllBip85DerivationsUsecase,
    required DeriveNextBip85MnemonicFromDefaultWalletUsecase
    deriveNextBip85MnemonicFromDefaultWalletUsecase,
    required DeriveNextBip85HexFromDefaultWalletUsecase
    deriveNextBip85HexFromDefaultWalletUsecase,
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
    required AliasBip85DerivationUsecase aliasBip85DerivationUsecase,
  }) : _fetchAllBip85DerivationsUsecase = fetchAllBip85DerivationsUsecase,
       _deriveNextBip85MnemonicFromDefaultWalletUsecase =
           deriveNextBip85MnemonicFromDefaultWalletUsecase,
       _deriveNextBip85HexFromDefaultWalletUsecase =
           deriveNextBip85HexFromDefaultWalletUsecase,
       _getDefaultSeedUsecase = getDefaultSeedUsecase,
       _aliasBip85DerivationUsecase = aliasBip85DerivationUsecase,
       super(const Bip85EntropyState()) {
    init();
  }

  Future<void> init() async {
    try {
      await fetchXprvBase58();
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> fetchAllDerivations() async {
    final derivations = await _fetchAllBip85DerivationsUsecase.execute();
    emit(state.copyWith(derivations: derivations));
  }

  Future<void> fetchXprvBase58() async {
    final seed = await _getDefaultSeedUsecase.execute();
    final xprvBase58 = Bip32Derivation.getXprvFromSeed(
      seed.bytes,
      Network.bitcoinMainnet,
    );
    emit(state.copyWith(xprvBase58: xprvBase58));
  }

  Future<void> deriveNextMnemonic() async {
    try {
      await _deriveNextBip85MnemonicFromDefaultWalletUsecase.execute();
      await fetchAllDerivations();
    } catch (e) {
      emit(state.copyWith(error: Bip85EntropyError(e.toString())));
    }
  }

  Future<void> deriveNextHex() async {
    try {
      await _deriveNextBip85HexFromDefaultWalletUsecase.execute(length: 30);
      await fetchAllDerivations();
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

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const Bip85EntropyState());
}
