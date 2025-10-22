import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/coming_soon_bottom_sheet.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/widgets/utxo_detail_field.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/widgets/utxo_label_section.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class UtxoDetailsScreen extends StatelessWidget {
  const UtxoDetailsScreen({super.key, required this.outpoint});

  final String outpoint;

  @override
  Widget build(BuildContext context) {
    final utxo = context.select(
      (UtxosBloc bloc) => bloc.state.getUtxo(outpoint),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO Details')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child:
                    utxo != null
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UtxoDetailField(
                              title: 'Transaction ID',
                              value: utxo.txId,
                            ),
                            const SizedBox(height: 8.0),
                            UtxoLabelSection(
                              labels: utxo.transactionLabels,
                              onAddLabel: () {
                                ComingSoonBottomSheet.show(
                                  context,
                                  description:
                                      'Labeling this transaction will be available soon.',
                                );
                              },
                            ),
                            const SizedBox(height: 16.0),
                            UtxoDetailField(
                              title: 'Vout',
                              value: utxo.index.toString(),
                            ),
                            const SizedBox(height: 8.0),
                            UtxoLabelSection(
                              labels: utxo.outputLabels,
                              onAddLabel: () {
                                ComingSoonBottomSheet.show(
                                  context,
                                  description:
                                      'Labeling this UTXO will be available soon.',
                                );
                              },
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              'Value',
                              style: context.theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4.0),
                            CurrencyText(
                              utxo.valueSat,
                              showFiat: false,
                              style: context.theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Spendable',
                                  style: context.theme.textTheme.titleMedium,
                                ),
                                Switch(
                                  value: utxo.isSpendable,
                                  onChanged: (value) {
                                    ComingSoonBottomSheet.show(
                                      context,
                                      description:
                                          'Toggling UTXO spendability will be available soon.',
                                    );
                                    // context.read<UtxosBloc>().add(
                                    //   UtxosSetUtxoSpendable(
                                    //     outpoint: utxo.outpoint,
                                    //     isSpendable: value,
                                    //   ),
                                    // );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            UtxoDetailField(
                              title: 'Wallet Name',
                              value: utxo.walletName,
                            ),
                            const SizedBox(height: 16.0),
                            UtxoDetailField(
                              title: 'Address',
                              value: utxo.address,
                            ),
                            const SizedBox(height: 8.0),
                            UtxoLabelSection(
                              labels: utxo.addressLabels,
                              onAddLabel: () {
                                ComingSoonBottomSheet.show(
                                  context,
                                  description:
                                      'Labeling this address will be available soon.',
                                );
                              },
                            ),
                          ],
                        )
                        : const Center(child: Text('UTXO not found')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: BBButton.big(
                iconData: Icons.crop_free,
                label: 'Send',
                iconFirst: true,
                onPressed: () {
                  ComingSoonBottomSheet.show(
                    context,
                    description: 'Sending this UTXO will be available soon.',
                  );
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onPrimary,
                disabled: utxo == null,
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
