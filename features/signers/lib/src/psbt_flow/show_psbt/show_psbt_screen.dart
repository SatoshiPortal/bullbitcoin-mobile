import 'package:signers/src/signer_device.dart';
import 'package:signers/src/signers_l10n.dart';
import 'package:signers/src/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';
import 'package:signers/src/psbt_flow/show_psbt/device_instructions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullButtonSize, BullButton, Gap;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

typedef WriteSignerNfc = Future<void> Function(
  BuildContext context,
  String title,
  String data,
  VoidCallback onSuccess,
);

enum PsbtHandoffResult { readyToReadSignedTransaction }

class ShowPsbtScreen extends StatelessWidget {
  final GetIt services;
  final String psbt;
  final WriteSignerNfc writeNfc;
  final SignerDevice? signerDevice;

  const ShowPsbtScreen({
    super.key,
    required this.services,
    required this.psbt,
    required this.writeNfc,
    this.signerDevice,
  });

  @override
  Widget build(BuildContext context) {
    final device = signerDevice;
    final canSignViaNfc =
        signerDevice == SignerDevice.coldcardQ ||
        signerDevice == SignerDevice.coldcardMk4;

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
                    services: services,
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
                    onPressed: () => writeNfc(
                      context,
                      context.loc.psbtFlowSignViaNfcSheetTitle(
                        device.displayName,
                      ),
                      psbt,
                      () {
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
                  SignerDevice.coldcardQ,
                  SignerDevice.coldcardMk4,
                  SignerDevice.jade,
                  SignerDevice.krux,
                  SignerDevice.keystone,
                  SignerDevice.passport,
                  SignerDevice.seedsigner,
                  SignerDevice.specter,
                ].contains(signerDevice))
                  BullButton.secondary(
                    size: BullButtonSize.small,
                    label: context.loc.psbtFlowInstructions,
                    onPressed: () {
                      switch (signerDevice) {
                        case SignerDevice.coldcardQ:
                          QrDeviceInstructions.showColdcardQInstructions(
                            context,
                          );
                        case SignerDevice.coldcardMk4:
                          QrDeviceInstructions.showColdcardMk4Instructions(
                            context,
                          );
                        case SignerDevice.jade:
                          QrDeviceInstructions.showJadeInstructions(context);
                        case SignerDevice.krux:
                          QrDeviceInstructions.showKruxInstructions(context);
                        case SignerDevice.keystone:
                          QrDeviceInstructions.showKeystoneInstructions(
                            context,
                          );
                        case SignerDevice.passport:
                          QrDeviceInstructions.showPassportInstructions(
                            context,
                          );
                        case SignerDevice.seedsigner:
                          QrDeviceInstructions.showSeedSignerInstructions(
                            context,
                          );
                        case SignerDevice.specter:
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
