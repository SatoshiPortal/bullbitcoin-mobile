import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';

/// Collects one foreground intent; the native quote revalidates all authority.
class ArkExitRequestScreen extends StatefulWidget {
  final ArkSnapshot snapshot;
  final List<String>? claimIds;
  final ValueChanged<ArkQuoteRequest> onReview;
  const ArkExitRequestScreen({
    super.key,
    required this.snapshot,
    required this.onReview,
    this.claimIds,
  });
  @override
  State<ArkExitRequestScreen> createState() => _ArkExitRequestScreenState();
}

class _ArkExitRequestScreenState extends State<ArkExitRequestScreen> {
  String _destination = '', _rate = '', _maximum = '';
  bool _consumed = false;
  int _revision = 0;

  BigInt? _positive(String raw, BigInt maximum) {
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return null;
    final value = BigInt.tryParse(raw);
    return value != null && value > BigInt.zero && value <= maximum
        ? value
        : null;
  }

  List<String> get _ids =>
      widget.claimIds ??
      [
        for (final vtxo in widget.snapshot.vtxos)
          if (vtxo.state == ArkVtxoState.spendable && !vtxo.pendingRound)
            vtxo.id,
      ];

  bool _current(ArkExitRequestScreen rendered, int revision) =>
      mounted &&
      !_consumed &&
      identical(rendered, widget) &&
      revision == _revision;

  ArkQuoteRequest? _request() {
    final snapshot = widget.snapshot;
    final ids = _ids;
    final maximum = _positive(_maximum, BigInt.from(2100000000000000));
    if (snapshot.stale ||
        snapshot.tipHeight == null ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        maximum == null ||
        _destination.trim().isEmpty) {
      return null;
    }
    if (widget.claimIds != null) {
      if (!ids.every(
        (id) =>
            snapshot.exitDetails
                .where(
                  (exit) =>
                      exit.id == id && exit.status == ArkExitStatus.claimable,
                )
                .length ==
            1,
      )) {
        return null;
      }
      return ArkQuoteRequest.claim(
        ids: ids,
        destination: _destination.trim(),
        maxFee: Sats(maximum),
      );
    }
    final rate = _positive(_rate, BigInt.from(9007199254740991));
    if (rate == null || !snapshot.vtxoInventoryComplete) {
      return null;
    }
    return ArkQuoteRequest.emergencyExit(
      ids: ids,
      destination: _destination.trim(),
      feeRate: FeeRate(rate.toDouble()),
      maxClaimFee: Sats(maximum),
    );
  }

  void _edit(ArkExitRequestScreen rendered, int revision, VoidCallback change) {
    if (_current(rendered, revision)) {
      setState(() {
        change();
        ++_revision;
      });
    }
  }

  void _review(ArkExitRequestScreen rendered, int revision) {
    if (!_current(rendered, revision)) return;
    final request = _request();
    if (request == null) return;
    setState(() => _consumed = true);
    rendered.onReview(request);
  }

  @override
  void didUpdateWidget(ArkExitRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.account != widget.snapshot.account) {
      _destination = _rate = _maximum = '';
      ++_revision;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final rendered = widget;
    final revision = _revision;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.exits,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(message: l10n.foregroundExit),
              if (widget.claimIds == null)
                BullInfoBar(message: l10n.exitProgressReviewWarning),
              for (final id in _ids) BullText(id, style: null),
              BullInputText(
                value: _destination,
                hint: l10n.claimDestination,
                disabled: _consumed,
                onChanged: (value) =>
                    _edit(rendered, revision, () => _destination = value),
              ),
              if (widget.claimIds == null)
                BullInputText(
                  value: _rate,
                  hint: l10n.exitProgressFeeRate,
                  digitsOnly: true,
                  onlyNumbers: true,
                  disabled: _consumed,
                  onChanged: (value) =>
                      _edit(rendered, revision, () => _rate = value),
                ),
              BullInputText(
                value: _maximum,
                hint: l10n.exitMaximumClaimFee,
                digitsOnly: true,
                onlyNumbers: true,
                disabled: _consumed,
                onChanged: (value) =>
                    _edit(rendered, revision, () => _maximum = value),
              ),
              BullButton.big(
                label: l10n.review,
                disabled: _consumed || _request() == null,
                onPressed: () => _review(rendered, revision),
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
