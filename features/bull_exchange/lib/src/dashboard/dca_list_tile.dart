import '../exchange_l10n.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullConfirmDialog, BullSwitch, BullTypographyX, Gap;

class DcaListTile extends StatefulWidget {
  const DcaListTile({
    super.key,
    required this.hasDcaActive,
    required this.dca,
    required this.onActivate,
    required this.onDeactivate,
  });

  final bool hasDcaActive;
  final UserDca? dca;
  final VoidCallback onActivate;
  final Future<void> Function() onDeactivate;

  @override
  State<DcaListTile> createState() => _DcaListTileState();
}

class _DcaListTileState extends State<DcaListTile> {
  bool _showSettings = false;

  Widget? _buildDcaContent(UserDca dca, BuildContext context) {
    final amount = dca.amount;
    final currency = dca.currency;
    final frequency = dca.frequency;
    final network = dca.network;
    final address = dca.address;
    if (amount == null ||
        currency == null ||
        frequency == null ||
        network == null ||
        address == null) {
      return Text(
        context.loc.exchangeDcaUnableToGetConfig,
        style: TextStyle(
          color: context.appColors.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return DcaSettingsContent(
      amount: amount,
      currency: currency,
      frequency: frequency,
      network: network,
      address: address,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dca = widget.dca;
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Text(
                  widget.hasDcaActive
                      ? context.loc.exchangeDcaDeactivateTitle
                      : context.loc.exchangeDcaActivateTitle,
                ),
                if (widget.hasDcaActive) ...[
                  const Gap(4),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showSettings = !_showSettings),
                    child: Text(
                      _showSettings
                          ? context.loc.exchangeDcaHideSettings
                          : context.loc.exchangeDcaViewSettings,
                      style: context.bullType.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.appColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.appColors.primary,
                      ),
                    ),
                  ),
                  const Gap(4),
                ],
              ],
            ),
          ),
          BullSwitch(
            value: widget.hasDcaActive,
            onChanged: (value) {
              if (value) {
                // Activate DCA
                widget.onActivate();
              } else {
                // Deactivate DCA - show confirmation dialog
                _confirmStopDca(context);
              }
            },
          ),
        ],
      ),
      subtitle: widget.hasDcaActive && _showSettings && dca != null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDcaContent(dca, context),
            )
          : null,
    );
  }

  Future<void> _confirmStopDca(BuildContext context) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.exchangeDcaCancelDialogTitle,
      message: context.loc.exchangeDcaCancelDialogMessage,
      confirmLabel: context.loc.exchangeDcaCancelDialogConfirmButton,
      cancelLabel: context.loc.exchangeDcaCancelDialogCancelButton,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await widget.onDeactivate();
    }
  }
}

class DcaSettingsContent extends StatelessWidget {
  const DcaSettingsContent({
    super.key,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.network,
    required this.address,
  });

  final double amount;
  final FiatCurrency currency;
  final DcaBuyFrequency frequency;
  final BtcNetwork network;
  final String address;

  @override
  Widget build(BuildContext context) {
    final frequency = switch (this.frequency) {
      DcaBuyFrequency.hourly => context.loc.exchangeDcaFrequencyHour,
      DcaBuyFrequency.daily => context.loc.exchangeDcaFrequencyDay,
      DcaBuyFrequency.weekly => context.loc.exchangeDcaFrequencyWeek,
      DcaBuyFrequency.monthly => context.loc.exchangeDcaFrequencyMonth,
    };
    final network = switch (this.network) {
      BtcNetwork.bitcoin => context.loc.exchangeDcaNetworkBitcoin,
      BtcNetwork.lightning => context.loc.exchangeDcaNetworkLightning,
      BtcNetwork.liquid => context.loc.exchangeDcaNetworkLiquid,
    };
    final addressLabel = switch (this.network) {
      BtcNetwork.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
      BtcNetwork.lightning => context.loc.exchangeDcaAddressLabelLightning,
      BtcNetwork.liquid => context.loc.exchangeDcaAddressLabelLiquid,
    };

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.loc.exchangeDcaSummaryMessage(
            FormatAmount.fiat(amount, currency.code),
            frequency,
            network,
          ),
          style: context.bullType.body,
        ),
        const Gap(8),
        Text(
          context.loc.exchangeDcaAddressDisplay(addressLabel, address),
          style: context.bullType.body,
        ),
      ],
    );
  }
}
