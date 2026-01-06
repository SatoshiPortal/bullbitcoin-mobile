import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/device_instructions.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ShowPsbtScreen extends StatelessWidget {
  final String psbt;
  final SignerDeviceEntity? signerDevice;

  const ShowPsbtScreen({super.key, required this.psbt, this.signerDevice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.psbtFlowSignTransaction)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: [
            Column(
              children: [
                if (signerDevice != null &&
                    signerDevice!.supportedQrType != QrType.none) ...[
                  ShowAnimatedQrWidget(
                    key: ValueKey(
                      '${psbt.hashCode}_${signerDevice!.supportedQrType}',
                    ),
                    psbt: psbt,
                    qrType: signerDevice!.supportedQrType,
                    showSlider: signerDevice!.supportedQrType == QrType.urqr,
                  ),
                  const Gap(16),
                ],

                if (signerDevice != null)
                  BBButton.small(
                    label: context.loc.psbtFlowInstructions,
                    onPressed: () {
                      switch (signerDevice) {
                        case SignerDeviceEntity.jade:
                          QrDeviceInstructions.showJadeInstructions(context);
                        case SignerDeviceEntity.krux:
                          QrDeviceInstructions.showKruxInstructions(context);
                        case SignerDeviceEntity.keystone:
                          QrDeviceInstructions.showKeystoneInstructions(
                            context,
                          );
                        case SignerDeviceEntity.passport:
                          QrDeviceInstructions.showPassportInstructions(
                            context,
                          );
                        case SignerDeviceEntity.seedsigner:
                          QrDeviceInstructions.showSeedSignerInstructions(
                            context,
                          );
                        case SignerDeviceEntity.specter:
                          QrDeviceInstructions.showSpecterInstructions(context);
                        default:
                          break;
                      }
                    },
                    bgColor: context.appColors.onSecondary,
                    textColor: context.appColors.secondary,
                    outlined: true,
                  ),
              ],
            ),

            BBButton.big(
              label: context.loc.psbtFlowDone,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onPrimary,
              onPressed: () {
                context.pushNamed(
                  BroadcastSignedTxRoute.broadcastHome.name,
                  extra: psbt,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
