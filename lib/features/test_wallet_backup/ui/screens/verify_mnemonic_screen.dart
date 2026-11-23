import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSnackBar, BullText, BullTypographyX;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:physical_backup_verification/physical_backup_verification.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret;

class VerifyMnemonicScreen extends StatelessWidget {
  final void Function(BuildContext) onTestSucceeded;

  const VerifyMnemonicScreen({super.key, required this.onTestSucceeded});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
      listenWhen: (previous, current) =>
          previous.verificationStatus != current.verificationStatus ||
          previous.failure != current.failure,
      listener: (context, state) {
        final bloc = context.read<TestWalletBackupBloc>();
        if (state.failure case final failure?) {
          // Keep the initial load failure available to the body; there is no
          // selected secret whose result would otherwise replace the spinner.
          if (state.selectedWallet == null) return;
          bloc.add(const ClearFailure());
          BullSnackBar.show(context, message: failure.toTranslated(context));
        } else if (state.verificationStatus ==
            BackupVerificationStatus.success) {
          bloc.add(const ClearFailure());
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BackupTestSuccessScreen(
                onContinue: () => onTestSucceeded(context),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final wallet = state.selectedWallet;
        final walletName = wallet?.isDefault ?? false
            ? context.loc.testBackupDefaultWallets
            : wallet?.displayLabel(context) ?? '';
        return Scaffold(
          backgroundColor: context.appColors.onSecondary,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AppBarWidget(
              title: context.loc.testBackupWalletTitle(walletName),
            ),
          ),
          body: switch (wallet) {
            null => switch (state.failure) {
              final failure? => Center(
                child: BullText(failure.toTranslated(context)),
              ),
              null => const Center(child: CircularProgressIndicator()),
            },
            _ => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SelectedChallenge(
                key: ValueKey<String?>(wallet.masterFingerprint),
              ),
            ),
          },
        );
      },
    );
  }
}

class _SelectedChallenge extends StatefulWidget {
  const _SelectedChallenge({super.key});

  @override
  State<_SelectedChallenge> createState() => _SelectedChallengeState();
}

class _SelectedChallengeState extends State<_SelectedChallenge> {
  late final Future<Result<Secret, TestWalletBackupFailure>> _secret = context
      .read<TestWalletBackupBloc>()
      .loadSelectedWalletSecret();
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TestWalletBackupBloc, TestWalletBackupState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure &&
          current.failure is TestWalletBackupCompletionFailure,
      listener: (_, _) => setState(() => _attempt++),
      child: _buildChallenge(),
    );
  }

  Widget _buildChallenge() {
    return FutureBuilder<Result<Secret, TestWalletBackupFailure>>(
      future: _secret,
      builder: (context, snapshot) {
        final failure = switch (snapshot.data) {
          Err(:final failure) => failure,
          _ when snapshot.hasError => const TestWalletBackupUnexpectedFailure(),
          _ => null,
        };
        if (failure != null) {
          return BullText(
            failure.toTranslated(context),
            textAlign: .center,
            style: context.bullType.body.copyWith(
              fontWeight: .w500,
              color: context.appColors.error,
            ),
          );
        }
        if (snapshot.data case Ok(:final value)) {
          final loc = context.loc;
          return PhysicalBackupChallenge(
            key: ValueKey(_attempt),
            secret: value,
            labels: (
              privacyUnavailable: loc.screenPrivacyUnavailable,
              retry: loc.retry,
              instruction: loc.testBackupTapWordsInOrder,
              wordNumber: loc.testBackupWhatIsWordNumber,
              allWordsSelected: loc.testBackupAllWordsSelected,
              incorrectOrder: loc.testBackupErrorIncorrectOrder,
              unavailable: loc.testBackupErrorSeedUnavailable,
              passphrasePrompt: loc.passphraseBackupPrompt,
              passphraseLabel: loc.passphraseLabel,
              showPassphrase: loc.passphraseShow,
              hidePassphrase: loc.passphraseHide,
              whitespaceWarning: loc.passphraseWhitespaceWarning,
              incorrectPassphrase: loc.passphraseIncorrect,
              continueLabel: loc.continueButton,
            ),
            onVerified: (proof) => context.read<TestWalletBackupBloc>().add(
              VerifyPhysicalBackup(proof),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
