import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';
import 'ark_connection_details.dart';

/// Input handoff only; no source wallet, fee estimate or funding authority.
class ArkBoardAmountScreen extends StatefulWidget {
  final ArkAccountConfig config;
  final void Function(ArkAccountConfig config, Sats amount)? onReviewRequest;
  const ArkBoardAmountScreen({
    super.key,
    required this.config,
    this.onReviewRequest,
  });
  @override
  State<ArkBoardAmountScreen> createState() => _ArkBoardAmountScreenState();
}

class _ArkBoardAmountScreenState extends State<ArkBoardAmountScreen> {
  String _amount = '';
  int _epoch = 0;
  Object? _inputToken;
  bool _consumed = false;

  Object _binding(ArkAccountConfig c) => (
    c.id,
    c.arkUrl,
    c.primaryEsploraUrl,
    c.fallbackEsploraUrl,
    c.renewalThresholdBlocks,
  );
  bool _current(ArkBoardAmountScreen rendered, int epoch) =>
      mounted &&
      !_consumed &&
      epoch == _epoch &&
      _binding(rendered.config) == _binding(widget.config) &&
      identical(rendered.onReviewRequest, widget.onReviewRequest);

  Sats? _parse(String raw) {
    if (raw.isEmpty || raw.codeUnits.any((unit) => unit < 48 || unit > 57)) {
      return null;
    }
    final value = BigInt.tryParse(raw);
    if (value == null ||
        value <= BigInt.zero ||
        value > BigInt.from(2100000000000000)) {
      return null;
    }
    return Sats(value);
  }

  @override
  void didUpdateWidget(ArkBoardAmountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedConfig = _binding(oldWidget.config) != _binding(widget.config);
    if (changedConfig ||
        !identical(oldWidget.onReviewRequest, widget.onReviewRequest)) {
      ++_epoch;
      _inputToken = null;
      if (changedConfig) _amount = '';
      // Never clear consumption: replacement is not evidence of no effect.
    }
  }

  @override
  void dispose() {
    _inputToken = null;
    super.dispose();
  }

  void _edit(ArkBoardAmountScreen rendered, Object token, String value) {
    if (!identical(token, _inputToken) || !_current(rendered, _epoch)) return;
    setState(() {
      ++_epoch;
      _amount = value;
    });
  }

  void _review(ArkBoardAmountScreen rendered, int epoch, String raw) {
    if (!_current(rendered, epoch) || _amount != raw) return;
    final delegate = rendered.onReviewRequest;
    final amount = _parse(raw);
    if (delegate == null || amount == null) return;
    setState(() => _consumed = true);
    _inputToken = null;
    delegate(rendered.config, amount); // A throw is not permission to retry.
  }

  @override
  Widget build(BuildContext context) {
    final token = Object();
    _inputToken = token;
    final rendered = widget;
    final epoch = _epoch;
    final raw = _amount;
    final l10n = arkLocalizationsOf(context);
    final id = rendered.config.id;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.board,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(
                message: l10n.boardDestination(
                  '${id.parent.hex}/${id.network.name}/${id.serverIdentity}',
                ),
              ),
              ArkConnectionDetails(config: rendered.config),
              BullInfoBar(message: l10n.boardFastPolicy),
              BullInfoBar(message: l10n.boardFeeReview),
              const Gap(BullSpacing.md),
              BullInputText(
                value: raw,
                hint: l10n.amount,
                digitsOnly: true,
                onlyNumbers: true,
                disabled: _consumed,
                onChanged: (value) => _edit(rendered, token, value),
              ),
              if (raw.isNotEmpty && _parse(raw) == null)
                BullInfoBar(message: l10n.boardAmountInvalid),
              if (rendered.onReviewRequest == null)
                BullInfoBar(message: l10n.nativeUnavailable),
              BullButton.big(
                label: l10n.review,
                disabled:
                    _consumed ||
                    rendered.onReviewRequest == null ||
                    _parse(raw) == null,
                onPressed: () => _review(rendered, epoch, raw),
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
