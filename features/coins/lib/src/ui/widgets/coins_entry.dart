import 'dart:async';
import 'dart:ui' show Clip, Offset;

import 'package:flutter/painting.dart' show BoxShadow;

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

/// Bitcoin wallet entry. The host must not mount this for Liquid wallets.
/// [syncCompletions] emits when the host's wallet sync finishes; reading the
/// summary never starts a network sync.
class CoinsEntry extends StatefulWidget {
  const CoinsEntry({
    super.key,
    required this.walletId,
    required this.label,
    required this.loadCoinSummary,
    required this.syncCompletions,
    required this.onOpen,
  });

  final String walletId;
  final String label;
  final Future<Result<CoinSummary, CoinsFailure>> Function(String walletId)
  loadCoinSummary;
  final Stream<void> syncCompletions;
  final Future<void> Function(BuildContext context, String walletId) onOpen;

  @override
  State<CoinsEntry> createState() => _CoinsEntryState();
}

class _CoinsEntryState extends State<CoinsEntry> {
  CoinSummary? _summary;
  StreamSubscription<void>? _subscription;
  int _generation = 0;
  int _walletGeneration = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _reload();
  }

  void _subscribe() {
    _subscription = widget.syncCompletions.listen((_) => _reload());
  }

  @override
  void didUpdateWidget(covariant CoinsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncCompletions != widget.syncCompletions) {
      _subscription?.cancel();
      _subscribe();
    }
    if (oldWidget.walletId != widget.walletId) {
      _walletGeneration++;
      _summary = null;
      _reload();
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final result = await widget.loadCoinSummary(widget.walletId);
    if (result case Ok(:final value)
        when mounted && generation == _generation) {
      setState(() => _summary = value);
    }
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.bullShapes.card);
    final summary = _summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: context.appColors.scrim,
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: BullBorderedTile(
          backgroundColor: context.appColors.cardBackground,
          padding: EdgeInsets.zero,
          onTap: () async {
            final walletId = widget.walletId;
            final walletGeneration = _walletGeneration;
            await widget.onOpen(context, walletId);
            if (mounted && _walletGeneration == walletGeneration) _reload();
          },
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: radius),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: context.appColors.bitcoinOrange),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          BullIcon(
                            BullIcons.accountTree,
                            size: 24,
                            color: context.appColors.bitcoinOrange,
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BullText(
                                  widget.label,
                                  style: context.bullType.body
                                      .copyWith(fontWeight: FontWeight.w500)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (summary != null) ...[
                                  const Gap(2),
                                  CoinsEntrySubtitle(
                                    utxoCount: summary.count,
                                    frozenSat: summary.frozenSat,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          BullIcon(
                            BullIcons.chevronRight,
                            size: 22,
                            color: context.appColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
