import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/address/bloc/address_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({
    required Address address,
    required WalletBloc walletBloc,
    required WalletAddress walletAddress,
    required BDKUtxo bdkUtxo,
  })  : _walletAddress = walletAddress,
        _walletBloc = walletBloc,
        _bdkUtxo = bdkUtxo,
        super(AddressState(address: address));

  // final WalletStorage walletStorage;
  final WalletBloc _walletBloc;
  final WalletAddress _walletAddress;
  final BDKUtxo _bdkUtxo;

  Future<void> freezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await _walletAddress.addAddressToWallet(
      address: (state.address!.index, state.address!.address),
      label: state.address?.label,
      wallet: _walletBloc.state.wallet!,
      kind: state.address!.kind,
      state: state.address!.state,
      spendable: false,
    );

    final (utxoWallet, err) = _bdkUtxo.updateUtxoFromAddressSpendable(
      wallet: w,
      address: address,
      spendable: false,
    );

    if (err != null) {
      emit(
        state.copyWith(
          freezingAddress: false,
          errFreezingAddress: err.toString(),
        ),
      );
      return;
    }

    _walletBloc.add(
      UpdateWallet(
        utxoWallet!,
        updateTypes: [UpdateWalletTypes.addresses, UpdateWalletTypes.utxos],
      ),
    );

    emit(
      state.copyWith(
        freezingAddress: false,
        frozenAddress: true,
        address: address,
      ),
    );
  }

  Future<void> unfreezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await _walletAddress.addAddressToWallet(
      address: (state.address!.index, state.address!.address),
      label: state.address?.label,
      wallet: _walletBloc.state.wallet!,
      kind: state.address!.kind,
      state: state.address!.state,
    );

    final (utxoWallet, err) = _bdkUtxo.updateUtxoFromAddressSpendable(
      wallet: w,
      address: address,
      spendable: true,
    );

    if (err != null) {
      emit(
        state.copyWith(
          freezingAddress: false,
          errFreezingAddress: err.toString(),
        ),
      );
      return;
    }

    _walletBloc.add(
      UpdateWallet(
        utxoWallet!,
        updateTypes: [UpdateWalletTypes.addresses, UpdateWalletTypes.utxos],
      ),
    );

    // final errUpdate = await walletsStorageRepository.updateWallet(
    //   wallet: w,
    //   hiveStore: hiveStorage,
    // );
    // if (errUpdate != null) {
    //   emit(
    //     state.copyWith(
    //       freezingAddress: false,
    //       errFreezingAddress: errUpdate.toString(),
    //     ),
    //   );
    //   return;
    // }

    emit(
      state.copyWith(
        freezingAddress: false,
        frozenAddress: false,
        address: address,
      ),
    );
  }

  Future<void> saveAddressName(Address address, String label) async {
    emit(state.copyWith(savingAddressName: true, errSavingAddressName: ''));

    final (addr, w) = await _walletAddress.addAddressToWallet(
      address: (address.index, address.address),
      label: label,
      wallet: _walletBloc.state.wallet!,
      kind: address.kind,
      state: address.state,
    );
    if (!w.isLiquid()) {
      // pass utxo into cubit
      // make utxo interface
      final updatedWallet = await BDKUtxo().updateUtxoLabel(
        addressStr: address.address,
        wallet: w,
        label: label,
      );
      if (updatedWallet == null) {
        _walletBloc.add(
          UpdateWallet(
            w,
            updateTypes: [
              UpdateWalletTypes.addresses,
              UpdateWalletTypes.utxos,
            ],
          ),
        );
      } else {
        _walletBloc.add(
          UpdateWallet(
            updatedWallet,
            updateTypes: [
              UpdateWalletTypes.addresses,
              UpdateWalletTypes.utxos,
            ],
          ),
        );
      }
    } else {
      _walletBloc
          .add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.addresses]));
    }
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
