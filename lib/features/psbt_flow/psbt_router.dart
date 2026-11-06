import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_screen.dart';
import 'package:go_router/go_router.dart';

enum PsbtFlowRoutes {
  show('/show-psbt');

  final String path;
  const PsbtFlowRoutes(this.path);
}

class PsbtRouterConfig {
  static final route = GoRoute(
    name: PsbtFlowRoutes.show.name,
    path: PsbtFlowRoutes.show.path,
    builder: (context, state) {
      if (state.extra case (
        psbt: final String psbt,
        signerDevice: final SignerDeviceEntity? signerDevice,
        wallet: final Wallet? wallet,
      ) when psbt.isNotEmpty) {
        return ShowPsbtScreen(
          psbt: psbt,
          signerDevice: signerDevice,
          wallet: wallet,
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
      );
    },
  );
}
