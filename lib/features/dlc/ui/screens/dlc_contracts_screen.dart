import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:bb_mobile/features/dlc/ui/dlc_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Temporary stub pubkey — will be replaced with the real wallet pubkey.
const _stubPubkey = 'stub_pubkey';

class DlcContractsScreen extends StatefulWidget {
  const DlcContractsScreen({super.key});

  @override
  State<DlcContractsScreen> createState() => _DlcContractsScreenState();
}

class _DlcContractsScreenState extends State<DlcContractsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DlcContractsCubit>().loadContracts(pubkey: _stubPubkey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contracts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<DlcContractsCubit>()
                .refresh(pubkey: _stubPubkey),
          ),
        ],
      ),
      body: BlocBuilder<DlcContractsCubit, DlcContractsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.contracts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error: ${state.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context
                        .read<DlcContractsCubit>()
                        .refresh(pubkey: _stubPubkey),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state.contracts.isEmpty) {
            return const Center(child: Text('No contracts yet'));
          }
          return RefreshIndicator(
            onRefresh: () => context
                .read<DlcContractsCubit>()
                .refresh(pubkey: _stubPubkey),
            child: CustomScrollView(
              slivers: [
                if (state.offeredContracts.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Pending Offers'),
                  ),
                  SliverList.separated(
                    itemCount: state.offeredContracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ContractRow(
                      contract: state.offeredContracts[index],
                      onTap: () => _openDetail(
                        context,
                        state.offeredContracts[index],
                      ),
                    ),
                  ),
                ],
                if (state.activeContracts.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Active'),
                  ),
                  SliverList.separated(
                    itemCount: state.activeContracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ContractRow(
                      contract: state.activeContracts[index],
                      onTap: () => _openDetail(
                        context,
                        state.activeContracts[index],
                      ),
                    ),
                  ),
                ],
                if (state.closedContracts.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Closed'),
                  ),
                  SliverList.separated(
                    itemCount: state.closedContracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ContractRow(
                      contract: state.closedContracts[index],
                      onTap: () => _openDetail(
                        context,
                        state.closedContracts[index],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, DlcContract contract) {
    context.read<DlcContractsCubit>().selectContract(contract);
    context.push(DlcRoute.contractDetail.path);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({required this.contract, required this.onTap});
  final DlcContract contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCall = contract.optionType == DlcOptionType.call;
    final statusColor = _statusColor(contract.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCall ? Colors.green.shade100 : Colors.red.shade100,
        child: Text(
          isCall ? 'C' : 'P',
          style: TextStyle(
            color: isCall ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '${isCall ? 'Call' : 'Put'} @ ${contract.strikePriceSat} sats',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Premium ${contract.premiumSat} sats · '
        'Collateral ${contract.collateralSat} sats',
      ),
      trailing: Chip(
        label: Text(contract.status.name),
        backgroundColor: statusColor.withAlpha(40),
        labelStyle: TextStyle(color: statusColor, fontSize: 12),
        visualDensity: VisualDensity.compact,
      ),
      onTap: onTap,
    );
  }

  Color _statusColor(DlcContractStatus status) => switch (status) {
        DlcContractStatus.offered => Colors.orange,
        DlcContractStatus.accepted => Colors.blue,
        DlcContractStatus.signed => Colors.indigo,
        DlcContractStatus.confirmed => Colors.green,
        DlcContractStatus.closed => Colors.grey,
        DlcContractStatus.refunded => Colors.grey,
        DlcContractStatus.rejected => Colors.red,
      };
}
