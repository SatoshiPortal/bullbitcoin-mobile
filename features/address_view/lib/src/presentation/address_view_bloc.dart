import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:primitives/primitives.dart';
import 'package:address_view/address_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/watch_address_revisions_usecase.dart';

part 'address_view_bloc.freezed.dart';
part 'address_view_event.dart';
part 'address_view_state.dart';

class AddressViewBloc extends Bloc<AddressViewEvent, AddressViewState> {
  final String _walletId;
  final int _limit;
  final AddressView _addresses;

  StreamSubscription<void>? _revisions;

  AddressViewBloc({
    WatchAddressRevisionsUsecase? watchRevisions,
    required this._walletId,
    required this._addresses,
    int? limit,
  }) : _limit = limit ?? 20,
       super(const AddressViewState()) {
    on<AddressViewInitialAddressesLoaded>(
      _onInitialAddressesLoaded,
      transformer: restartable(),
    );
    _revisions = watchRevisions?.execute(_walletId).listen((_) {
      if (!isClosed) add(const AddressViewInitialAddressesLoaded());
    });
    on<AddressViewMoreReceiveAddressesLoaded>(_onMoreReceiveAddressesLoaded);
    on<AddressViewMoreChangeAddressesLoaded>(_onMoreChangeAddressesLoaded);
  }

  @override
  Future<void> close() async {
    await _revisions?.cancel();
    return super.close();
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
      _addresses.isLiquid(_walletId),
      _addresses.list(walletId: _walletId, limit: _limit),
      _addresses.list(walletId: _walletId, limit: _limit, change: true),
    ).wait;
    if (isClosed || emit.isDone) return;

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

    final result = await _addresses.list(
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

    final result = await _addresses.list(
      walletId: _walletId,
      change: true,
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
