import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/nfc/nfc_scan_flow.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_failure_l10n.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanNfcPage extends StatelessWidget {
  const ScanNfcPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.loc.broadcastSignedTxNfcTitle;
    final tagLostMessage = context.loc.nfcConnectionLost;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(title: title, onBack: () => context.pop()),
      ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();
          final failure = state.failure;

          return Column(
            children: [
              Expanded(
                child: NfcScanFlow(
                  session: locator<NfcSession>(),
                  run: (session) => session.readPushTxUri(
                    iosAlertMessage: title,
                    iosTagLostMessage: tagLostMessage,
                  ),
                  onPayload: cubit.onPushTxPayload,
                  onCancelled: () => context.pop(),
                ),
              ),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: BBText(
                    failure.toTranslated(context),
                    style: context.font.bodyMedium,
                    color: context.appColors.error,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
