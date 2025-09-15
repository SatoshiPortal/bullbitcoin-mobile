import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/core/ark/usecases/create_ark_secret_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/ark/ark.dart';
import 'package:bb_mobile/features/ark/errors.dart';
import 'package:bb_mobile/features/ark_setup/presentation/state.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkSetupCubit extends Cubit<ArkSetupState> {
  final GetDefaultSeedUsecase getDefaultSeedUsecase;
  final CreateArkSecretUsecase createArkSecretUsecase;

  ArkSetupCubit({
    required this.getDefaultSeedUsecase,
    required this.createArkSecretUsecase,
  }) : super(const ArkSetupState());

  Future<void> createArkSecretKey() async {
    try {
      emit(state.copyWith(isLoading: true, error: null, wallet: null));
      final defaultSeed = await getDefaultSeedUsecase.execute();

      final (
        :String derivation,
        hex: String arkSecretHex,
      ) = await createArkSecretUsecase.execute(defaultSeed: defaultSeed);

      final wallet = await ArkWallet.init(
        secretKey: hex.decode(arkSecretHex),
        network: Ark.network,
        esplora: Ark.esplora,
        server: Ark.server,
      );

      wallet.boardingAddress();

      emit(state.copyWith(wallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
