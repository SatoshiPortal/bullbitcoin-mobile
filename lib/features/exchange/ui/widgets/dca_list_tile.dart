import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/ui/dca_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
class DcaListTile extends StatefulWidget {
  const DcaListTile({super.key, required this.hasDcaActive, required this.dca});

  final bool hasDcaActive;
  final UserDca? dca;

  @override
  State<DcaListTile> createState() => _DcaListTileState();
}

class _DcaListTileState extends State<DcaListTile> {
  bool _showSettings = false;

  Widget? _buildDcaContent(UserDca dca, BuildContext context) {
    if (dca.amount == null ||
        dca.currency == null ||
        dca.frequency == null ||
        dca.network == null ||
        dca.address == null) {
      return Text(
        context.loc.exchangeDcaUnableToGetConfig,
        style: TextStyle(
          color: context.colour.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return DcaSettingsContent(
      amount: dca.amount!,
      currency: dca.currency!,
      frequency: dca.frequency!,
      network: dca.network!,
      address: dca.address!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.hasDcaActive
                      ? context.loc.exchangeDcaDeactivateTitle
                      : context.loc.exchangeDcaActivateTitle,
                ),
                if (widget.hasDcaActive) ...[
                  const Gap(4),
                  GestureDetector(
                    onTap: () => setState(() => _showSettings = !_showSettings),
                    child: Text(
                      _showSettings ? context.loc.exchangeDcaHideSettings : context.loc.exchangeDcaViewSettings,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colour.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.colour.primary,
                      ),
                    ),
                  ),
                  const Gap(4),
                ],
              ],
            ),
          ),
          Switch(
            value: widget.hasDcaActive,
            onChanged: (value) {
              if (value) {
                // Activate DCA
                context.pushNamed(DcaRoute.dca.name);
              } else {
                // Deactivate DCA - show confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      title: Text(context.loc.exchangeDcaCancelDialogTitle),
                      content: Text(
                        context.loc.exchangeDcaCancelDialogMessage,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text(context.loc.exchangeDcaCancelDialogCancelButton),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            context.read<ExchangeCubit>().stopDca();
                          },
                          child: Text(context.loc.exchangeDcaCancelDialogConfirmButton),
                        ),
                      ],
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
      subtitle:
          widget.hasDcaActive && _showSettings
              ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildDcaContent(widget.dca!, context),
              )
              : null,
    );
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
  final DcaNetwork network;
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
      DcaNetwork.bitcoin => context.loc.exchangeDcaNetworkBitcoin,
      DcaNetwork.lightning => context.loc.exchangeDcaNetworkLightning,
      DcaNetwork.liquid => context.loc.exchangeDcaNetworkLiquid,
    };
    final addressLabel = switch (this.network) {
      DcaNetwork.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
      DcaNetwork.lightning => context.loc.exchangeDcaAddressLabelLightning,
      DcaNetwork.liquid => context.loc.exchangeDcaAddressLabelLiquid,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.exchangeDcaSummaryMessage(
            FormatAmount.fiat(amount, currency.code),
            frequency,
            network,
          ),
          style: context.font.bodyMedium,
        ),
        const Gap(8),
        Text(
          context.loc.exchangeDcaAddressDisplay(addressLabel, address),
          style: context.font.bodyMedium,
        ),
      ],
    );
  }
}
