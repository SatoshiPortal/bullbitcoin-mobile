import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/address/bloc/address_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({
    required Address address,
    required this.walletSettingsCubit,
    required this.walletBloc,
    required this.walletAddress,
    required this.walletRepository,
    required this.hiveStorage,
    required this.walletRead,
  }) : super(AddressState(address: address));

  // final WalletStorage walletStorage;
  final WalletSettingsCubit walletSettingsCubit;
  final WalletBloc walletBloc;
  final WalletAddress walletAddress;
  final WalletRepository walletRepository;

  final HiveStorage hiveStorage;
  final WalletSync walletRead;

  void freezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await walletAddress.addAddressToWallet(
      address: (state.address!.index!, state.address!.address),
      label: state.address?.label,
      wallet: walletBloc.state.wallet!,
      kind: state.address!.kind,
      state: state.address!.state,
      spendable: false,
    );

    // final errUpdate = await walletRepository.updateWallet(
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

    walletBloc.add(UpdateWallet(w));
    await Future.delayed(const Duration(microseconds: 300));

    emit(state.copyWith(freezingAddress: false, frozenAddress: true, address: address));
  }

  void unfreezeAddress() async {
    emit(state.copyWith(freezingAddress: true, errFreezingAddress: ''));

    final (address, w) = await walletAddress.addAddressToWallet(
      address: (state.address!.index!, state.address!.address),
      label: state.address?.label,
      wallet: walletBloc.state.wallet!,
      kind: state.address!.kind,
      state: state.address!.state,
    );

    // final errUpdate = await walletRepository.updateWallet(
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

    walletBloc.add(UpdateWallet(w));
    await Future.delayed(const Duration(microseconds: 300));

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

    final (addr, w) = await walletAddress.addAddressToWallet(
      address: (address.index, address.address),
      label: label,
      wallet: walletBloc.state.wallet!,
      kind: address.kind,
      state: address.state,
    );

    // final errUpdate = await walletRepository.updateWallet(
    //   wallet: w,
    //   hiveStore: hiveStorage,
    // );
    // if (errUpdate != null) {
    //   emit(
    //     state.copyWith(
    //       savingAddressName: false,
    //       errSavingAddressName: errUpdate.toString(),
    //     ),
    //   );
    //   await Future.delayed(const Duration(seconds: 3));
    //   emit(state.copyWith(errSavingAddressName: ''));
    //   return;
    // }

    walletBloc.add(UpdateWallet(w));
    await Future.delayed(const Duration(microseconds: 300));

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
