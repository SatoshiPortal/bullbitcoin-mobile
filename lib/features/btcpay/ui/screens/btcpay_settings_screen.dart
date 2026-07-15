import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_failure_l10n.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_state.dart';
import 'package:bb_mobile/features/btcpay/ui/screens/btcpay_pairing_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BtcpaySettingsScreen extends StatefulWidget {
  const BtcpaySettingsScreen({super.key});

  @override
  State<BtcpaySettingsScreen> createState() => _BtcpaySettingsScreenState();
}

class _BtcpaySettingsScreenState extends State<BtcpaySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<BtcpayPairingCubit>().load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BtcpayPairingCubit, BtcpayPairingState>(
      listener: (context, state) {
        if (state.isFailure) {
          final failure = state.failure;
          if (failure != null) {
            SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
          }
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.isSubmitting && !state.isSuccess,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (state.isSuccess) {
              context.pop(true);
              return;
            }
            if (!state.isSubmitting) return;
            SnackBarUtils.showSnackBar(
              context,
              context.loc.btcpayPairingOperationInProgress,
            );
          },
          child: Scaffold(
            appBar: AppBar(title: Text(context.loc.btcpaySettingsTitle)),
            body: SafeArea(
              child: state.isSuccess
                  ? const _BtcpayPairingSuccessView()
                  : state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.shouldShowConnection
                  ? _BtcpayConnectionView(
                      connection: state.connection!,
                      walletBehaviors: state.walletBehaviors,
                      walletSettingsSaving: state.walletSettingsSaving,
                    )
                  : _BtcpayPairingForm(
                      formKey: _formKey,
                      urlController: _urlController,
                      isSubmitting: state.isSubmitting,
                      failureMessage: state.isFailure
                          ? state.failure?.toTranslated(context)
                          : null,
                      onSubmit: _submit,
                      onScan: _scanPairingCode,
                      onChanged: _clearPairingFailure,
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final pairingUrl = _urlController.text.trim();
    final preview = context.read<BtcpayPairingCubit>().preview(pairingUrl);
    if (preview == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(context.loc.btcpayPairingConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.btcpayPairingConfirmBody(
                _walletSummary(context),
                preview.serverUrl,
              ),
            ),
            const Gap(12),
            Text(
              _capabilitySummary(context, preview),
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.loc.btcpayPairingConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.loc.btcpayPairingConfirmSubmit,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<BtcpayPairingCubit>().submit(pairingUrl);
  }

  Future<void> _scanPairingCode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BtcpayPairingScannerScreen(),
      ),
    );
    if (scanned == null || !mounted) return;
    _urlController.text = scanned;
    _clearPairingFailure();
  }

  void _clearPairingFailure() {
    context.read<BtcpayPairingCubit>().clearPairingFailure();
  }

  String _capabilitySummary(
    BuildContext context,
    BtcpayPairingPreview preview,
  ) {
    final capabilities = <String>[
      if (preview.supportsBitcoinChain) context.loc.btcpayPairingRailBitcoin,
      if (preview.supportsLiquidChain) context.loc.btcpayPairingRailLiquid,
      if (preview.supportsLightning) context.loc.btcpayPairingRailLightning,
    ];
    return context.loc.btcpayPairingConfirmRails(capabilities.join(', '));
  }

  String _walletSummary(BuildContext context) {
    return context.loc.btcpayPairingWalletsBitcoinAndLiquid;
  }
}

class _BtcpayPairingForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController urlController;
  final bool isSubmitting;
  final String? failureMessage;
  final VoidCallback onSubmit;
  final VoidCallback onScan;
  final VoidCallback onChanged;

  const _BtcpayPairingForm({
    required this.formKey,
    required this.urlController,
    required this.isSubmitting,
    required this.failureMessage,
    required this.onSubmit,
    required this.onScan,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failureMessage != null) ...[
              _BtcpayPairingFailurePanel(message: failureMessage!),
              const Gap(16),
            ],
            TextFormField(
              controller: urlController,
              enabled: !isSubmitting,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 3,
              maxLines: 5,
              onFieldSubmitted: (_) => isSubmitting ? null : onSubmit(),
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: context.loc.btcpayPairingUrlLabel,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.loc.btcpayPairingUrlRequired;
                }
                return null;
              },
            ),
            const Gap(12),
            BBButton.big(
              label: context.loc.btcpayPairingScanQr,
              iconData: Icons.qr_code_scanner,
              iconFirst: true,
              onPressed: onScan,
              disabled: isSubmitting,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
            const Gap(24),
            BBButton.big(
              label: isSubmitting
                  ? context.loc.btcpayPairingSubmitting
                  : context.loc.btcpayPairingSubmit,
              onPressed: onSubmit,
              disabled: isSubmitting,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BtcpayPairingFailurePanel extends StatelessWidget {
  final String message;

  const _BtcpayPairingFailurePanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: context.font.bodyMedium),
      ),
    );
  }
}

class _BtcpayConnectionView extends StatelessWidget {
  final BtcpayConnectionViewModel connection;
  final List<BtcpayWalletBehaviorViewModel> walletBehaviors;
  final bool walletSettingsSaving;

  const _BtcpayConnectionView({
    required this.connection,
    required this.walletBehaviors,
    required this.walletSettingsSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(context.loc.btcpayConnectionTitle, style: context.font.titleLarge),
        const Gap(16),
        if (connection.isUncertain) ...[
          Text(
            context.loc.btcpayConnectionUncertainTitle,
            style: context.font.titleMedium,
          ),
          const Gap(4),
          Text(
            context.loc.btcpayConnectionUncertainBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(16),
        ],
        _BtcpayConnectionRow(
          label: context.loc.btcpayConnectionServer,
          value: connection.serverUrl,
        ),
        const Gap(12),
        _BtcpayConnectionRow(
          label: context.loc.btcpayConnectionStore,
          value: connection.storeId,
        ),
        const Gap(12),
        _BtcpayConnectionRow(
          label: context.loc.btcpayConnectionRails,
          value: _capabilities(context),
        ),
        const Gap(12),
        _BtcpayConnectionRow(
          label: context.loc.btcpayConnectionWallets,
          value: _wallets(context),
        ),
        const Gap(12),
        _BtcpayConnectionRow(
          label: connection.isPaired
              ? context.loc.btcpayConnectionPairedAt
              : context.loc.btcpayConnectionUpdatedAt,
          value: connection.displayDate.toLocal().toString().substring(0, 16),
        ),
        if (walletBehaviors.isNotEmpty) ...[
          const Gap(24),
          Text(
            context.loc.btcpayWalletSettingsTitle,
            style: context.font.titleMedium,
          ),
          const Gap(8),
          for (final behavior in walletBehaviors)
            _BtcpayWalletBehaviorTile(
              behavior: behavior,
              saving: walletSettingsSaving,
            ),
        ],
        const Gap(24),
        BBButton.big(
          label: context.loc.btcpayPairNew,
          onPressed: context.read<BtcpayPairingCubit>().pairNew,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  String _capabilities(BuildContext context) {
    final labels = [
      if (connection.rails.contains(BtcpayPairingRail.bitcoin))
        context.loc.btcpayPairingRailBitcoin,
      if (connection.rails.contains(BtcpayPairingRail.liquid))
        context.loc.btcpayPairingRailLiquid,
      if (connection.rails.contains(BtcpayPairingRail.lightning))
        context.loc.btcpayPairingRailLightning,
    ];
    return labels.join(', ');
  }

  String _wallets(BuildContext context) {
    final createsBitcoin = connection.wallets.contains(
      BtcpayPairingWallet.bitcoin,
    );
    final createsLiquid = connection.wallets.contains(
      BtcpayPairingWallet.liquid,
    );
    if (createsBitcoin && createsLiquid) {
      return context.loc.btcpayPairingWalletsBitcoinAndLiquid;
    }
    if (createsBitcoin) return context.loc.btcpayPairingWalletsBitcoin;
    return context.loc.btcpayPairingWalletsLiquid;
  }
}

class _BtcpayWalletBehaviorTile extends StatelessWidget {
  final BtcpayWalletBehaviorViewModel behavior;
  final bool saving;

  const _BtcpayWalletBehaviorTile({
    required this.behavior,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (behavior.wallet) {
      BtcpayPairingWallet.bitcoin => context.loc.btcpayPairingWalletsBitcoin,
      BtcpayPairingWallet.liquid => context.loc.btcpayPairingWalletsLiquid,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(title: Text(title)),
          SwitchListTile(
            value: behavior.hideOnHome,
            onChanged: saving
                ? null
                : (value) {
                    context.read<BtcpayPairingCubit>().updateWalletBehavior(
                      walletId: behavior.walletId,
                      hideOnHome: value,
                    );
                  },
            title: Text(context.loc.btcpayHideWalletOnHome),
          ),
          SwitchListTile(
            value: behavior.autoSweepEnabled,
            onChanged: saving
                ? null
                : (value) {
                    context.read<BtcpayPairingCubit>().updateWalletBehavior(
                      walletId: behavior.walletId,
                      autoSweepEnabled: value,
                    );
                  },
            title: Text(context.loc.btcpayAutoSweepWallet),
          ),
        ],
      ),
    );
  }
}

class _BtcpayConnectionRow extends StatelessWidget {
  final String label;
  final String value;

  const _BtcpayConnectionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Text(value, style: context.font.bodyMedium),
      ],
    );
  }
}

class _BtcpayPairingSuccessView extends StatelessWidget {
  const _BtcpayPairingSuccessView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.check_circle, color: context.appColors.success, size: 72),
          const Gap(24),
          Text(
            context.loc.btcpayPairingSuccessTitle,
            style: context.font.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            context.loc.btcpayPairingSuccess,
            style: context.font.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          BBButton.big(
            label: context.loc.doneButton,
            onPressed: () => context.pop(true),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ),
    );
  }
}
