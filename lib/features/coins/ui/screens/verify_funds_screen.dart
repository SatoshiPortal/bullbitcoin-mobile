import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/coins/presentation/verify_proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/verify_proof_of_funds_state.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Verify-funds screen: paste a message, the challenge address, and a `pof`
/// proof string, then run the full check (offline crypto + on-chain UTXO
/// lookup). Shows the three-state result plus per-UTXO status.
class VerifyFundsScreen extends StatefulWidget {
  const VerifyFundsScreen({super.key});

  @override
  State<VerifyFundsScreen> createState() => _VerifyFundsScreenState();
}

class _VerifyFundsScreenState extends State<VerifyFundsScreen> {
  String _message = '';
  String _address = '';
  String _proof = '';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.appColors;

    return BlocConsumer<VerifyProofOfFundsCubit, VerifyProofOfFundsState>(
      listener: (context, state) {
        if (state.status == VerifyProofOfFundsStatus.error &&
            state.error != null) {
          BullSnackBar.show(
            context,
            message: state.error!.toTranslated(context),
          );
          context.read<VerifyProofOfFundsCubit>().clearError();
        }
      },
      builder: (context, state) {
        return BullScaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                BullTopBar(
                  title: loc.proofOfFundsVerifyTitle,
                  onBack: context.pop,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BullInputText(
                          value: _message,
                          onChanged: (v) => setState(() => _message = v),
                          hint: loc.proofOfFundsMessageHint,
                        ),
                        const Gap(12),
                        BullInputText(
                          value: _address,
                          onChanged: (v) => setState(() => _address = v),
                          hint: loc.proofOfFundsChallengeAddressHint,
                        ),
                        const Gap(12),
                        BullInputText(
                          value: _proof,
                          onChanged: (v) => setState(() => _proof = v),
                          hint: loc.proofOfFundsProofHint,
                        ),
                        const Gap(24),
                        BullButton.big(
                          label: loc.proofOfFundsVerifyAction,
                          disabled:
                              _message.trim().isEmpty ||
                              _address.trim().isEmpty ||
                              _proof.trim().isEmpty ||
                              state.isWorking,
                          onPressed: () =>
                              context.read<VerifyProofOfFundsCubit>().verify(
                                message: _message.trim(),
                                challengeAddress: _address.trim(),
                                signature: _proof.trim(),
                              ),
                          bgColor: colors.primary,
                          textColor: colors.onPrimary,
                        ),
                        const Gap(24),
                        if (state.result != null)
                          _ResultView(result: state.result!),
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

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final ProofResult result;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.appColors;

    final (statusLabel, statusColor) = switch (result.status) {
      ProofStatus.valid => (loc.proofOfFundsStatusValid, colors.success),
      ProofStatus.inconclusive => (
        loc.proofOfFundsStatusInconclusive,
        colors.text,
      ),
      ProofStatus.invalid => (loc.proofOfFundsStatusInvalid, colors.error),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          statusLabel,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const Gap(12),
        for (final u in result.proven)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${u.outpoint.txId}:${u.outpoint.vout} — '
              '${_onChainLabel(loc, u.onChain)}',
              style: TextStyle(color: colors.text, fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _onChainLabel(AppLocalizations loc, OnChainStatus status) =>
      switch (status) {
        OnChainStatus.confirmedUnspent => loc.proofOfFundsUtxoConfirmed,
        OnChainStatus.spent => loc.proofOfFundsUtxoSpent,
        OnChainStatus.mismatchOrMissing => loc.proofOfFundsUtxoMismatch,
        OnChainStatus.notChecked => loc.proofOfFundsUtxoNotChecked,
      };
}
