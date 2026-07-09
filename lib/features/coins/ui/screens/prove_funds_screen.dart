import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_state.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Prove-funds screen: the user enters a message and produces a BIP-322
/// Proof of Funds over the coins they selected on the previous screen. The
/// resulting `pof` string is shown as copyable text + an animated QR.
class ProveFundsScreen extends StatefulWidget {
  const ProveFundsScreen({super.key, required this.selectedUtxos});

  /// The Bitcoin UTXOs the user picked to prove (proof of funds is Bitcoin
  /// only; the caller filters to [BitcoinWalletUtxo]).
  final List<BitcoinWalletUtxo> selectedUtxos;

  @override
  State<ProveFundsScreen> createState() => _ProveFundsScreenState();
}

class _ProveFundsScreenState extends State<ProveFundsScreen> {
  String _message = '';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.appColors;

    return BlocConsumer<ProofOfFundsCubit, ProofOfFundsState>(
      listener: (context, state) {
        if (state.status == ProofOfFundsStatus.error && state.error != null) {
          BullSnackBar.show(
            context,
            message: state.error!.toTranslated(context),
          );
          context.read<ProofOfFundsCubit>().clearError();
        }
      },
      builder: (context, state) {
        final signature = state.signature;
        return BullScaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                BullTopBar(
                  title: loc.proofOfFundsProveTitle,
                  onBack: context.pop,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          loc.proofOfFundsProveSubtitle(
                            widget.selectedUtxos.length,
                          ),
                          style: TextStyle(color: colors.text),
                        ),
                        const Gap(16),
                        if (signature == null) ...[
                          BullInputText(
                            value: _message,
                            onChanged: (v) => setState(() => _message = v),
                            hint: loc.proofOfFundsMessageHint,
                          ),
                          const Gap(24),
                          BullButton.big(
                            label: loc.proofOfFundsProveAction,
                            disabled:
                                _message.trim().isEmpty || state.isWorking,
                            onPressed: () =>
                                context.read<ProofOfFundsCubit>().prove(
                                  message: _message.trim(),
                                  utxos: widget.selectedUtxos,
                                ),
                            bgColor: colors.primary,
                            textColor: colors.onPrimary,
                          ),
                        ] else ...[
                          Text(
                            loc.proofOfFundsProveResult,
                            style: TextStyle(color: colors.text),
                          ),
                          const Gap(12),
                          Center(
                            child: ShowAnimatedQrWidget(
                              psbt: signature,
                              qrType: QrType.bbqr,
                            ),
                          ),
                          const Gap(16),
                          BullButton.big(
                            label: loc.proofOfFundsCopy,
                            iconData: BullIcons.contentCopy,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: signature),
                              );
                              if (context.mounted) {
                                BullSnackBar.show(
                                  context,
                                  message: loc.proofOfFundsCopied,
                                );
                              }
                            },
                            bgColor: colors.surface,
                            textColor: colors.text,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
