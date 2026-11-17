import 'dart:async';

import 'package:ark/ark.dart' show ArkDestinationKind, ArkAccountId;
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_receive_cubit.dart';
import '../presentation/ark_failure_l10n.dart';

/// A real host share handler is optional; absence stays visibly unavailable.
/// Host replaces the owner for full configuration/context changes.
class ArkReceiveScreen extends StatefulWidget {
  final ArkReceiveCubit cubit;
  final ValueChanged<String>? onShare;
  const ArkReceiveScreen({super.key, required this.cubit, this.onShare});
  @override
  State<ArkReceiveScreen> createState() => _ArkReceiveScreenState();
}

class _ArkReceiveScreenState extends State<ArkReceiveScreen> {
  String _amount = '';
  bool _lightning = false;
  late StreamSubscription<ArkReceiveState> _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ArkReceiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _subscription = widget.cubit.stream.listen((_) {
        if (mounted) setState(() {});
      });
      _amount = '';
      _lightning = false;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final ready = state is ArkReceiveReady ? state : null;
    final destination = ready?.destination;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.receive,
                onBack: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  Expanded(
                    child: _button(context, l10n.arkAddress, () {
                      widget.cubit.edit();
                      setState(() => _lightning = false);
                    }, selected: !_lightning),
                  ),
                  const Gap(BullSpacing.xs),
                  Expanded(
                    child: _button(context, l10n.lightningInvoice, () {
                      widget.cubit.edit();
                      setState(() => _lightning = true);
                    }, selected: _lightning),
                  ),
                ],
              ),
              const Gap(BullSpacing.md),
              if (_lightning)
                BullInputText(
                  value: _amount,
                  hint: l10n.amount,
                  digitsOnly: true,
                  onlyNumbers: true,
                  onChanged: (value) {
                    widget.cubit.edit();
                    setState(() => _amount = value);
                  },
                ),
              if (state case ArkReceiveEditing(:final failure?))
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              if (state is ArkReceiveLoading)
                BullText(l10n.loading, style: null),
              if (ready != null && destination != null) ...[
                BullQrCode(
                  data: destination.value,
                  size: 280,
                  semanticsLabel: _destinationLabel(context, destination.kind),
                  errorBuilder: (context) => BullInfoBar(
                    message: arkLocalizationsOf(context).unavailable,
                  ),
                ),
                const Gap(BullSpacing.md),
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: _destinationLabel(context, destination.kind),
                      displayValue: destination.value,
                      copyValue: destination.value,
                      copiedMessage: l10n.copied,
                    ),
                    if (destination.fee case final fee?)
                      BullDetailsTableItem(
                        label: l10n.feeInSats,
                        displayValue: fee.toString(),
                      ),
                    if (destination.net case final net?)
                      BullDetailsTableItem(
                        label: l10n.netInSats,
                        displayValue: net.toString(),
                      ),
                    if (destination.expiresAt case final expiry?)
                      BullDetailsTableItem(
                        label: l10n.invoiceExpires,
                        displayValue: expiry.toLocal().toString(),
                      ),
                  ],
                ),
                const Gap(BullSpacing.md),
                BullButton.big(
                  label: l10n.share,
                  onPressed: () => _share(owner, account, ready),
                  disabled: widget.onShare == null || !_shareable(ready),
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                ),
                if (widget.onShare == null)
                  BullInfoBar(message: l10n.nativeUnavailable),
                if (!_shareable(ready)) BullInfoBar(message: l10n.unknown),
              ],
              const Gap(BullSpacing.md),
              BullButton.big(
                label: l10n.generate,
                onPressed: () => widget.cubit.request(
                  lightning: _lightning,
                  amount: _amount,
                ),
                disabled: state is ArkReceiveLoading,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shareable(ArkReceiveReady ready) =>
      ready.destination.value.trim().isNotEmpty &&
      (ready.destination.kind == ArkDestinationKind.ark ||
          ready.destination.kind == ArkDestinationKind.bolt11);

  // Ready identity binds this intent to the currently published request epoch.
  void _share(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady rendered,
  ) {
    if (!mounted || owner.isClosed) return;
    if (!identical(widget.cubit, owner) || widget.cubit.account != account) {
      return;
    }
    final current = owner.state;
    if (current is! ArkReceiveReady ||
        !identical(current, rendered) ||
        !identical(current.destination, rendered.destination) ||
        current.destination.kind != rendered.destination.kind ||
        current.destination.value != rendered.destination.value ||
        !_shareable(rendered)) {
      return;
    }
    final callback = widget.onShare;
    if (callback == null) return;
    callback(rendered.destination.value);
  }

  String _destinationLabel(BuildContext context, ArkDestinationKind kind) {
    final l10n = arkLocalizationsOf(context);
    return switch (kind) {
      ArkDestinationKind.ark => l10n.arkAddress,
      ArkDestinationKind.bolt11 => l10n.lightningInvoice,
      ArkDestinationKind.bitcoin => l10n.unknown,
    };
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    required bool selected,
  }) => BullButton.small(
    label: label,
    onPressed: onPressed,
    bgColor: selected ? context.bull.primary : context.bull.surface,
    textColor: selected ? context.bull.onPrimary : context.bull.text,
    outlined: !selected,
  );
}
