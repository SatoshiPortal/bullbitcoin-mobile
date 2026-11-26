import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';
import 'ark_amount.dart';

/// Roughly one bitcoin block every ten minutes.
const _blocksPerDay = 144;

class ArkInformationScreen extends StatelessWidget {
  final ArkSnapshot snapshot;
  final ArkAccountConfig config;

  const ArkInformationScreen({
    super.key,
    required this.snapshot,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final info = snapshot.serverInfo;
    String sats(Sats? amount) =>
        amount == null ? l10n.unknown : formatArkSats(context, amount);
    String blocks(int? count) {
      if (count == null) return l10n.unknown;
      final days = (count / _blocksPerDay).round();
      if (days < 1) return l10n.infoBlocks(count);
      return l10n.infoBlocksDays(_grouped(context, count), days);
    }

    String seconds(int? value) {
      if (value == null) return l10n.unknown;
      if (value < 60 || value % 60 != 0) {
        return l10n.infoSeconds(_grouped(context, value));
      }
      return l10n.infoSecondsMinutes(
        _grouped(context, value),
        _grouped(context, value ~/ 60),
      );
    }

    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullTopBar(
              title: l10n.arkInfo,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  BullSpacing.md,
                  BullSpacing.zero,
                  BullSpacing.md,
                  BullSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: l10n.infoServerSection,
                      items: [
                        BullDetailsTableItem(
                          label: l10n.arkServer,
                          displayValue: config.arkUrl.host,
                          copyValue: config.arkUrl.toString(),
                          copiedMessage: l10n.copied,
                        ),
                      ],
                    ),
                    // Not in the design: the chain providers carry the same
                    // privacy exposure as the Ark server, so they stay visible.
                    _Section(
                      title: l10n.infoChainSection,
                      footer: l10n.privacy,
                      items: [
                        BullDetailsTableItem(
                          label: l10n.primaryChainSource,
                          displayValue: config.primaryEsploraUrl.host,
                          copyValue: config.primaryEsploraUrl.toString(),
                          copiedMessage: l10n.copied,
                        ),
                        if (config.fallbackEsploraUrl case final fallback?)
                          BullDetailsTableItem(
                            label: l10n.fallbackChainSource,
                            displayValue: fallback.host,
                            copyValue: fallback.toString(),
                            copiedMessage: l10n.copied,
                          ),
                      ],
                    ),
                    _Section(
                      title: l10n.infoKeysSection,
                      items: [
                        BullDetailsTableItem(
                          label: l10n.infoServerPublicKey,
                          displayValue: info == null
                              ? l10n.unknown
                              : _shortKey(info.publicKey),
                          copyValue: info?.publicKey,
                          copiedMessage: l10n.copied,
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.infoLimitsSection,
                      items: [
                        BullDetailsTableItem(
                          label: l10n.infoMinimumBoard,
                          displayValue: sats(info?.minimumBoard),
                        ),
                        BullDetailsTableItem(
                          label: l10n.infoMaximumVtxo,
                          displayValue: switch (info) {
                            null => l10n.unknown,
                            ArkServerInfo(maximumVtxo: final maximum?) =>
                              formatArkSats(context, maximum),
                            ArkServerInfo() => l10n.infoNoLimit,
                          },
                        ),
                        BullDetailsTableItem(
                          label: l10n.infoRequiredConfirmations,
                          displayValue:
                              info?.boardConfirmations?.toString() ??
                              l10n.unknown,
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.infoTimingSection,
                      items: [
                        BullDetailsTableItem(
                          label: l10n.infoVtxoLifetime,
                          displayValue: blocks(info?.vtxoLifetimeBlocks),
                        ),
                        BullDetailsTableItem(
                          label: l10n.infoRoundInterval,
                          displayValue: seconds(info?.roundIntervalSeconds),
                        ),
                        BullDetailsTableItem(
                          label: l10n.infoAutoRenew,
                          displayValue: blocks(config.renewalThresholdBlocks),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.md),
                    BullText(
                      l10n.backgroundNotice,
                      role: BullTextRole.caption,
                      color: context.bull.textMuted,
                    ),
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

String _shortKey(String key) => key.length <= 16
    ? key
    : '${key.substring(0, 6)}…${key.substring(key.length - 6)}';

String _grouped(BuildContext context, int value) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
        .format(value);

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BullSpacing.md,
      BullSpacing.md,
      BullSpacing.md,
      BullSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: BullText(
        title.toUpperCase(),
        role: BullTextRole.label,
        color: context.bull.textMuted,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final String? footer;

  const _Section({required this.title, required this.items, this.footer});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionTitle(title),
      BullDetailsTable(items: items),
      if (footer case final text?)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.md,
            BullSpacing.xs,
            BullSpacing.md,
            BullSpacing.zero,
          ),
          child: BullText(
            text,
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
        ),
    ],
  );
}
