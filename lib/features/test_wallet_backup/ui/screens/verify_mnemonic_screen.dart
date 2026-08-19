import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class VerifyMnemonicScreen extends StatefulWidget {
  const VerifyMnemonicScreen({super.key});

  @override
  State<VerifyMnemonicScreen> createState() => _VerifyMnemonicScreenState();
}

class _VerifyMnemonicScreenState extends State<VerifyMnemonicScreen>
    with PrivacyScreen {
  /// The secret lives only in this ephemeral widget state — never in bloc
  /// state, so it can never leak through the freezed `toString()` or logs.
  List<String> _mnemonic = [];
  List<String> _shuffled = [];
  List<int> _selectedIndices = [];
  String? _fingerprint;
  bool _isLoading = true;

  late final Future<void> _privacyFuture = enableScreenPrivacy();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fingerprint = context
        .read<TestWalletBackupBloc>()
        .state
        .selectedWallet
        ?.masterFingerprint;
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      unawaited(_loadSecret());
    }
  }

  Future<void> _loadSecret() async {
    setState(() => _isLoading = true);
    try {
      final (mnemonic, _) = await context
          .read<TestWalletBackupBloc>()
          .loadSelectedWalletMnemonic();
      if (!mounted) return;
      setState(() {
        _mnemonic = mnemonic;
        _shuffled = [...mnemonic]..shuffle();
        _selectedIndices = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _resetGame() {
    setState(() {
      _shuffled = [..._mnemonic]..shuffle();
      _selectedIndices = [];
    });
  }

  void _onWordTap(int index) {
    final word = _shuffled[index];
    final candidate = [for (final i in _selectedIndices) _shuffled[i], word];

    final isCorrectSoFar = List.generate(
      candidate.length,
      (i) => candidate[i] == _mnemonic[i],
    ).every((e) => e);

    if (!isCorrectSoFar) {
      _resetGame();
      SnackBarUtils.showSnackBar(
        context,
        context.loc.testBackupErrorIncorrectOrder,
      );
      return;
    }

    setState(() => _selectedIndices.add(index));

    if (candidate.length == _mnemonic.length) {
      context.read<TestWalletBackupBloc>().add(
        VerifyPhysicalBackup(reorderedWords: candidate),
      );
    }
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _privacyFuture,
      builder: (context, snapshot) {
        return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
          listenWhen: (previous, current) =>
              previous.verificationStatus != current.verificationStatus ||
              (previous.statusError.isEmpty && current.statusError.isNotEmpty),
          listener: (context, state) {
            if (state.statusError.isNotEmpty) {
              SnackBarUtils.showSnackBar(context, state.statusError);
              context.read<TestWalletBackupBloc>().add(const ClearError());
              return;
            }
            switch (state.verificationStatus) {
              case BackupVerificationStatus.success:
                context.read<TestWalletBackupBloc>().add(const ClearError());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BackupTestSuccessScreen(),
                  ),
                );
              case BackupVerificationStatus.failure:
                _resetGame();
                SnackBarUtils.showSnackBar(
                  context,
                  context.loc.testBackupErrorIncorrectOrder,
                );
                context.read<TestWalletBackupBloc>().add(const ClearError());
              case BackupVerificationStatus.idle:
                break;
            }
          },
          builder: (context, state) {
            final walletName = state.selectedWallet?.isDefault ?? false
                ? context.loc.testBackupDefaultWallets
                : state.selectedWallet?.displayLabel(context) ?? '';
            final title = context.loc.testBackupWalletTitle(walletName);

            final nextWordNumber = _selectedIndices.length + 1;
            final showPrompt = _selectedIndices.length < _mnemonic.length;

            return Scaffold(
              backgroundColor: context.appColors.onSecondary,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      BBText(
                        context.loc.testBackupTapWordsInOrder,
                        textAlign: .center,
                        maxLines: 2,
                        style: context.font.headlineLarge?.copyWith(
                          fontWeight: .w600,
                          fontSize: 16,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(20),
                      if (showPrompt)
                        Column(
                          children: [
                            BBText(
                              context.loc.testBackupWhatIsWordNumber(
                                nextWordNumber,
                              ),
                              textAlign: .center,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: .w700,
                                color: context.appColors.outline,
                                letterSpacing: 0,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
                        BBText(
                          context.loc.testBackupAllWordsSelected,
                          textAlign: .center,
                          style: context.font.labelMedium?.copyWith(
                            fontWeight: .w700,
                            color: context.appColors.surface,
                            letterSpacing: 0,
                            fontSize: 14,
                          ),
                        ),
                      const Gap(16),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        _ShuffledMnemonicGrid(
                          shuffled: _shuffled,
                          selectedIndices: _selectedIndices,
                          onWordTap: _onWordTap,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ShuffledMnemonicGrid extends StatelessWidget {
  const _ShuffledMnemonicGrid({
    required this.shuffled,
    required this.selectedIndices,
    required this.onWordTap,
  });

  final List<String> shuffled;
  final List<int> selectedIndices;
  final ValueChanged<int> onWordTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < (shuffled.length + 1) ~/ 2; i++)
          Row(
            children: [
              Expanded(
                child: _ShuffledMnemonicWord(
                  index: i,
                  word: shuffled[i],
                  selectedIndices: selectedIndices,
                  onTap: onWordTap,
                ),
              ),
              if (i + (shuffled.length + 1) ~/ 2 < shuffled.length)
                Expanded(
                  child: _ShuffledMnemonicWord(
                    index: i + (shuffled.length + 1) ~/ 2,
                    word: shuffled[i + (shuffled.length + 1) ~/ 2],
                    selectedIndices: selectedIndices,
                    onTap: onWordTap,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
      ],
    );
  }
}

class _ShuffledMnemonicWord extends StatelessWidget {
  const _ShuffledMnemonicWord({
    required this.word,
    required this.index,
    required this.selectedIndices,
    required this.onTap,
  });

  final int index;
  final String word;
  final List<int> selectedIndices;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndices.contains(index);
    final selectedWordNumber = selectedIndices.indexOf(index) + 1;

    return InkWell(
      onTap: isSelected ? null : () => onTap(index),
      splashColor: context.appColors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(2.76),
          border: Border.all(color: context.appColors.border, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.appColors.border.withValues(alpha: 0.3),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        height: 41,
        child: Row(
          mainAxisSize: .min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Container(
                key: ValueKey(isSelected),
                width: 34.48,
                height: 34.48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.appColors.primary
                      : context.appColors.textMuted,
                  border: Border.all(
                    color: isSelected
                        ? context.appColors.primary
                        : context.appColors.textMuted,
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(2.46),
                ),
                child: Center(
                  child: BBText(
                    isSelected ? '$selectedWordNumber' : '00',
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: .w700,
                      fontSize: 16,
                      letterSpacing: 0.15,
                      color: context.appColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(12),
            BBText(
              word,
              textAlign: .start,
              maxLines: 2,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: .w700,
                fontSize: 14,
                color: context.appColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
