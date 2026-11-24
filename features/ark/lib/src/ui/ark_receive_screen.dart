import 'dart:async';

import 'package:ark/ark.dart' show ArkDestinationKind;
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Sats;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../domain/ark_display_data_port.dart';
import 'ark_amount.dart';
import 'ark_review.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_receive_cubit.dart';
import '../presentation/ark_failure_l10n.dart';

/// The host replaces the owner for full configuration/context changes.
class ArkReceiveScreen extends StatefulWidget {
  final ArkReceiveCubit cubit;
  final ArkDisplayData? displayData;
  const ArkReceiveScreen({super.key, required this.cubit, this.displayData});
  @override
  State<ArkReceiveScreen> createState() => _ArkReceiveScreenState();
}

class _ArkReceiveScreenState extends State<ArkReceiveScreen> {
  String _amount = '';
  bool _lightning = false;

  /// The invoice amount in sats, as the app's Lightning receive takes it.
  final _amountController = TextEditingController();
  late StreamSubscription<ArkReceiveState> _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
    // Like the app's Receive: the address is there when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAddress());
  }

  void _requestAddress() {
    if (!mounted || _lightning || widget.cubit.state is ArkReceiveReady) {
      return;
    }
    unawaited(widget.cubit.request(lightning: false, amount: ''));
  }

  void _select(bool lightning) {
    if (lightning == _lightning) return;
    widget.cubit.edit();
    setState(() => _lightning = lightning);
    if (!lightning) _requestAddress();
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
      _amountController.clear();
      _lightning = false;
      // A new account shows its own address, as when the screen opens.
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestAddress());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final ready = state is ArkReceiveReady ? state : null;
    final destination = ready?.destination;
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.sm,
              ),
              child: BullTopBar(
                title: l10n.receive,
                titleWidget: BullText(
                  l10n.receive,
                  role: BullTextRole.subtitle,
                ),
                onBack: () => Navigator.pop(context),
              ),
            ),
            // The app's network switch, here Ark or Lightning.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullSegmented(
                items: {l10n.receiveTabArk, l10n.receiveTabLightning},
                initialValue: _lightning
                    ? l10n.receiveTabLightning
                    : l10n.receiveTabArk,
                onSelected: (label) =>
                    _select(label == l10n.receiveTabLightning),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  BullSpacing.md,
                  BullSpacing.lg,
                  BullSpacing.md,
                  BullSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // An invoice needs its amount first.
                    if (_lightning && destination == null) ...[
                      // The app's Lightning amount: its label, then the
                      // framed amount input with its fiat equivalent.
                      Text(l10n.amountLabel, style: context.bullType.body),
                      const Gap(6),
                      BullAmountInput(
                        canonicalUnit: BitcoinUnit.sats,
                        amountController: _amountController,
                        framed: true,
                        readOnly: state is ArkReceiveLoading,
                        amountEquivalent: switch (BigInt.tryParse(_amount)) {
                          final sats? when !sats.isNegative =>
                            switch (arkFiatText(
                              context,
                              Sats(sats),
                              widget.displayData?.account == account
                                  ? widget.displayData?.price
                                  : null,
                            )) {
                              final fiat? => '~$fiat',
                              null => '',
                            },
                          _ => '',
                        },
                        onEntryChanged: (entry) {
                          final text = entry.sats?.toString() ?? '';
                          if (text == _amount) return;
                          widget.cubit.edit();
                          setState(() => _amount = text);
                        },
                      ),
                      const Gap(BullSpacing.md),
                    ],
                    // Refused: why, in red, as the app shows it.
                    if (state case ArkReceiveEditing(:final failure?)) ...[
                      BullText(
                        failure.toTranslated(context),
                        role: BullTextRole.body,
                        fontWeight: FontWeight.w500,
                        color: context.bull.error,
                        textAlign: TextAlign.center,
                        maxLines: 5,
                      ),
                      const Gap(BullSpacing.md),
                    ],
                    // The QR, or its shimmer while the request is made.
                    if (destination != null || state is ArkReceiveLoading)
                      Center(
                        child: destination == null
                            ? const BullShimmerBox(width: 240, height: 240)
                            : SizedBox.square(
                                key: const ValueKey('ark-receive-qr'),
                                dimension: 240,
                                child: BullQrCode(
                                  data: destination.value,
                                  size: 240,
                                  semanticsLabel: _destinationLabel(
                                    context,
                                    destination.kind,
                                  ),
                                  errorBuilder: (context) => Center(
                                    child: BullText(
                                      context.loc.unavailable,
                                      role: BullTextRole.body,
                                      color: context.bull.error,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    if (ready != null && destination != null) ...[
                      const Gap(BullSpacing.md),
                      // As the app shows a receive address: its label, then
                      // one line in a bordered tile; a tap copies it.
                      Text(
                        destination.kind == ArkDestinationKind.bolt11
                            ? l10n.receiveInvoiceLabel
                            : l10n.receiveAddressLabel,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(6),
                      SizedBox(
                        height: 56,
                        child: BullBorderedTile(
                          backgroundColor: context.bull.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: BullSpacing.md,
                          ),
                          onTap: () => _copy(destination.value),
                          onLongPress: () => _copy(destination.value),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              destination.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.bullType.body.copyWith(
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (destination.fee != null ||
                          destination.net != null ||
                          destination.expiresAt != null) ...[
                        const Gap(BullSpacing.md),
                        ArkReviewFacts(
                          children: [
                            if (destination.fee case final fee?)
                              ArkReviewFact(
                                label: l10n.feeInSats,
                                value: fee.toString(),
                              ),
                            if (destination.net case final net?)
                              ArkReviewFact(
                                label: l10n.netInSats,
                                value: net.toString(),
                                detail: switch (arkFiatText(
                                  context,
                                  net,
                                  widget.displayData?.account == account
                                      ? widget.displayData?.price
                                      : null,
                                )) {
                                  final fiat? => '~$fiat',
                                  null => null,
                                },
                              ),
                            if (destination.expiresAt case final expiry?)
                              ArkReviewFact(
                                label: l10n.invoiceExpires,
                                value: expiry.toLocal().toString(),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            // Lightning only: the invoice is made once its amount is typed.
            if (_lightning && destination == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BullSpacing.md,
                  BullSpacing.sm,
                  BullSpacing.md,
                  BullSpacing.md,
                ),
                child: BullButton.primary(
                  label: l10n.generate,
                  onPressed: state is ArkReceiveLoading || _amount.isEmpty
                      ? null
                      : () => widget.cubit.request(
                          lightning: true,
                          amount: _amount,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    BullSnackBar.show(context, message: context.loc.copied);
  }

  String _destinationLabel(BuildContext context, ArkDestinationKind kind) {
    final l10n = context.loc;
    return switch (kind) {
      ArkDestinationKind.ark => l10n.arkAddress,
      ArkDestinationKind.bolt11 => l10n.lightningInvoice,
      ArkDestinationKind.bitcoin => l10n.unknown,
    };
  }
}
