import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/address/bloc/address_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({
    required Address address,
    required this.walletSettingsCubit,
    required this.walletCubit,
    required this.walletUpdate,
    required this.storage,
    required this.walletRead,
  }) : super(AddressState(address: address));

  // final WalletStorage walletStorage;
  final WalletSettingsCubit walletSettingsCubit;
  final WalletCubit walletCubit;
  final WalletUpdate walletUpdate;
  final IStorage storage;
  final WalletRead walletRead;

  void freezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await walletUpdate.updateWalletAddress(
      address: (state.address!.index, state.address!.address),
      label: state.address?.label,
      freeze: true,
      wallet: walletCubit.state.wallet!,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
    );
    if (errUpdate != null) {
      emit(
        state.copyWith(
          freezingAddress: false,
          errFreezingAddress: errUpdate.toString(),
        ),
      );
      return;
    }

    walletCubit.updateWallet(w);

    emit(state.copyWith(freezingAddress: false, frozenAddress: true, address: address));
  }

  void unfreezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await walletUpdate.updateWalletAddress(
      address: (state.address!.index, state.address!.address),
      label: state.address?.label,
      freeze: false,
      wallet: walletCubit.state.wallet!,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
    );
    if (errUpdate != null) {
      emit(
        state.copyWith(
          freezingAddress: false,
          errFreezingAddress: errUpdate.toString(),
        ),
      );
      return;
    }

    walletCubit.updateWallet(w);

    emit(
      state.copyWith(
        freezingAddress: false,
        frozenAddress: false,
        address: address,
      ),
    );
  }

  void saveAddressName(Address address, String label) async {
    emit(state.copyWith(savingAddressName: true, errSavingAddressName: ''));

    final (addr, w) = await walletUpdate.updateWalletAddress(
      address: (address.index, address.address),
      label: label,
      wallet: walletCubit.state.wallet!,
    );

    final errUpdate = await walletUpdate.updateWallet(
      wallet: w,
      walletRead: walletRead,
      storage: storage,
    );
    if (errUpdate != null) {
      emit(
        state.copyWith(
          savingAddressName: false,
          errSavingAddressName: errUpdate.toString(),
        ),
      );
      await Future.delayed(const Duration(seconds: 3));
      emit(state.copyWith(errSavingAddressName: ''));
      return;
    }

    walletCubit.updateWallet(w);

    emit(
      state.copyWith(
        address: addr,
        savingAddressName: false,
        savedAddressName: true,
      ),
    );
    await Future.delayed(const Duration(seconds: 3));
    emit(state.copyWith(savedAddressName: false));
  }
}
