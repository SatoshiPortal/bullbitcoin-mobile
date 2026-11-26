import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

import '../domain/delete_wallet_usecase.dart';
import '../domain/read_wallet_details_usecase.dart';
import '../domain/wallet_details.dart';
import '../domain/wallet_details_failure.dart';

sealed class WalletDetailsState {
  const WalletDetailsState();
}

final class WalletDetailsLoading extends WalletDetailsState {
  const WalletDetailsLoading();
}

final class WalletDetailsMissing extends WalletDetailsState {
  final WalletDetailsFailure failure;
  const WalletDetailsMissing(this.failure);
}

final class WalletDetailsLoaded extends WalletDetailsState {
  final WalletDetails details;
  final bool isDeleting;
  final WalletDetailsFailure? deletionFailure;

  const WalletDetailsLoaded(
    this.details, {
    this.isDeleting = false,
    this.deletionFailure,
  });
}

final class WalletDetailsDeleted extends WalletDetailsState {
  const WalletDetailsDeleted();
}

class WalletDetailsCubit extends Cubit<WalletDetailsState> {
  final ReadWalletDetailsUsecase _read;
  final DeleteWalletUsecase _delete;

  WalletDetailsCubit(this._read, this._delete)
    : super(const WalletDetailsLoading());

  Future<void> load(String walletId) async {
    final result = await _read.execute(walletId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => WalletDetailsLoaded(value),
      Err(:final failure) => WalletDetailsMissing(failure),
    });
  }

  Future<void> delete() async {
    final current = state;
    if (current is! WalletDetailsLoaded || current.isDeleting) return;
    emit(WalletDetailsLoaded(current.details, isDeleting: true));
    final result = await _delete.execute(current.details.id);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const WalletDetailsDeleted(),
      Err(:final failure) => WalletDetailsLoaded(
        current.details,
        deletionFailure: failure,
      ),
    });
  }
}
