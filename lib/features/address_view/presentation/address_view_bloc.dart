import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/check_wallet_is_liquid_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_view_bloc.freezed.dart';
part 'address_view_event.dart';
part 'address_view_state.dart';

class AddressViewBloc extends Bloc<AddressViewEvent, AddressViewState> {
  final String _walletId;
  final int _limit;
  final CheckWalletIsLiquidUsecase _checkWalletIsLiquidUsecase;
  final GetAddressListUsecase _getAddressListUsecase;

  AddressViewBloc({
    required this._walletId,
    required this._checkWalletIsLiquidUsecase,
    required this._getAddressListUsecase,
    int? limit,
  }) : _limit = limit ?? 20,
       super(const AddressViewState()) {
    on<AddressViewInitialAddressesLoaded>(_onInitialAddressesLoaded);
    on<AddressViewMoreReceiveAddressesLoaded>(_onMoreReceiveAddressesLoaded);
    on<AddressViewMoreChangeAddressesLoaded>(_onMoreChangeAddressesLoaded);
  }

  Future<void> _onInitialAddressesLoaded(
    AddressViewInitialAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        receiveAddressesFailure: null,
        changeAddressesFailure: null,
      ),
    );

    // Fetch receive and change addresses independently so one failing doesn't
    // prevent the other from loading.
    final (isLiquid, receiveResult, changeResult) = await (
      _checkWalletIsLiquidUsecase.execute(_walletId),
      _getAddressListUsecase.execute(walletId: _walletId, limit: _limit),
      _getAddressListUsecase.execute(
        walletId: _walletId,
        limit: _limit,
        isChange: true,
      ),
    ).wait;
    if (isClosed) return;

    emit(
      state.copyWith(
        isLiquid: switch (isLiquid) {
          Ok(value: final liquid) => liquid,
          Err() => state.isLiquid,
        },
        receiveAddresses: switch (receiveResult) {
          Ok(value: final addresses) => addresses,
          Err() => state.receiveAddresses,
        },
        receiveAddressesFailure: switch (receiveResult) {
          Ok() => null,
          Err(:final failure) => failure,
        },
        changeAddresses: switch (changeResult) {
          Ok(value: final addresses) => addresses,
          Err() => state.changeAddresses,
        },
        changeAddressesFailure: switch (changeResult) {
          Ok() => null,
          Err(:final failure) => failure,
        },
        hasReachedEndOfReceiveAddresses: switch (receiveResult) {
          Ok(value: final addresses) => addresses.length < _limit,
          Err() => state.hasReachedEndOfReceiveAddresses,
        },
        hasReachedEndOfChangeAddresses: switch (changeResult) {
          Ok(value: final addresses) => addresses.length < _limit,
          Err() => state.hasReachedEndOfChangeAddresses,
        },
        isLoading: false,
      ),
    );
  }

  Future<void> _onMoreReceiveAddressesLoaded(
    AddressViewMoreReceiveAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    if (state.isLoading || state.hasReachedEndOfReceiveAddresses) {
      return; // Prevent loading more if already loading or reached end
    }

    // Clearing the failure here keeps a stale error row from outliving the
    // request that produced it.
    emit(state.copyWith(isLoading: true, receiveAddressesFailure: null));

    final result = await _getAddressListUsecase.execute(
      walletId: _walletId,
      limit: _limit,
      fromIndex: state.nextReceiveAddressIndexToLoad,
    );
    if (isClosed) return;

    switch (result) {
      case Ok(value: final moreReceiveAddresses):
        emit(
          state.copyWith(
            receiveAddresses: [
              ...state.receiveAddresses,
              ...moreReceiveAddresses,
            ],
            hasReachedEndOfReceiveAddresses:
                moreReceiveAddresses.length < _limit ||
                moreReceiveAddresses.lastOrNull?.index == 0,
            isLoading: false,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(receiveAddressesFailure: failure, isLoading: false),
        );
    }
  }

  Future<void> _onMoreChangeAddressesLoaded(
    AddressViewMoreChangeAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    if (state.isLoading || state.hasReachedEndOfChangeAddresses) {
      return; // Prevent loading more if already loading or reached end
    }

    emit(state.copyWith(isLoading: true, changeAddressesFailure: null));

    final result = await _getAddressListUsecase.execute(
      walletId: _walletId,
      isChange: true,
      limit: _limit,
      fromIndex: state.nextChangeAddressIndexToLoad,
    );
    if (isClosed) return;

    switch (result) {
      case Ok(value: final moreChangeAddresses):
        emit(
          state.copyWith(
            changeAddresses: [...state.changeAddresses, ...moreChangeAddresses],
            hasReachedEndOfChangeAddresses:
                moreChangeAddresses.length < _limit ||
                moreChangeAddresses.lastOrNull?.index == 0,
            isLoading: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(changeAddressesFailure: failure, isLoading: false));
    }
  }
}
