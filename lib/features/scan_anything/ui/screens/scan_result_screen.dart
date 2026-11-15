import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/address_view/public/address_explorer_route.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/public/broadcast_signed_tx_route.dart';
import 'package:bb_mobile/features/buy/public/buy_route.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart'
    show ExchangeSessionBuilder;
import 'package:bb_mobile/features/import_mnemonic/public/import_mnemonic_route.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart'
    show
        ImportWatchOnlyWalletRoutes,
        SignerEntity,
        SignerExportOption,
        WatchOnlyWalletEntity;
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_route.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_failure_l10n.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_state.dart';
import 'package:bb_mobile/features/scan_anything/ui/scanned_content_l10n.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scan_action.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_cubit.dart';
import 'package:bb_mobile/features/send/public/send_route.dart';
import 'package:bb_mobile/features/swap/public/swap_route.dart';
import 'package:bb_mobile/features/wallet/public/wallet_route.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/transactions/public/transaction_explorer_route.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullBottomSheet, BullButton, BullSnackBar, BullText, BullTopBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.select(
      (ScanAnythingCubit cubit) => cubit.state.content,
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.scanAnythingTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: content == null
          ? const SizedBox.shrink()
          : BlocListener<ScanAnythingCubit, ScanAnythingState>(
              listenWhen: (previous, current) =>
                  previous.importedLabelCount != current.importedLabelCount ||
                  previous.failure != current.failure,
              listener: (context, state) {
                final count = state.importedLabelCount;
                final failure = state.failure;
                if (failure != null) {
                  BullSnackBar.show(
                    context,
                    message: failure.toTranslated(context),
                  );
                } else if (count != null) {
                  BullSnackBar.show(
                    context,
                    message: context.loc.scanAnythingLabelsImported(count),
                  );
                }
              },
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        children: [
                          _TypeHeader(content: content),
                          const Gap(24),
                          ..._summary(context, content),
                          if (content.actions.isNotEmpty) ...[
                            const Gap(24),
                            BullText(
                              context.loc.scanAnythingActionsTitle,
                              style: context.font.titleMedium,
                              color: context.appColors.onSurface,
                            ),
                            const Gap(8),
                            for (final action in content.actions)
                              _GatedActionTile(
                                action: action,
                                content: content,
                              ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: BullButton.big(
                        label: context.loc.scanAnythingScanAgain,
                        onPressed: () => context.pop(),
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _summary(BuildContext context, ScannedContent content) {
    final loc = context.loc;
    return switch (content) {
      BitcoinAddressContent(:final address, :final network) ||
      LiquidAddressContent(:final address, :final network) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(address)),
        _TextRow(
          label: loc.scanAnythingNetwork,
          value: _networkName(context, network),
        ),
      ],
      Bip21Content() => [
        _TextRow(
          label: loc.scanAnythingContent,
          value: _shorten(content.address),
        ),
        _TextRow(
          label: loc.scanAnythingNetwork,
          value: _networkName(context, content.network),
        ),
        if (content.amountSat case final amountSat?)
          _AmountRow(amountSat: amountSat),
        if (content.label.isNotEmpty)
          _TextRow(label: loc.scanAnythingLabel, value: content.label),
        if (content.hasLightning)
          _NoteRow(text: loc.scanAnythingIncludesLightning),
        if (content.hasPayjoin) _NoteRow(text: loc.scanAnythingIncludesPayjoin),
      ],
      LightningInvoiceContent() => [
        _TextRow(
          label: loc.scanAnythingContent,
          value: _shorten(content.invoice),
        ),
        if (content.isTestnet)
          _TextRow(label: loc.scanAnythingNetwork, value: loc.electrumTestnet),
        _AmountRow(amountSat: content.amountSat),
        if (content.isExpired) _NoteRow(text: loc.scanAnythingInvoiceExpired),
        if (content.description.isNotEmpty)
          _TextRow(
            label: loc.scanAnythingDescription,
            value: content.description,
          ),
        if (content.expiresAt case final expiresAt?)
          _TextRow(
            label: loc.scanAnythingExpiry,
            value: MaterialLocalizations.of(
              context,
            ).formatMediumDate(expiresAt),
          ),
      ],
      LightningAddressContent(:final address) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(address)),
      ],
      DescriptorContent(:final wallet, :final existingWallet) ||
      XpubContent(:final wallet, :final existingWallet) => [
        _TextRow(
          label: loc.scanAnythingContent,
          value: _shorten(wallet.pubkey),
        ),
        _TextRow(
          label: loc.scanAnythingNetwork,
          value: _networkName(context, wallet.network),
        ),
        if (existingWallet != null)
          _NoteRow(
            text: loc.scanAnythingAlreadyImported(
              existingWallet.displayLabel(context),
            ),
          ),
      ],
      PsbtContent(:final psbt) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(psbt)),
      ],
      SignedTransactionContent(:final hex) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(hex)),
      ],
      TransactionIdContent(:final txid) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(txid)),
        _NoteRow(text: loc.scanAnythingTxidHint),
      ],
      SignerExportContent(:final options, :final existingWallet) => [
        _TextRow(
          label: loc.scanAnythingDerivations,
          value: options
              .map((option) => _derivationName(context, option.derivation))
              .join(', '),
        ),
        if (existingWallet != null)
          _NoteRow(
            text: loc.scanAnythingAlreadyImported(
              existingWallet.displayLabel(context),
            ),
          ),
      ],
      SilentPaymentAddressContent(:final address, :final network) => [
        _TextRow(label: loc.scanAnythingContent, value: _shorten(address)),
        _TextRow(
          label: loc.scanAnythingNetwork,
          value: _networkName(context, network),
        ),
      ],
      ElectrumServerContent() => [
        _TextRow(
          label: loc.scanAnythingContent,
          value: '${content.host}:${content.port}',
        ),
        _TextRow(
          label: loc.scanAnythingConnection,
          value: content.useSsl
              ? loc.scanAnythingConnectionSsl
              : loc.scanAnythingConnectionTcp,
        ),
      ],
      LabelsExportContent(:final count) => [
        _TextRow(label: loc.scanAnythingLabelCount, value: count.toString()),
      ],
      RecoveryPhraseContent() => [
        _Warning(text: loc.scanAnythingRecoveryPhraseWarning),
      ],
      PrivateKeyContent() => [
        _Warning(text: loc.scanAnythingPrivateKeyWarning),
      ],
    };
  }
}

class _TypeHeader extends StatelessWidget {
  final ScannedContent content;

  const _TypeHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    final (icon, name) = scannedContentType(context, content);

    return Row(
      children: [
        Icon(icon, size: 32, color: context.appColors.secondary),
        const Gap(12),
        Expanded(
          child: BullText(
            name,
            style: context.font.headlineSmall,
            color: context.appColors.onSurface,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _TextRow extends StatelessWidget {
  final String label;
  final String value;

  const _TextRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BullText(
            label,
            style: context.font.bodyMedium,
            color: context.appColors.onSurfaceVariant,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              value,
              textAlign: .end,
              maxLines: 3,
              overflow: .ellipsis,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final int amountSat;

  const _AmountRow({required this.amountSat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          BullText(
            context.loc.sendAmount,
            style: context.font.bodyMedium,
            color: context.appColors.onSurfaceVariant,
          ),
          const Gap(12),
          Expanded(
            child: Align(
              alignment: .centerRight,
              child: CurrencyText(
                amountSat,
                showFiat: false,
                style: context.font.bodyMedium,
                color: context.appColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String text;

  const _NoteRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: BullText(
        text,
        style: context.font.bodySmall,
        color: context.appColors.onSurfaceVariant,
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;

  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        Icon(Icons.warning_amber_outlined, color: context.appColors.error),
        const Gap(12),
        Expanded(
          child: Text(
            text,
            style: context.font.titleMedium?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _GatedActionTile extends StatelessWidget {
  final ScanAction action;
  final ScannedContent content;

  const _GatedActionTile({required this.action, required this.content});

  @override
  Widget build(BuildContext context) {
    final tile = _ActionTile(action: action, content: content);
    if (!action.requiresExchangeSession) return tile;
    return ExchangeSessionBuilder(
      builder: (context, isLoggedIn) =>
          isLoggedIn ? tile : const SizedBox.shrink(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final ScanAction action;
  final ScannedContent content;

  const _ActionTile({required this.action, required this.content});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final (IconData icon, String title, String subtitle) = switch (action) {
      ScanAction.send => (
        Icons.arrow_upward,
        loc.scanAnythingActionSend,
        loc.scanAnythingActionSendSubtitle,
      ),
      ScanAction.exploreAddress => (
        Icons.search,
        loc.scanAnythingActionExploreAddress,
        loc.scanAnythingActionExploreAddressSubtitle,
      ),
      ScanAction.buyToAddress => (
        Icons.shopping_cart_outlined,
        loc.scanAnythingActionBuy,
        loc.scanAnythingActionBuySubtitle,
      ),
      ScanAction.importWatchOnly => (
        Icons.visibility_outlined,
        loc.scanAnythingActionImportWatchOnly,
        loc.scanAnythingActionImportWatchOnlySubtitle,
      ),
      ScanAction.importRemoteSigner => (
        Icons.usb_outlined,
        loc.scanAnythingActionImportRemoteSigner,
        loc.scanAnythingActionImportRemoteSignerSubtitle,
      ),
      ScanAction.reviewAndBroadcast => (
        Icons.cell_tower,
        loc.scanAnythingActionBroadcast,
        loc.scanAnythingActionBroadcastSubtitle,
      ),
      ScanAction.exploreTransaction => (
        Icons.receipt_long_outlined,
        loc.scanAnythingActionExploreTransaction,
        loc.scanAnythingActionExploreTransactionSubtitle,
      ),
      ScanAction.importRecoveryPhrase => (
        Icons.download_outlined,
        loc.scanAnythingActionImportRecoveryPhrase,
        loc.scanAnythingActionImportRecoveryPhraseSubtitle,
      ),
      ScanAction.swapToAddress => (
        Icons.swap_horiz,
        loc.scanAnythingActionSwap,
        loc.scanAnythingActionSwapSubtitle,
      ),
      ScanAction.openWallet => (
        Icons.account_balance_wallet_outlined,
        loc.scanAnythingActionOpenWallet,
        loc.scanAnythingActionOpenWalletSubtitle,
      ),
      ScanAction.addElectrumServer => (
        Icons.dns_outlined,
        loc.scanAnythingActionAddElectrumServer,
        loc.scanAnythingActionAddElectrumServerSubtitle,
      ),
      ScanAction.importLabels => (
        Icons.label_outline,
        loc.scanAnythingActionImportLabels,
        loc.scanAnythingActionImportLabelsSubtitle,
      ),
      ScanAction.copy => (
        Icons.copy,
        loc.scanAnythingActionCopy,
        loc.scanAnythingActionCopySubtitle,
      ),
    };

    return InkWell(
      onTap: () => _run(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: context.appColors.secondary),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BullText(
                    title,
                    style: context.font.bodyLarge,
                    color: context.appColors.onSurface,
                  ),
                  const Gap(2),
                  BullText(
                    subtitle,
                    style: context.font.bodySmall,
                    color: context.appColors.onSurfaceVariant,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    final content = this.content;
    final text = content.copyText;
    switch (action) {
      case ScanAction.send:
        if (text == null) return;
        await context.pushNamed(
          SendRoute.send.name,
          extra: content is SilentPaymentAddressContent
              ? SendRouteArgs.spPrefilled(text)
              : SendRouteArgs.prefilled(text),
        );
      case ScanAction.exploreAddress:
        final args = switch (content) {
          BitcoinAddressContent(:final address, :final network) ||
          Bip21Content(
            :final address,
            :final network,
          ) => AddressExplorerArgs(address: address, network: network),
          _ => null,
        };
        if (args == null) return;
        await context.pushNamed(
          AddressExplorerRoute.addressExplorer.name,
          extra: args,
        );
      case ScanAction.buyToAddress:
        if (content is! BitcoinAddressContent) return;
        await context.pushNamed(
          BuyRoute.buy.name,
          extra: BuyRouteArgs(externalAddress: content.address),
        );
      case ScanAction.importWatchOnly:
        await _import(context, SignerEntity.none);
      case ScanAction.importRemoteSigner:
        await _import(context, SignerEntity.remote);
      case ScanAction.swapToAddress:
        final args = switch (content) {
          BitcoinAddressContent(:final address) => SwapRouteArgs(
            externalAddress: address,
            isLiquidAddress: false,
          ),
          LiquidAddressContent(:final address) => SwapRouteArgs(
            externalAddress: address,
            isLiquidAddress: true,
          ),
          _ => null,
        };
        if (args == null) return;
        await context.pushNamed(SwapRoute.swap.name, extra: args);
      case ScanAction.openWallet:
        final existing = switch (content) {
          DescriptorContent(:final existingWallet) ||
          XpubContent(:final existingWallet) ||
          SignerExportContent(:final existingWallet) => existingWallet,
          _ => null,
        };
        if (existing == null) return;
        await context.pushNamed(
          WalletRoute.walletDetail.name,
          pathParameters: {'walletId': existing.id},
        );
      case ScanAction.addElectrumServer:
        if (content is! ElectrumServerContent) return;
        await context.pushNamed(
          ElectrumSettingsRoute.electrumSettings.name,
          extra: ElectrumSettingsArgs(prefilledServer: content.serverInput),
        );
      case ScanAction.importLabels:
        await context.read<ScanAnythingCubit>().importLabels();
      case ScanAction.reviewAndBroadcast:
        if (text == null) return;
        await context.pushNamed(
          BroadcastSignedTxRoute.broadcastHome.name,
          extra: BroadcastSignedTxArgs.signed(text),
        );
      case ScanAction.exploreTransaction:
        if (content is! TransactionIdContent) return;
        await context.pushNamed(
          TransactionExplorerRoute.transactionExplorer.name,
          extra: TransactionExplorerArgs(txid: content.txid),
        );
      case ScanAction.importRecoveryPhrase:
        await context.pushNamed(ImportMnemonicRoute.importMnemonicHome.name);
      case ScanAction.copy:
        if (text == null) return;
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        BullSnackBar.show(context, message: context.loc.copiedToClipboard);
    }
  }

  Future<void> _import(BuildContext context, SignerEntity signer) async {
    final content = this.content;
    final WatchOnlyWalletEntity? wallet = switch (content) {
      DescriptorContent(:final wallet) || XpubContent(:final wallet) => wallet,
      SignerExportContent(:final options) => await _chooseDerivation(
        context,
        options,
      ),
      _ => null,
    };
    if (wallet == null || !context.mounted) return;
    await context.pushNamed(
      ImportWatchOnlyWalletRoutes.import.name,
      extra: wallet.copyWith(signer: signer),
    );
  }
}

Future<WatchOnlyWalletEntity?> _chooseDerivation(
  BuildContext context,
  List<SignerExportOption> options,
) => BullBottomSheet.show<WatchOnlyWalletEntity>(
  context: context,
  child: SafeArea(
    child: Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: BullText(
            context.loc.importWatchOnlySelectDerivation,
            style: context.font.titleMedium,
            color: context.appColors.onSurface,
          ),
        ),
        for (final option in options)
          ListTile(
            title: Text(_derivationName(context, option.derivation)),
            onTap: () => Navigator.of(context).pop(option.wallet),
          ),
        const Gap(8),
      ],
    ),
  ),
);

String _derivationName(BuildContext context, String derivation) =>
    switch (derivation) {
      'bip84' => context.loc.scanAnythingDerivationBip84,
      'bip49' => context.loc.scanAnythingDerivationBip49,
      'bip44' => context.loc.scanAnythingDerivationBip44,
      _ => derivation,
    };

String _shorten(String value) => shortenScannedValue(value);

String _networkName(BuildContext context, Network network) => switch (network) {
  Network.bitcoinMainnet => context.loc.addressExplorerNetworkBitcoinMainnet,
  Network.bitcoinTestnet => context.loc.addressExplorerNetworkBitcoinTestnet,
  Network.bitcoinRegtest => context.loc.addressExplorerNetworkBitcoinRegtest,
  Network.liquidMainnet => context.loc.mempoolNetworkLiquidMainnet,
  Network.liquidTestnet => context.loc.mempoolNetworkLiquidTestnet,
  Network.liquidRegtest => context.loc.addressExplorerNetworkLiquid,
};
