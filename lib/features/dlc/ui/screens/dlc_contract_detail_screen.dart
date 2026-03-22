import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// TODO: replace stub signatures with real wallet signing logic.
const _stubCetAdaptorSignaturesHex = 'stub_cet_adaptor_signatures_hex';
const _stubRefundSignatureHex = 'stub_refund_signature_hex';
const _stubFundingSignaturesHex = 'stub_funding_signatures_hex';

class DlcContractDetailScreen extends StatelessWidget {
  const DlcContractDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DlcContractsCubit, DlcContractsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final contract = state.selectedContract;
        if (contract == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('DLC Detail')),
            body: const Center(child: Text('No DLC selected')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('DLC Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => context
                    .read<DlcContractsCubit>()
                    .refreshContract(dlcId: contract.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(contract: contract),
                const SizedBox(height: 16),
                _DetailCard(contract: contract),
                const SizedBox(height: 16),
                if (contract.status == DlcContractStatus.accepted)
                  _SignCetsButton(
                    isActing: state.isActing,
                    onSign: () => context
                        .read<DlcContractsCubit>()
                        .submitSignedCets(
                          dlcId: contract.id,
                          cetAdaptorSignaturesHex: _stubCetAdaptorSignaturesHex,
                          refundSignatureHex: _stubRefundSignatureHex,
                          fundingSignaturesHex: _stubFundingSignaturesHex,
                        ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.contract});
  final DlcContract contract;

  @override
  Widget build(BuildContext context) {
    final isActive = contract.isActive;
    return Card(
      color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? Colors.blue.shade200 : Colors.grey.shade300,
              child: Icon(
                Icons.handshake_outlined,
                color: isActive ? Colors.blue.shade900 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DLC Contract',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Instrument: ${contract.instrumentId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(contract.status.name),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.contract});
  final DlcContract contract;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _Row(
              label: 'DLC ID',
              value: contract.id,
              onCopy: () => _copy(context, contract.id),
            ),
            _Row(
              label: 'Order ID',
              value: contract.orderId.isNotEmpty ? contract.orderId : '–',
            ),
            _Row(label: 'Price', value: '${contract.price} sats'),
            _Row(label: 'Collateral', value: '${contract.collateralSat} sats'),
            if (contract.fundingTxId != null)
              _Row(
                label: 'Funding TX',
                value: _truncate(contract.fundingTxId!),
                onCopy: () => _copy(context, contract.fundingTxId!),
              ),
            if (contract.label != null)
              _Row(label: 'Label', value: contract.label!),
            _Row(
              label: 'Created',
              value: contract.createdAt.isNotEmpty
                  ? contract.createdAt.substring(
                      0,
                      contract.createdAt.length < 10
                          ? contract.createdAt.length
                          : 10,
                    )
                  : '–',
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s) =>
      s.length > 16 ? '${s.substring(0, 8)}…${s.substring(s.length - 6)}' : s;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: onCopy,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SignCetsButton extends StatelessWidget {
  const _SignCetsButton({required this.isActing, required this.onSign});
  final bool isActing;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isActing ? null : onSign,
      icon: isActing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.draw),
      label: const Text('Submit Signed CETs'),
    );
  }
}
