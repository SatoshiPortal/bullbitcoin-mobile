import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/features/send/ui/screens/full_screen_scanner_page.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_appbar_progress.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_error_text.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SpSendRecipientPage extends StatefulWidget {
  const SpSendRecipientPage({super.key});

  @override
  State<SpSendRecipientPage> createState() => _SpSendRecipientPageState();
}

class _SpSendRecipientPageState extends State<SpSendRecipientPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Clear any prior recipient/amount/simulation on flow entry so a stale
    // value can't wedge re-entry or let a step be skipped.
    context.read<SpSendCubit>().resetSendFlow();
    // Rebuild the badge and Continue enablement as the user types. Typing does
    // NOT commit the recipient; that happens only on the Continue tap.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onContinue() {
    final cubit = context.read<SpSendCubit>();
    // Commit the typed address (runs the wrong-network check). Only advance
    // when it was accepted; otherwise the inline error stays on this page.
    cubit.previewRecipient(_controller.text);
    if (cubit.state.hasSendRecipient) {
      context.pushNamed(SpRoute.spSendAmount.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.spSend, style: context.font.headlineMedium),
          bottom: SpSendAppBarProgress(
            isLoading: context.select((SpSendCubit c) => c.state.isLoading),
          ),
        ),
        backgroundColor: context.appColors.secondaryFixedDim,
        body: Column(
          children: [
            Expanded(
              child: _SpCameraSection(
                onScanned: (address) {
                  _controller.text = address;
                },
              ),
            ),
            Card(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Gap(32),
                      Text(
                        context.loc.spSendRecipientLabel,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(16),
                      BBInputText(
                        controller: _controller,
                        focusNode: _focusNode,
                        value: _controller.text,
                        onChanged: (_) {},
                        maxLines: 3,
                        minLines: 1,
                        hint: context.loc.spSendRecipientHint,
                        rightIcon: Icon(
                          Icons.paste_outlined,
                          color: context.appColors.secondary,
                        ),
                        onRightTap: () {
                          Clipboard.getData(Clipboard.kTextPlain)
                              .then((value) {
                                if (value != null && mounted) {
                                  _controller.text = value.text ?? '';
                                }
                              })
                              .catchError((Object e) {
                                // A clipboard read can reject; swallow it so it
                                // is not an unhandled async error.
                              });
                        },
                      ),
                      const Gap(8),
                      _AddressTypeBadge(input: _controller.text),
                      const Gap(16),
                      BlocSelector<SpSendCubit, SpSendState, SpFailure?>(
                        selector: (s) => s.error,
                        builder: (context, failure) =>
                            SpSendErrorText(failure: failure),
                      ),
                      const Gap(16),
                      BBButton.big(
                        label: context.loc.continueButton,
                        onPressed: _onContinue,
                        disabled: _controller.text.trim().isEmpty,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpCameraSection extends StatelessWidget {
  const _SpCameraSection({required this.onScanned});
  final void Function(String address) onScanned;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.secondaryFixedDim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: context.appColors.secondary,
            ),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullScreenScannerPage(
                        onScannedPaymentRequest: (paymentRequest) {
                          onScanned(paymentRequest.$1);
                        },
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) => child,
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(context.loc.spSendScanQrButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTypeBadge extends StatelessWidget {
  const _AddressTypeBadge({required this.input});
  final String input;

  @override
  Widget build(BuildContext context) {
    if (input.trim().isEmpty) return const SizedBox.shrink();
    final (label, color) = switch (classifySpAddress(input)) {
      SpAddressKind.silentPaymentMainnet ||
      SpAddressKind.silentPaymentTestnet ||
      SpAddressKind.silentPaymentRegtest => (
        context.loc.spAddressTypeSilentPayment,
        context.appColors.success,
      ),
      SpAddressKind.bitcoin => (
        context.loc.spAddressTypeBitcoin,
        context.appColors.primary,
      ),
      SpAddressKind.unrecognized => (
        context.loc.spAddressTypeUnrecognized,
        context.appColors.error,
      ),
    };
    return BullBadge(
      label: label,
      background: color.withValues(alpha: 0.15),
      foreground: color,
      radius: 4,
      border: Border.all(color: color),
    );
  }
}
