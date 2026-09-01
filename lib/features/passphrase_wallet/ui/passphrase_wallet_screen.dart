import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_cubit.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_failure_l10n.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_state.dart';
import 'package:bb_mobile/features/passphrase_wallet/ui/passphrase_input.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/public/wallet_routes.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

final class PassphraseWalletScreen extends StatefulWidget {
  const PassphraseWalletScreen({super.key});

  @override
  State<PassphraseWalletScreen> createState() => _PassphraseWalletScreenState();
}

final class _PassphraseWalletScreenState extends State<PassphraseWalletScreen>
    with WidgetsBindingObserver, PrivacyScreen {
  final _keyboardKey = GlobalKey<PassphraseInputState>();
  late final PassphraseWalletCubit _cubit;

  // The screen-privacy overlay is a platform capability of this widget, not
  // page state: nothing outside the screen can observe or act on it.
  var _privacyReady = false;
  var _privacyFailed = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PassphraseWalletCubit>();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enablePrivacy());
  }

  Future<void> _enablePrivacy() async {
    try {
      await enableScreenPrivacy();
      if (mounted) setState(() => _privacyReady = true);
    } on Exception {
      if (mounted) setState(() => _privacyFailed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _keyboardKey.currentState?.clear();
    _cubit.cancelEntry();
  }

  @override
  void dispose() {
    // The Cubit clears any candidate it still holds when it closes; only this
    // widget's own input buffer is ours to zero here.
    _keyboardKey.currentState?.clear();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.passphraseWalletPageTitle)),
      body: SafeArea(
        child: BlocBuilder<PassphraseWalletCubit, PassphraseWalletState>(
          builder: (context, state) {
            if (_privacyFailed ||
                state.status == PassphraseWalletLoadStatus.failure) {
              return _ErrorView(
                onRetry: () {
                  if (_privacyFailed) {
                    setState(() => _privacyFailed = false);
                    unawaited(_enablePrivacy());
                  }
                  unawaited(_cubit.load());
                },
              );
            }
            if (!_privacyReady ||
                state.status == PassphraseWalletLoadStatus.loading ||
                state.status == PassphraseWalletLoadStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.wallets.isNotEmpty) ...[
                  Text(
                    context.loc.passphraseWalletHistoryIntro,
                    style: context.font.bodyMedium,
                  ),
                  const Gap(12),
                  for (final card in state.wallets) ...[
                    _PassphraseWalletCard(
                      card: card,
                      isLoaded: state.isLoaded(card.wallet.walletId),
                    ),
                    const Gap(12),
                  ],
                ],
                if (state.isEntering) ...[
                  Text(
                    context.loc.passphraseWalletInputTitle,
                    style: context.font.headlineMedium,
                  ),
                  const Gap(8),
                  Text(
                    context.loc.passphraseWalletInputHelp,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  const Gap(12),
                  PassphraseInput(
                    key: _keyboardKey,
                    showLabel: context.loc.passphraseWalletShow,
                    hideLabel: context.loc.passphraseWalletHide,
                    lettersLabel: context.loc.passphraseWalletKeyboardLetters,
                    symbolsLabel: context.loc.passphraseWalletKeyboardSymbols,
                    spaceLabel: context.loc.passphraseWalletKeyboardSpace,
                  ),
                  const Gap(12),
                  BBButton.big(
                    label: context.loc.passphraseWalletEnter,
                    onPressed: _submit,
                    disabled: state.isSubmitting,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ] else if (state.hasLoadedWallet) ...[
                  Text(
                    context.loc.passphraseWalletLoaded,
                    style: context.font.headlineMedium,
                  ),
                  const Gap(12),
                  BBButton.big(
                    label: context.loc.passphraseWalletCreateNewPassphrase,
                    onPressed: _startCreating,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ] else
                  BBButton.big(
                    label: context.loc.passphraseWalletEnter,
                    onPressed: _startEntering,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _startEntering() => _cubit.startEntering();

  void _startCreating() => _cubit.startCreatingAnother();

  Future<void> _submit() async {
    final result = await _cubit.submitPassphrase(
      _keyboardKey.currentState?.takeValue() ?? '',
    );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        _showFailure(failure);
      case Ok(:final value):
        if (value.status == PassphraseWalletEntryStatus.openedKnown) {
          _openHome();
          return;
        }
        final confirmed = await _showGeneralDisclaimer();
        if (!mounted) return;
        if (!confirmed) {
          _cubit.discardCandidate();
        } else if (value.hasHistory && !await _showUnmatchedWarning()) {
          _cubit.discardCandidate();
        } else {
          final details = await _showWalletDetails();
          if (!mounted) return;
          if (details == null) {
            _cubit.discardCandidate();
          } else {
            await _createWallet(details);
          }
        }
    }
  }

  Future<bool> _showGeneralDisclaimer() async {
    return await BlurredDialog.show<bool>(
          context: context,
          isDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.appColors.surface,
            title: Text(context.loc.passphraseWalletDisclaimerTitle),
            content: SingleChildScrollView(
              child: _PassphraseDisclaimerText(
                text: context.loc.passphraseWalletDisclaimerBody,
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.passphraseWalletEditPassphrase,
                      onPressed: () => Navigator.pop(dialogContext, false),
                      bgColor: context.appColors.transparent,
                      textColor: context.appColors.primary,
                      outlined: true,
                      borderColor: context.appColors.primary,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.continueButton,
                      onPressed: () => Navigator.pop(dialogContext, true),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showUnmatchedWarning() async =>
      await BlurredDialog.show<bool>(
        context: context,
        isDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: context.appColors.surface,
          title: Text(context.loc.passphraseWalletDisclaimerTitle),
          content: Text(context.loc.passphraseWalletUnmatchedWarning),
          actions: [
            Row(
              children: [
                Expanded(
                  child: BBButton.small(
                    label: context.loc.passphraseWalletEditPassphrase,
                    onPressed: () => Navigator.pop(dialogContext, false),
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.primary,
                    outlined: true,
                    borderColor: context.appColors.primary,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: BBButton.small(
                    label: context.loc.passphraseWalletCreateNew,
                    onPressed: () => Navigator.pop(dialogContext, true),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;

  Future<_PassphraseWalletDetails?> _showWalletDetails() =>
      Navigator.of(context).push<_PassphraseWalletDetails>(
        MaterialPageRoute(
          builder: (_) => const _PassphraseWalletDetailsScreen(),
        ),
      );

  Future<void> _createWallet(_PassphraseWalletDetails details) async {
    final result = await _cubit.confirmNewWallet(
      label: details.label,
      hint: details.hint,
    );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        _showFailure(failure);
      case Ok(:final value):
        if (value == PassphraseWalletOpenStatus.savedButNotOpened) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.passphraseWalletSavedNotOpened,
          );
          await _cubit.load();
        } else {
          _openHome();
        }
    }
  }

  void _openHome() => context.goNamed(WalletRoute.walletHome.name);

  void _showFailure(PassphraseWalletFailure failure) =>
      SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
}

final class _PassphraseWalletDetails {
  final String? label;
  final String? hint;

  const _PassphraseWalletDetails({required this.label, required this.hint});
}

final class _PassphraseWalletDetailsScreen extends StatefulWidget {
  const _PassphraseWalletDetailsScreen();

  @override
  State<_PassphraseWalletDetailsScreen> createState() =>
      _PassphraseWalletDetailsScreenState();
}

final class _PassphraseWalletDetailsScreenState
    extends State<_PassphraseWalletDetailsScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _hintController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _hintController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.passphraseWalletDetailsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.loc.passphraseWalletOptionalLabel,
              style: context.font.headlineMedium,
            ),
            const Gap(8),
            Text(
              context.loc.passphraseWalletLabelHelp,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            TextField(
              controller: _labelController,
              maxLength: 50,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.loc.passphraseWalletOptionalLabel,
              ),
            ),
            const Gap(24),
            Text(
              context.loc.passphraseWalletOptionalHint,
              style: context.font.headlineMedium,
            ),
            const Gap(8),
            Text(
              context.loc.passphraseWalletHintHelp,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            TextField(
              controller: _hintController,
              maxLength: 200,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.loc.passphraseWalletOptionalHint,
                alignLabelWithHint: true,
              ),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: BBButton.small(
                    label: context.loc.passphraseWalletEditPassphrase,
                    onPressed: () => Navigator.pop(context),
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.primary,
                    outlined: true,
                    borderColor: context.appColors.primary,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: BBButton.small(
                    label: context.loc.passphraseWalletCreateNew,
                    onPressed: _submit,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final label = _labelController.text.trim();
    final hint = _hintController.text.trim();
    Navigator.pop(
      context,
      _PassphraseWalletDetails(
        label: label.isEmpty ? null : label,
        hint: hint.isEmpty ? null : hint,
      ),
    );
  }
}

final class _PassphraseDisclaimerText extends StatelessWidget {
  final String text;

  const _PassphraseDisclaimerText({required this.text});

  @override
  Widget build(BuildContext context) {
    final firstMarker = text.indexOf('*');
    final secondMarker = firstMarker < 0
        ? -1
        : text.indexOf('*', firstMarker + 1);
    if (firstMarker < 0 || secondMarker < 0) {
      return Text(text, style: context.font.bodyMedium);
    }
    final style = context.font.bodyMedium;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, firstMarker)),
          TextSpan(
            text: text.substring(firstMarker + 1, secondMarker),
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
          TextSpan(text: text.substring(secondMarker + 1)),
        ],
      ),
    );
  }
}

final class _PassphraseHintScreen extends StatefulWidget {
  final String? initialValue;

  const _PassphraseHintScreen({this.initialValue});

  @override
  State<_PassphraseHintScreen> createState() => _PassphraseHintScreenState();
}

final class _PassphraseHintScreenState extends State<_PassphraseHintScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.passphraseWalletUpdateHintTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.loc.passphraseWalletOptionalHint,
              style: context.font.headlineMedium,
            ),
            const Gap(8),
            Text(
              context.loc.passphraseWalletHintHelp,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            TextField(
              controller: _controller,
              maxLength: 200,
              minLines: 3,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.loc.passphraseWalletOptionalHint,
                alignLabelWithHint: true,
              ),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: BBButton.small(
                    label: context.loc.passphraseWalletRemoveHint,
                    onPressed: () => Navigator.pop(context, ''),
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.primary,
                    outlined: true,
                    borderColor: context.appColors.primary,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: BBButton.small(
                    label: context.loc.save,
                    onPressed: () => Navigator.pop(context, _controller.text),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.loc.passphraseWalletLoadError),
          const Gap(12),
          FilledButton(onPressed: onRetry, child: Text(context.loc.retry)),
        ],
      ),
    ),
  );
}

final class _PassphraseWalletCard extends StatelessWidget {
  final PassphraseWalletCardState card;
  final bool isLoaded;

  const _PassphraseWalletCard({required this.card, required this.isLoaded});

  @override
  Widget build(BuildContext context) {
    final wallet = card.wallet;
    final hideAmounts =
        context.select((SettingsCubit c) => c.state.hideAmounts) ?? true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    wallet.label ??
                        context.loc.walletBackupManifestPassphraseWallet,
                    style: context.font.headlineSmall,
                  ),
                ),
                Text(
                  isLoaded
                      ? context.loc.passphraseWalletLoadedStatus
                      : context.loc.passphraseWalletLocked,
                ),
              ],
            ),
            const Gap(12),
            _cardRow(
              context,
              context.loc.passphraseWalletBalanceLabel,
              _balance(context, hideAmounts),
            ),
            _cardRow(
              context,
              context.loc.passphraseWalletCreationDateLabel,
              DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(wallet.createdAt.toLocal()),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => _showHint(context),
                  child: Text(context.loc.passphraseWalletShowHint),
                ),
                if (card.balanceStatus == PassphraseWalletBalanceStatus.failure)
                  TextButton(
                    onPressed: () => context
                        .read<PassphraseWalletCubit>()
                        .retryBalance(wallet.walletId),
                    child: Text(context.loc.retry),
                  ),
                TextButton(
                  onPressed: () => _editHint(context),
                  child: Text(context.loc.passphraseWalletEditHint),
                ),
                TextButton(
                  onPressed: () => _forget(context),
                  child: Text(context.loc.passphraseWalletForget),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _balance(BuildContext context, bool hideAmounts) =>
      switch (card.balanceStatus) {
        PassphraseWalletBalanceStatus.idle ||
        PassphraseWalletBalanceStatus.syncing =>
          context.loc.passphraseWalletSyncing,
        PassphraseWalletBalanceStatus.failure =>
          context.loc.passphraseWalletSyncError,
        PassphraseWalletBalanceStatus.success =>
          hideAmounts
              ? '••••'
              : FormatAmount.sats(card.balance!.satoshis.toInt()),
      };

  Widget _cardRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const Gap(12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _showHint(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.passphraseWalletHintTitle),
      content: Text(walletHint(context)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.loc.cancel),
        ),
      ],
    ),
  );

  String walletHint(BuildContext context) =>
      card.wallet.hint ?? context.loc.passphraseWalletNoHint;

  Future<void> _editHint(BuildContext context) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _PassphraseHintScreen(initialValue: card.wallet.hint),
      ),
    );
    if (value != null && context.mounted) {
      final updated = await context.read<PassphraseWalletCubit>().updateHint(
        card.wallet,
        value.isEmpty ? null : value,
      );
      if (!updated && context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          context.loc.passphraseWalletOpenError,
        );
      }
    }
  }

  Future<void> _forget(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.passphraseWalletForgetTitle),
        content: Text(context.loc.passphraseWalletForgetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.loc.passphraseWalletForget),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final forgotten = await context.read<PassphraseWalletCubit>().forget(
        card.wallet,
      );
      if (!forgotten && context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          context.loc.passphraseWalletOpenError,
        );
      }
    }
  }
}
