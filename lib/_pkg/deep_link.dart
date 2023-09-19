import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';

class DeepLink {
  StreamSubscription? _sub;

  Future<Err?> initUniLink({
    required Function(String) link,
    required Function(String) err,
  }) async {
    try {
      if (_sub != null) return null;
      _sub = linkStream.listen(
        (String? uri) {
          if (uri != null) link(uri);
        },
        onError: (err) {
          err(err.toString());
        },
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<Err?> handleUri({
    required String link,
    required SettingsCubit settingsCubit,
    required HomeCubit homeCubit,
    required BuildContext context,
  }) async {
    try {
      // check auth

      final bip21Obj = bip21.decode(link);
      final address = bip21Obj.address;
      final isTestnet = isTestnetAddress(address);
      if (isTestnet == null) return Err('Invalid address');
      final currentIsTestnet = settingsCubit.state.testnet;
      if (currentIsTestnet != isTestnet) settingsCubit.toggleTestnet();
      await Future.delayed(const Duration(milliseconds: 200));
      final wallet = homeCubit.state.getFirstWithSpendableAndBalance(
        isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet,
      );

      if (wallet == null) return Err('No wallet found');

      homeCubit.changeMoveToIdx(wallet);

      await Future.delayed(const Duration(milliseconds: 100));

      final walletBloc = homeCubit.state.selectedWalletCubit;

      if (walletBloc == null) return Err('No wallet found');

      // await SendPage.openSendPopUp(
      //   context,
      //   walletBloc,
      //   deepLinkUri: link,
      // );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}

bool? isTestnetAddress(String address) {
  // Mainnet addresses begin with '1', '3', or 'bc1', while testnet addresses begin with '2', 'm', 'n', or 'tb1'.
  if (address.startsWith('2') ||
      address.startsWith('m') ||
      address.startsWith('n') ||
      address.startsWith('tb1')) return true;

  if (address.startsWith('1') || address.startsWith('3') || address.startsWith('bc1')) return false;

  return null;
}
