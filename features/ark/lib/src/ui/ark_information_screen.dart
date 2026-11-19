import 'package:ark/ark.dart';
import 'package:intl/intl.dart';
import 'package:bull_ui/bull_ui.dart';

import '../domain/ark_failure.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

class ArkInformationScreen extends StatelessWidget {
  final ArkSnapshot? snapshot;
  final ArkAccountConfig config;
  final bool loading;
  final ArkFailure? failure;
  final VoidCallback? onRetry;

  /// Connectivity belongs to the observed account and configured server.
  final (ArkAccountId, Uri, bool)? serverConnection;
  final (ArkAccountId, Uri, int)? serverExitDelta;

  const ArkInformationScreen({
    super.key,
    required this.snapshot,
    required this.config,
    this.loading = false,
    this.failure,
    this.onRetry,
    this.serverConnection,
    this.serverExitDelta,
  });

  String _short(String value) => value.length <= 22
      ? value
      : '${value.substring(0, 10)}…${value.substring(value.length - 8)}';

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      Padding(
        padding: const EdgeInsets.only(bottom: BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
                child: BullText(
                  title,
                  role: BullTextRole.label,
                  color: context.bull.textMuted,
                ),
              ),
            ),
            const Gap(BullSpacing.sm),
            BullDetailsTable(flat: true, dividerHeight: 1, items: rows),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final observed = switch (snapshot) {
      final value? when value.account == config.id => value,
      _ => null,
    };
    final cached = observed?.serverInfo;
    final info = cached?.serverUri == null || cached?.serverUri == config.arkUrl
        ? cached
        : null;
    final scopedInfo = info?.serverUri == config.arkUrl ? info : null;
    int? nonnegative(int? value) => value != null && value >= 0 ? value : null;
    final address = observed?.reserveAddress;
    final reserve = observed?.confirmedReserve;
    final connection = serverConnection;
    final online =
        connection != null &&
            connection.$1 == config.id &&
            connection.$2 == config.arkUrl
        ? connection.$3
        : null;
    final exitFact = serverExitDelta;
    final exitDelta =
        exitFact != null &&
            exitFact.$1 == config.id &&
            exitFact.$2 == config.arkUrl &&
            exitFact.$3 >= 0
        ? exitFact.$3
        : null;
    final error = failure;
    final retry = onRetry;
    String integer(int? value) => value == null
        ? l10n.unknown
        : NumberFormat.decimalPattern(
            Localizations.localeOf(context).toString(),
          ).format(value);
    String blocks(int? value) =>
        value == null ? l10n.unknown : l10n.inventoryBlocks(integer(value));
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullTopBar(
                title: l10n.arkInfo,
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loading && info == null) ...[
                      const Gap(BullSpacing.xxl),
                      BullText(
                        l10n.loading,
                        role: BullTextRole.body,
                        textAlign: TextAlign.center,
                      ),
                    ] else if (error != null && info == null) ...[
                      const Gap(BullSpacing.xxl),
                      BullIcon(
                        BullIcons.errorOutline,
                        size: 48,
                        color: context.bull.error,
                      ),
                      const Gap(BullSpacing.md),
                      BullText(
                        online == false
                            ? l10n.inventoryServerError
                            : l10n.unavailable,
                        role: BullTextRole.subtitle,
                        textAlign: TextAlign.center,
                      ),
                      BullText(
                        error.toTranslated(context),
                        role: BullTextRole.body,
                        textAlign: TextAlign.center,
                      ),
                      if (retry != null) ...[
                        const Gap(BullSpacing.lg),
                        BullButton.big(
                          label: l10n.retry,
                          onPressed: retry,
                          bgColor: context.bull.secondary,
                          textColor: context.bull.onSecondary,
                        ),
                      ],
                    ] else ...[
                      _section(context, l10n.arkServer, [
                        BullDetailsTableItem(
                          compact: true,
                          label: config.arkUrl.host,
                          displayValue: online == null
                              ? l10n.unknown
                              : online
                              ? l10n.inventoryOnline
                              : l10n.inventoryOffline,
                          displayWidget: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: BullSpacing.sm,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: online == null
                                      ? context.bull.textMuted
                                      : online
                                      ? context.bull.success
                                      : context.bull.error,
                                ),
                              ),
                              BullText(
                                online == null
                                    ? l10n.unknown
                                    : online
                                    ? l10n.inventoryOnline
                                    : l10n.inventoryOffline,
                                role: BullTextRole.body,
                                color: context.bull.textMuted,
                              ),
                            ],
                          ),
                          copyValue: config.arkUrl.toString(),
                          copiedMessage: l10n.copied,
                        ),
                      ]),
                      if (online == false && info != null)
                        BullInfoBar(message: l10n.inventoryCachedInfo),
                      if (observed?.stale == true)
                        BullInfoBar(message: l10n.stale),
                      _section(context, l10n.inventoryKeys, [
                        BullDetailsTableItem(
                          compact: true,
                          label: l10n.inventoryServerPublicKey,
                          displayValue: info == null
                              ? l10n.unknown
                              : _short(info.publicKey),
                          copyValue: info?.publicKey,
                          copiedMessage: l10n.copied,
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryMailboxKey,
                          displayValue: l10n.unknown,
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryRoundNonceCount,
                          displayValue:
                              nonnegative(scopedInfo?.roundNonceCount)
                                  ?.toString() ??
                              l10n.unknown,
                        ),
                      ]),
                      _section(context, l10n.inventoryBoardingLimits, [
                        BullDetailsTableItem(
                          compact: true,
                          label: l10n.inventoryMinimumBoard,
                          displayValue: formatArkObservedSats(
                            context,
                            info?.minimumBoard,
                          ),
                        ),
                        BullDetailsTableItem(
                          compact: true,
                          label: l10n.inventoryMaximumVtxo,
                          displayValue: formatArkObservedSats(
                            context,
                            info?.maximumVtxo,
                          ),
                        ),
                        BullDetailsTableItem(
                          compact: true,
                          label: l10n.inventoryConfirmations,
                          displayValue: integer(info?.boardConfirmations),
                        ),
                      ]),
                      _section(context, l10n.inventoryTiming, [
                        BullDetailsTableItem(
                          label: l10n.inventoryLifetime,
                          displayValue: blocks(info?.vtxoLifetimeBlocks),
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryRoundInterval,
                          displayValue: info?.roundIntervalSeconds == null
                              ? l10n.unknown
                              : l10n.inventorySeconds(
                                  integer(info?.roundIntervalSeconds),
                                ),
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryExitDelta,
                          displayValue: blocks(exitDelta),
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryHtlcSendExpiryDelta,
                          displayValue: blocks(
                            nonnegative(scopedInfo?.htlcSendExpiryDelta),
                          ),
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryHtlcExpiryDelta,
                          displayValue: blocks(
                            nonnegative(scopedInfo?.htlcExpiryDelta),
                          ),
                        ),
                        BullDetailsTableItem(
                          label: l10n.inventoryAutoRenew,
                          displayValue: blocks(config.renewalThresholdBlocks),
                        ),
                      ]),
                      if (address != null && address.trim().isNotEmpty)
                        Column(
                          key: const ValueKey('ark-fee-reserve'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BullText(
                              l10n.feeReserveTitle,
                              role: BullTextRole.subtitle,
                            ),
                            const Gap(BullSpacing.sm),
                            BullText(
                              !arkAmountsVisible(context)
                                  ? l10n.hiddenAmount
                                  : reserve == null
                                  ? l10n.unknown
                                  : l10n.feeReserveAmount(
                                      reserve.value.toString(),
                                    ),
                              role: BullTextRole.body,
                            ),
                            const Gap(BullSpacing.sm),
                            BullInfoBar(message: l10n.feeReserveHelp),
                            const Gap(BullSpacing.md),
                            Center(
                              child: BullQrCode(
                                data: address,
                                size: 200,
                                semanticsLabel: l10n.feeReserveTitle,
                              ),
                            ),
                            const Gap(BullSpacing.md),
                            BullCopyField(
                              text: address,
                              clipboardText: address,
                              copiedMessage: l10n.copied,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(BullSpacing.lg),
                          ],
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
  }
}
