import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/public/broadcast_signed_tx_facade.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/device_instructions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class ShowPsbtScreen extends StatelessWidget {
  final String psbt;
  final SignerDeviceEntity? signerDevice;

  const ShowPsbtScreen({super.key, required this.psbt, this.signerDevice});

  @override
  Widget build(BuildContext context) {
    final canSignViaNfc =
        signerDevice == SignerDeviceEntity.coldcardQ ||
        signerDevice == SignerDeviceEntity.coldcardMk4;
    final qrType = signerDevice?.supportedQrType ?? QrType.none;
    final canSignViaQr = qrType != QrType.none;

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.psbtFlowSignTransaction)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Column(
              children: [
                if (canSignViaQr) ...[
                  ShowAnimatedQrWidget(
                    key: ValueKey('${psbt.hashCode}_$qrType'),
                    psbt: psbt,
                    qrType: qrType,
                    showSlider: qrType == QrType.urqr,
                  ),
                  const Gap(16),
                ] else ...[
                  BBButton.small(
                    label: context.loc.psbtFlowCopyPsbt,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: psbt));
                      if (!context.mounted) return;
                      SnackBarUtils.showSnackBar(
                        context,
                        context.loc.copiedToClipboardMessage,
                      );
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                    iconData: Icons.copy,
                    iconFirst: true,
                    outlined: true,
                  ),
                  const Gap(16),
                  Builder(
                    builder: (buttonContext) => BBButton.small(
                      label: context.loc.psbtFlowSharePsbt,
                      onPressed: () => _sharePsbt(buttonContext),
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onSecondary,
                      iconData: Icons.share,
                      iconFirst: true,
                      outlined: true,
                    ),
                  ),
                  const Gap(16),
                ],

                if (canSignViaNfc) ...[
                  BBButton.small(
                    label: context.loc.psbtFlowSignViaNfc,
                    onPressed: () => NfcBottomSheet.showWriteNfc(
                      context: context,
                      title: context.loc.psbtFlowSignViaNfcSheetTitle(
                        signerDevice!.displayName,
                      ),
                      data: psbt,
                      onSuccess: () async {
                        if (!context.mounted) return;
                        await _collectSignerResult(context);
                      },
                    ),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                    outlined: true,
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
                  BBButton.small(
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
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                    outlined: true,
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BBButton.big(
            label: context.loc.importSignedPsbtTitle,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            onPressed: () => _collectSignerResult(context),
          ),
        ),
      ),
    );
  }

  Future<void> _collectSignerResult(BuildContext context) async {
    const broadcastSignedTx = BroadcastSignedTxFacade();
    final signerResult = await context.pushNamed<String>(
      broadcastSignedTx.collectSignerResultRouteName,
      extra: broadcastSignedTx.collectSignerResultRequest(
        unsignedPsbt: psbt,
        allowNfc:
            signerDevice == SignerDeviceEntity.coldcardQ ||
            signerDevice == SignerDeviceEntity.coldcardMk4,
        allowBbqr: signerDevice == SignerDeviceEntity.coldcardQ,
      ),
    );
    if (signerResult != null && context.mounted) context.pop(signerResult);
  }

  Future<void> _sharePsbt(BuildContext context) async {
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        text: psbt,
        subject: 'unsigned.psbt',
        title: 'unsigned.psbt',
        sharePositionOrigin: _shareOrigin(context),
      ),
    );
  }
}

Rect _shareOrigin(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}
