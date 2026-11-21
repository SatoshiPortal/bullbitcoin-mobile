import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/scanning/public/nfc_scanning.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/device_instructions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullButtonSize, BullButton, Gap;
import 'package:go_router/go_router.dart';

enum PsbtHandoffResult { readyToReadSignedTransaction }

class ShowPsbtScreen extends StatelessWidget {
  final String psbt;
  final SignerDeviceEntity? signerDevice;

  const ShowPsbtScreen({super.key, required this.psbt, this.signerDevice});

  @override
  Widget build(BuildContext context) {
    final device = signerDevice;
    final canSignViaNfc =
        signerDevice == SignerDeviceEntity.coldcardQ ||
        signerDevice == SignerDeviceEntity.coldcardMk4;

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.psbtFlowSignTransaction)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: [
            Column(
              children: [
                if (device != null &&
                    device.supportedQrType != QrType.none) ...[
                  ShowAnimatedQrWidget(
                    key: ValueKey('${psbt.hashCode}_${device.supportedQrType}'),
                    psbt: psbt,
                    qrType: device.supportedQrType,
                    showSlider: device.supportedQrType == QrType.urqr,
                  ),
                  const Gap(16),
                ],

                if (canSignViaNfc && device != null) ...[
                  BullButton.secondary(
                    size: BullButtonSize.small,
                    label: context.loc.psbtFlowSignViaNfc,
                    onPressed: () => NfcBottomSheet.showWriteNfc(
                      context: context,
                      title: context.loc.psbtFlowSignViaNfcSheetTitle(
                        device.displayName,
                      ),
                      data: psbt,
                      onSuccess: () async {
                        if (!context.mounted) return;
                        context.pop(
                          PsbtHandoffResult.readyToReadSignedTransaction,
                        );
                      },
                    ),
                  ),
                  const Gap(16),
                ],

                if ([
                  SignerDeviceEntity.coldcardQ,
                  SignerDeviceEntity.coldcardMk4,
                  SignerDeviceEntity.jade,
                  SignerDeviceEntity.krux,
                  SignerDeviceEntity.keystone,
                  SignerDeviceEntity.passport,
                  SignerDeviceEntity.seedsigner,
                  SignerDeviceEntity.specter,
                ].contains(signerDevice))
                  BullButton.secondary(
                    size: BullButtonSize.small,
                    label: context.loc.psbtFlowInstructions,
                    onPressed: () {
                      switch (signerDevice) {
                        case SignerDeviceEntity.coldcardQ:
                          QrDeviceInstructions.showColdcardQInstructions(
                            context,
                          );
                        case SignerDeviceEntity.coldcardMk4:
                          QrDeviceInstructions.showColdcardMk4Instructions(
                            context,
                          );
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
                  ),
              ],
            ),

            BullButton.primary(
              label: context.loc.psbtFlowDone,
              onPressed: () {
                context.pop(PsbtHandoffResult.readyToReadSignedTransaction);
              },
            ),
          ],
        ),
      ),
    );
  }
}
