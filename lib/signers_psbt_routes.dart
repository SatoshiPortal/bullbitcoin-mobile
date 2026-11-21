import 'package:signers/routes.dart';
import 'package:bb_mobile/features/scanning/public/nfc_scanning.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/signers.dart';
import 'package:go_router/go_router.dart';

class PsbtRouterConfig {
  static final route = GoRoute(
    name: PsbtFlowRoutes.show.name,
    path: PsbtFlowRoutes.show.path,
    builder: (context, state) {
      if (state.extra
          case (
            psbt: final String psbt,
            signerDevice: final SignerDeviceEntity? signerDevice,
          )
          when psbt.isNotEmpty) {
        return ShowPsbtScreen(
          psbt: psbt,
          signerDevice: signerDevice,
          writeNfc: (context, title, data, onSuccess) =>
              NfcBottomSheet.showWriteNfc(
                context: context,
                title: title,
                data: data,
                onSuccess: onSuccess,
              ),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
      );
    },
  );
}
