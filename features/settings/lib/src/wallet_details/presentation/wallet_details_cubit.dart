import 'dart:async';

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
  late final StreamSubscription<bool> _lockSubscription;
  var _revocations = 0;
  String? _walletId;

  /// [lockChanges] is true on every lock and false on every unlock. A lock
  /// clears the old session's details and drops any result still in flight; the
  /// next unlock reads the wallet again, which tells whether a deletion
  /// committed before the lock.
  WalletDetailsCubit(this._read, this._delete, Stream<bool> lockChanges)
    : super(const WalletDetailsLoading()) {
    _lockSubscription = lockChanges.listen((locked) {
      if (locked) {
        _revocations++;
        if (!isClosed) emit(const WalletDetailsLoading());
      } else if (_walletId case final id? when !isClosed) {
        unawaited(load(id));
      }
    });
  }

  Future<void> load(String walletId) async {
    _walletId = walletId;
    final revocations = _revocations;
    final result = await _read.execute(walletId);
    if (isClosed || revocations != _revocations) return;
    emit(switch (result) {
      Ok(:final value) => WalletDetailsLoaded(value),
      Err(:final failure) => WalletDetailsMissing(failure),
    });
  }

  Future<void> delete() async {
    final current = state;
    if (current is! WalletDetailsLoaded || current.isDeleting) return;
    emit(WalletDetailsLoaded(current.details, isDeleting: true));
    final revocations = _revocations;
    final result = await _delete.execute(current.details.id);
    if (isClosed || revocations != _revocations) return;
    emit(switch (result) {
      Ok() => const WalletDetailsDeleted(),
      Err(:final failure) => WalletDetailsLoaded(
        current.details,
        deletionFailure: failure,
      ),
    });
  }

  @override
  Future<void> close() async {
    await _lockSubscription.cancel();
    await super.close();
  }
}
