import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_repositories/app_wallets_repository.dart';
import 'package:bb_mobile/_repositories/wallet_service.dart';
import 'package:bb_mobile/address/bloc/address_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({
    required Address address,
    required Wallet wallet,
    required WalletAddress walletAddress,
    required BDKUtxo bdkUtxo,
    required AppWalletsRepository appWalletsRepository,
  })  : _walletAddress = walletAddress,
        _wallet = wallet,
        _bdkUtxo = bdkUtxo,
        _appWalletsRepository = appWalletsRepository,
        super(AddressState(address: address));

  final Wallet _wallet;
  final WalletAddress _walletAddress;
  final BDKUtxo _bdkUtxo;
  final AppWalletsRepository _appWalletsRepository;

  Future<void> freezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await _walletAddress.addAddressToWallet(
      address: (state.address!.index, state.address!.address),
      label: state.address?.label,
      wallet: _wallet,
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

    await _appWalletsRepository
        .getWalletServiceById(utxoWallet!.id)
        ?.updateWallet(
      utxoWallet,
      updateTypes: [
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.utxos,
      ],
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
      wallet: _wallet,
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

    await _appWalletsRepository
        .getWalletServiceById(utxoWallet!.id)
        ?.updateWallet(
      utxoWallet,
      updateTypes: [
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.utxos,
      ],
    );

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
      wallet: _wallet,
      kind: address.kind,
      state: address.state,
    );
    if (!w.isLiquid()) {
      final updatedWallet = await BDKUtxo().updateUtxoLabel(
        addressStr: address.address,
        wallet: w,
        label: label,
      );
      if (updatedWallet == null) {
        await _appWalletsRepository.getWalletServiceById(w.id)?.updateWallet(
          w,
          updateTypes: [
            UpdateWalletTypes.addresses,
            UpdateWalletTypes.utxos,
          ],
        );
      } else {
        await _appWalletsRepository
            .getWalletServiceById(updatedWallet.id)
            ?.updateWallet(
          updatedWallet,
          updateTypes: [
            UpdateWalletTypes.addresses,
            UpdateWalletTypes.utxos,
          ],
        );
      }
    } else {
      await _appWalletsRepository.getWalletServiceById(w.id)?.updateWallet(
        w,
        updateTypes: [UpdateWalletTypes.addresses],
      );
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
