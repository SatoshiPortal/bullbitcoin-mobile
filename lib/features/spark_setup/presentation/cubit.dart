import 'package:bb_mobile/core/spark/entities/spark_wallet.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:bb_mobile/core/spark/usecases/enable_spark_usecase.dart';
import 'package:bb_mobile/core/spark/usecases/get_spark_wallet_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/spark_setup/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SparkSetupCubit extends Cubit<SparkSetupState> {
  final EnableSparkUsecase enableSparkUsecase;
  final GetSparkWalletUsecase getSparkWalletUsecase;
  final WalletBloc walletBloc;
  final SparkWalletEntity? wallet;

  SparkSetupCubit({
    required this.enableSparkUsecase,
    required this.getSparkWalletUsecase,
    required this.walletBloc,
    this.wallet,
  }) : super(SparkSetupState(wallet: wallet));

  Future<void> enableSpark() async {
    try {
      emit(state.copyWith(isLoading: true, error: null, wallet: null));

      await enableSparkUsecase.execute();

      final wallet = await getSparkWalletUsecase.execute(forceRefresh: true);

      if (wallet == null) {
        throw SparkError('Failed to initialize Spark wallet');
      }

      emit(state.copyWith(wallet: wallet));
      log.fine('Spark wallet created');

      walletBloc.add(const RefreshSparkWalletBalance());
    } catch (e) {
      emit(state.copyWith(error: SparkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
