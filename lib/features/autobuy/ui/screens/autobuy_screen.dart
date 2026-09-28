import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_failure_l10n.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullButton,
        BullInfoCard,
        BullSnackBar,
        BullSpacing,
        Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AutoBuyScreen extends StatelessWidget {
  final DefaultWalletsFacade defaultWalletsFacade;

  const AutoBuyScreen({required this.defaultWalletsFacade, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AutoBuyCubit, AutoBuyState>(
      listenWhen: (previous, current) =>
          (!previous.statusChangeSucceeded &&
              current.statusChangeSucceeded &&
              current.isActive) ||
          (previous.failure == null && current.failure != null),
      listener: (context, state) {
        if (state.statusChangeSucceeded && state.isActive) {
          context.pop();
        } else if (state.step != AutoBuyStep.intro && state.failure != null) {
          BullSnackBar.show(
            context,
            message: state.failure!.toTranslated(context),
          );
        }
      },
      child: BlocBuilder<AutoBuyCubit, AutoBuyState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_titleFor(context, state.step)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBack(context, state.step),
              ),
            ),
            body: switch (state.step) {
              AutoBuyStep.intro when state.isLoadingStatus => const Center(
                child: CircularProgressIndicator(),
              ),
              AutoBuyStep.intro when state.failure != null =>
                _StatusLoadFailure(
                  message: state.failure!.toTranslated(context),
                  onRetry: context.read<AutoBuyCubit>().loadStatus,
                ),
              AutoBuyStep.intro => _IntroStep(isRestricted: state.isRestricted),
              AutoBuyStep.wallets => defaultWalletsFacade.buildEditor(
                footerBuilder: (context, wallets, status) => BullButton.big(
                  label: context.loc.continueButton,
                  disabled:
                      !wallets.hasAnyWallet ||
                      status.isEditing ||
                      status.isSaving,
                  onPressed: () =>
                      context.read<AutoBuyCubit>().showConfirmation(wallets),
                  bgColor: context.appColors.onSurface,
                  textColor: context.appColors.surface,
                ),
              ),
              AutoBuyStep.confirm => const _ConfirmStep(),
            },
          );
        },
      ),
    );
  }

  String _titleFor(BuildContext context, AutoBuyStep step) => switch (step) {
    AutoBuyStep.intro => context.loc.autoBuyTitle,
    AutoBuyStep.wallets => context.loc.exchangeBitcoinWalletsTitle,
    AutoBuyStep.confirm => context.loc.autoBuyConfirmTitle,
  };

  void _goBack(BuildContext context, AutoBuyStep step) {
    final cubit = context.read<AutoBuyCubit>();
    switch (step) {
      case AutoBuyStep.intro:
        context.pop();
      case AutoBuyStep.wallets:
        cubit.showIntro();
      case AutoBuyStep.confirm:
        cubit.showWallets();
    }
  }
}

class _StatusLoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatusLoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const Gap(BullSpacing.md),
            BullButton.small(
              label: context.loc.retry,
              onPressed: onRetry,
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  final bool isRestricted;

  const _IntroStep({required this.isRestricted});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.loc.autoBuyDescription, style: context.font.bodyLarge),
            const Gap(BullSpacing.md),
            BullBorderedTile(
              padding: const EdgeInsets.all(BullSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.autoBuyHowItWorks,
                    style: context.font.titleMedium,
                  ),
                  const Gap(BullSpacing.sm),
                  _Bullet(text: context.loc.autoBuyConnectWallet),
                  const Gap(BullSpacing.xs),
                  _Bullet(text: context.loc.autoBuyPurchaseCreated),
                  const Gap(BullSpacing.xs),
                  _Bullet(text: context.loc.autoBuyBitcoinSent),
                ],
              ),
            ),
            const Gap(BullSpacing.md),
            Text(
              context.loc.autoBuyRiskDisclaimer,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(BullSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                link: true,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(SettingsConstants.exchangeTermsAndConditionsLink),
                    mode: LaunchMode.inAppBrowserView,
                  ),
                  child: Text(
                    context.loc.settingsTermsOfServiceTitle,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: context.appColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(BullSpacing.lg),
            if (isRestricted)
              BullInfoCard(
                title: context.loc.fundExchangeRestrictedTitle,
                description: context.loc.fundExchangeRestrictedMessage,
                bgColor: context.appColors.error.withValues(alpha: 0.1),
                tagColor: context.appColors.error,
              )
            else
              BullButton.big(
                label: context.loc.autoBuyGetStarted,
                onPressed: () => context.read<AutoBuyCubit>().showWallets(),
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: context.font.bodyMedium),
        const Gap(BullSpacing.xs),
        Expanded(child: Text(text, style: context.font.bodyMedium)),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AutoBuyCubit>().state;
    final wallets = state.wallets;

    if (wallets == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.autoBuyInfoMessage,
              style: context.font.bodyMedium,
            ),
            const Gap(BullSpacing.lg),
            if (wallets.bitcoinAddress.isNotEmpty)
              _WalletRow(
                label: context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
                address: wallets.bitcoinAddress,
              ),
            if (wallets.lightningAddress.isNotEmpty)
              _WalletRow(
                label: context.loc.exchangeBitcoinWalletsLightningAddressLabel,
                address: wallets.lightningAddress,
              ),
            if (wallets.liquidAddress.isNotEmpty)
              _WalletRow(
                label: context.loc.exchangeBitcoinWalletsLiquidAddressLabel,
                address: wallets.liquidAddress,
              ),
            const Gap(BullSpacing.lg),
            if (state.isSaving)
              const Center(child: CircularProgressIndicator())
            else if (!state.isActive)
              BullButton.big(
                label: context.loc.autoBuyActivate,
                onPressed: () => context.read<AutoBuyCubit>().setEnabled(true),
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  final String label;
  final String address;

  const _WalletRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Gap(BullSpacing.xs),
        Text(label, style: context.font.labelMedium),
        const Gap(BullSpacing.xs),
        AddressViewer(
          address,
          style: context.font.bodyMedium,
          color: context.appColors.onSurface,
        ),
        const Gap(BullSpacing.xs),
      ],
    );
  }
}
