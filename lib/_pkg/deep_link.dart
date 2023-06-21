import 'dart:async';

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
  }

  Future<Err?> handleUri({
    required String link,
    required SettingsCubit settingsCubit,
    required HomeCubit homeCubit,
    required BuildContext context,
  }) async {
    try {
      // check auth
      // check network
      // switch network if needed
      // switch to first wallet with spendable + balance
      // if no balance just open on spendable
      // open send popup with fields filled
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
