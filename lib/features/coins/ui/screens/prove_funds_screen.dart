import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_state.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The largest `pof` proof string we render as a single static QR. Above this,
/// a QR code becomes too dense to scan reliably (byte-mode capacity), so the
/// proof is offered as copyable text only. ~1 KB comfortably fits ~1–3 UTXOs.
const _maxQrChars = 1000;

/// Prove-funds screen: the user enters a message and produces a BIP-322
/// Proof of Funds over the coins they selected on the previous screen. The
/// resulting `pof` string is shown as copyable text, plus a single QR when it
/// is small enough to scan.
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
                          // The proof is a BIP-322 `pof` string (base64 of a
                          // finalized PSBT), not a bare PSBT — so it is shown
                          // as a single static QR when small enough to scan,
                          // and always as copyable text. Larger proofs (many
                          // UTXOs) exceed single-QR capacity; copy is then the
                          // only transport.
                          if (signature.length <= _maxQrChars)
                            Center(child: QrDisplayWidget(data: signature))
                          else
                            Text(
                              loc.proofOfFundsTooLargeForQr,
                              style: TextStyle(color: colors.textMuted),
                            ),
                          const Gap(16),
                          Text(
                            signature,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontFamily: 'monospace',
                              fontSize: 11,
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
