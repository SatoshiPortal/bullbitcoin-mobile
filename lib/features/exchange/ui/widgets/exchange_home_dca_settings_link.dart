import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ExchangeHomeDcaSettingsLink extends StatefulWidget {
  const ExchangeHomeDcaSettingsLink({
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
  State<ExchangeHomeDcaSettingsLink> createState() =>
      _ExchangeHomeDcaSettingsLinkState();
}

class _ExchangeHomeDcaSettingsLinkState
    extends State<ExchangeHomeDcaSettingsLink>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );
    final frequency = switch (widget.frequency) {
      DcaBuyFrequency.hourly => 'hour',
      DcaBuyFrequency.daily => 'day',
      DcaBuyFrequency.weekly => 'week',
      DcaBuyFrequency.monthly => 'month',
    };
    final network = switch (widget.network) {
      DcaNetwork.bitcoin => 'Bitcoin Network',
      DcaNetwork.lightning => 'Lightning Network',
      DcaNetwork.liquid => 'Liquid Network',
    };
    final addressLabel = switch (widget.network) {
      DcaNetwork.bitcoin => 'Bitcoin address',
      DcaNetwork.lightning => 'Lightning address',
      DcaNetwork.liquid => 'Liquid address',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft,
          ),
          child: Text(
            _open ? 'Hide DCA settings' : 'View DCA settings',
            style: linkStyle,
          ),
        ),

        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Text(
                  'You are buying '
                  '${FormatAmount.fiat(widget.amount, widget.currency.code)} '
                  'every $frequency via $network '
                  'as long as there are funds in your account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(8),
                Text(
                  '$addressLabel: ${widget.address}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
