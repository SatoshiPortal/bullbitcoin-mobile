import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/coming_soon_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/routing/utxos_route.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/widgets/utxo_card.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class UtxosScreen extends StatefulWidget {
  const UtxosScreen({super.key, required this.walletId});

  final String walletId;

  @override
  State<UtxosScreen> createState() => _UtxosScreenState();
}

class _UtxosScreenState extends State<UtxosScreen> {
  final Set<String> _selectedUtxos = {};

  void _toggleUtxoSelection(String outpoint) {
    setState(() {
      if (_selectedUtxos.contains(outpoint)) {
        _selectedUtxos.remove(outpoint);
      } else {
        _selectedUtxos.add(outpoint);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UTXO List')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () async => context.read<UtxosBloc>().add(
                      UtxosLoaded(widget.walletId),
                    ),
                child: BlocBuilder<UtxosBloc, UtxosState>(
                  builder: (context, state) {
                    final utxos = state.utxos;

                    return Column(
                      children: [
                        FadingLinearProgress(
                          trigger: state.isLoading,
                          height: 3,
                          backgroundColor: context.colour.surface,
                          foregroundColor: context.colour.primary,
                        ),
                        Expanded(
                          child:
                              !state.isLoading && utxos.isEmpty
                                  ? Center(
                                    child: Text(
                                      'No UTXOs found',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                  )
                                  : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      0,
                                    ),
                                    itemCount: utxos.length,
                                    separatorBuilder:
                                        (context, index) => const Gap(16),
                                    itemBuilder: (context, index) {
                                      final utxo = utxos[index];
                                      final isSelected = _selectedUtxos
                                          .contains(utxo.outpoint);
                                      return Column(
                                        children: [
                                          if (index == 0) ...[
                                            Text(
                                              'Tap to select a UTXO • Long press for details',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Gap(16),
                                          ],
                                          UtxoCard(
                                            isSpendable: utxo.isSpendable,
                                            txId: utxo.txId,
                                            index: utxo.index,
                                            valueSat: utxo.valueSat,
                                            labels:
                                                utxo.outputLabels +
                                                utxo.inheritedLabels,
                                            isSelected: isSelected,
                                            onTap:
                                                () => _toggleUtxoSelection(
                                                  utxo.outpoint,
                                                ),
                                            onLongPress: () {
                                              context.pushNamed(
                                                UtxosRoute.utxoDetails.name,
                                                pathParameters: {
                                                  'walletId': utxo.walletId,
                                                  'outpoint': utxo.outpoint,
                                                },
                                                extra:
                                                    context.read<UtxosBloc>(),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: Row(
                children: [
                  Expanded(
                    child: BBButton.big(
                      iconData: Icons.merge_type,
                      label: 'Consolidate',
                      iconFirst: true,
                      onPressed: () {
                        ComingSoonBottomSheet.show(
                          context,
                          description:
                              'UTXO consolidation will be available soon.',
                        );
                      },
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onPrimary,
                      disabled: _selectedUtxos.isEmpty,
                    ),
                  ),
                  const Gap(4),
                  Expanded(
                    child: BBButton.big(
                      iconData: Icons.crop_free,
                      label: 'Send',
                      iconFirst: true,
                      onPressed: () {
                        ComingSoonBottomSheet.show(
                          context,
                          description:
                              'Sending selected UTXOs will be available soon.',
                        );
                      },
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onPrimary,
                      disabled: _selectedUtxos.isEmpty,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
