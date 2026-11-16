import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_receive_cubit.dart';
import '../presentation/ark_failure_l10n.dart';

class ArkReceiveScreen extends StatefulWidget {
  final ArkReceiveCubit cubit;
  const ArkReceiveScreen({super.key, required this.cubit});
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
    final state = widget.cubit.state;
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
              if (state case ArkReceiveReady(:final destination)) ...[
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: _lightning
                          ? l10n.lightningInvoice
                          : l10n.arkAddress,
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
