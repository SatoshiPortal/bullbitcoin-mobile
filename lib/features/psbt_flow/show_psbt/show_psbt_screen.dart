import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
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
      appBar: AppBar(title: const Text('Sign transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (signerDevice != null) ...[
                  if (signerDevice == SignerDeviceEntity.coldcardQ || 
                      signerDevice == SignerDeviceEntity.coldcardMk4) ...[
                    BBButton.small(
                      label: 'Sign via NFC',
                      onPressed:
                          () => NfcBottomSheet.showWriteNfc(
                            context: context,
                            title: 'Tap your ${signerDevice!.displayName} to send PSBT via NFC',
                            data: psbt,
                            onSuccess: () async {
                              if (context.mounted) {
                                await context.pushNamed(
                                  BroadcastSignedTxRoute.broadcastHome.name,
                                  extra: psbt,
                                );
                              }
                            },
                          ),
                      bgColor: context.colour.onSecondary,
                      textColor: context.colour.secondary,
                      outlined: true,
                    ),
                    const Gap(16),
                  ],
                  BBButton.small(
                    label: 'Instructions',
                    onPressed: () {
                      switch (signerDevice) {
                        case SignerDeviceEntity.coldcardQ:
                          QrDeviceInstructions.showColdcardQInstructions(context);
                        case SignerDeviceEntity.coldcardMk4:
                          QrDeviceInstructions.showColdcardMk4Instructions(context);
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
                        default:
                          break;
                      }
                    },
                    bgColor: context.colour.onSecondary,
                    textColor: context.colour.secondary,
                    outlined: true,
                  ),
                ],
              ],
            ),

            BBButton.big(
              label: "I'm done",
              bgColor: context.colour.secondary,
              textColor: context.colour.onPrimary,
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
