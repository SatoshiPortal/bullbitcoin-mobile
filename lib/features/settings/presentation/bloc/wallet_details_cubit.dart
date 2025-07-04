import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_details_cubit.freezed.dart';
part 'wallet_details_state.dart';

class WalletDetailsCubit extends Cubit<WalletDetailsState> {
  final String walletId;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final WalletBloc _walletBloc;

  WalletDetailsCubit({
    required this.walletId,
    DeleteWalletUsecase? deleteWalletUsecase,
    WalletBloc? walletBloc,
  }) : _deleteWalletUsecase =
           deleteWalletUsecase ?? locator<DeleteWalletUsecase>(),
       _walletBloc = walletBloc ?? locator<WalletBloc>(),
       super(const WalletDetailsState());

  Future<void> deleteWallet() async {
    try {
      emit(state.copyWith(deleteStatus: WalletDeleteStatus.loading));

      await _deleteWalletUsecase.execute(walletId: walletId);

      // Refresh wallet list after deletion
      _walletBloc.add(const WalletRefreshed());

      emit(state.copyWith(deleteStatus: WalletDeleteStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          deleteStatus: WalletDeleteStatus.error,
          deleteError: e.toString(),
        ),
      );
    }
  }
}
