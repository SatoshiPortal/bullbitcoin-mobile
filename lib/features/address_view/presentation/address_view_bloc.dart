import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_view_bloc.freezed.dart';
part 'address_view_event.dart';
part 'address_view_state.dart';

class AddressViewBloc extends Bloc<AddressViewEvent, AddressViewState> {
  final String _walletId;
  final int _limit;
  final GetWalletUsecase _getWalletUseCase;
  final GetAddressListUsecase _getAddressListUseCase;

  AddressViewBloc({
    required String walletId,
    required GetWalletUsecase getWalletUseCase,
    required GetAddressListUsecase getAddressListUseCase,
    int? limit,
  }) : _walletId = walletId,
       _limit = limit ?? 20, // Default limit if not provided
       _getWalletUseCase = getWalletUseCase,
       _getAddressListUseCase = getAddressListUseCase,
       super(const AddressViewState()) {
    on<AddressViewInitialAddressesLoaded>(_onInitialAddressesLoaded);
    on<AddressViewMoreReceiveAddressesLoaded>(_onMoreReceiveAddressesLoaded);
    on<AddressViewMoreChangeAddressesLoaded>(_onMoreChangeAddressesLoaded);
  }

  Future<void> _onInitialAddressesLoaded(
    AddressViewInitialAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    debugPrint('Loading initial addresses for wallet: $_walletId');
    emit(state.copyWith(isLoading: true));

    try {
      final wallet = await _getWalletUseCase.execute(_walletId);

      // Fetch initial receive and change addresses and handle errors separately
      // so that one failing doesn't prevent the other from loading.
      final (receiveAddresses, changeAddresses) = await (
        () async {
          try {
            return _getAddressListUseCase.execute(
              walletId: _walletId,
              limit: _limit,
            );
          } catch (e) {
            if (e is WalletError) {
              emit(state.copyWith(receiveAddressesError: e));
            }
            return <WalletAddress>[];
          }
        }(),
        () async {
          try {
            return _getAddressListUseCase.execute(
              walletId: _walletId,
              limit: _limit,
              isChange: true,
            );
          } catch (e) {
            if (e is WalletError) {
              emit(state.copyWith(changeAddressesError: e));
            }
            return <WalletAddress>[];
          }
        }(),
      ).wait;

      emit(
        state.copyWith(
          isLiquid: wallet?.isLiquid ?? false,
          receiveAddresses: receiveAddresses,
          changeAddresses: changeAddresses,
          hasReachedEndOfReceiveAddresses: receiveAddresses.length < _limit,
          hasReachedEndOfChangeAddresses: changeAddresses.length < _limit,
          isLoading: false,
        ),
      );
    } on WalletError catch (error) {
      emit(
        state.copyWith(
          receiveAddressesError: error,
          changeAddressesError: error,
          isLoading: false,
        ),
      );
    } on GetWalletException catch (e) {
      // No need to handle this here since the address loading functions already
      // handle their own errors and we just need the wallet type to show
      // "Coming Soon" for Liquid change addresses or not and the state already
      // has a default value for it.
      debugPrint('Error loading wallet: $e');
      return;
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onMoreReceiveAddressesLoaded(
    AddressViewMoreReceiveAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    if (state.isLoading || state.hasReachedEndOfReceiveAddresses) {
      return; // Prevent loading more if already loading or reached end
    }

    try {
      emit(state.copyWith(isLoading: true));

      final moreReceiveAddresses = await _getAddressListUseCase.execute(
        walletId: _walletId,
        limit: _limit,
        fromIndex: state.nextReceiveAddressIndexToLoad,
      );

      emit(
        state.copyWith(
          receiveAddresses: List.from(state.receiveAddresses)
            ..addAll(moreReceiveAddresses),
          hasReachedEndOfReceiveAddresses:
              moreReceiveAddresses.length < _limit ||
              moreReceiveAddresses.lastOrNull?.index == 0,
        ),
      );
    } on WalletError catch (error) {
      emit(state.copyWith(receiveAddressesError: error));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onMoreChangeAddressesLoaded(
    AddressViewMoreChangeAddressesLoaded event,
    Emitter<AddressViewState> emit,
  ) async {
    if (state.isLoading || state.hasReachedEndOfChangeAddresses) {
      return; // Prevent loading more if already loading or reached end
    }

    try {
      emit(state.copyWith(isLoading: true));

      final moreChangeAddresses = await _getAddressListUseCase.execute(
        walletId: _walletId,
        isChange: true,
        limit: _limit,
        fromIndex: state.nextChangeAddressIndexToLoad,
      );

      emit(
        state.copyWith(
          changeAddresses: List.from(state.changeAddresses)
            ..addAll(moreChangeAddresses),
          hasReachedEndOfChangeAddresses:
              moreChangeAddresses.length < _limit ||
              moreChangeAddresses.lastOrNull?.index == 0,
        ),
      );
    } on WalletError catch (error) {
      emit(state.copyWith(changeAddressesError: error));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
