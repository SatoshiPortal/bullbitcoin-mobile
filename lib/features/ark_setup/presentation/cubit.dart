import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/ark/usecases/create_ark_secret_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark_setup/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkSetupCubit extends Cubit<ArkSetupState> {
  final GetDefaultSeedUsecase getDefaultSeedUsecase;
  final CreateArkSecretUsecase createArkSecretUsecase;
  final WalletBloc walletBloc;
  final ArkWalletEntity? wallet;

  ArkSetupCubit({
    required this.getDefaultSeedUsecase,
    required this.createArkSecretUsecase,
    required this.walletBloc,
    this.wallet,
  }) : super(ArkSetupState(wallet: wallet));

  Future<void> createArkSecretKey() async {
    try {
      emit(state.copyWith(isLoading: true, error: null, wallet: null));
      final defaultSeed = await getDefaultSeedUsecase.execute();

      final (
        :String derivation,
        hex: String arkSecretHex,
      ) = await createArkSecretUsecase.execute(defaultSeed: defaultSeed);

      final wallet = await ArkWalletEntity.init(
        secretKey: hex.decode(arkSecretHex),
      );

      emit(state.copyWith(wallet: wallet));
      log.fine('ARK wallet created');

      // Trigger WalletBloc refresh to update ARK wallet data
      walletBloc.add(const RefreshArkWalletBalance());
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
