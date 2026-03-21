import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// TODO: replace stub values with real wallet signing logic.
const _stubAcceptHex = 'stub_accept_hex';
const _stubCetSignatureHex = 'stub_cet_signature_hex';

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
            appBar: AppBar(title: const Text('Contract Detail')),
            body: const Center(child: Text('No contract selected')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contract Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => context
                    .read<DlcContractsCubit>()
                    .refreshContract(contractId: contract.id),
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
                if (contract.status == DlcContractStatus.offered)
                  _AcceptOfferButton(
                    contract: contract,
                    isActing: state.isActing,
                    onAccept: () => context
                        .read<DlcContractsCubit>()
                        .acceptOffer(
                          offerId: contract.id,
                          acceptHex: _stubAcceptHex,
                        ),
                  ),
                if (contract.status == DlcContractStatus.accepted)
                  _SignCetsButton(
                    contract: contract,
                    isActing: state.isActing,
                    onSign: () => context
                        .read<DlcContractsCubit>()
                        .submitSignedCets(
                          contractId: contract.id,
                          cetSignatureHex: _stubCetSignatureHex,
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
    final isCall = contract.optionType == DlcOptionType.call;
    return Card(
      color: isCall ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isCall ? Colors.green.shade200 : Colors.red.shade200,
              child: Text(
                isCall ? 'C' : 'P',
                style: TextStyle(
                  color:
                      isCall ? Colors.green.shade900 : Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isCall ? 'Call' : 'Put'} Option',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Strike: ${contract.strikePriceSat} sats',
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
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      contract.expiryTimestamp * 1000,
    );
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
            _Row(label: 'Premium', value: '${contract.premiumSat} sats'),
            _Row(label: 'Collateral', value: '${contract.collateralSat} sats'),
            _Row(
              label: 'Expiry',
              value: '${expiry.toLocal()}'.substring(0, 16),
            ),
            _Row(
              label: 'Counterparty',
              value: _truncate(contract.counterpartyPubkey),
              onCopy: () => _copy(context, contract.counterpartyPubkey),
            ),
            _Row(
              label: 'Oracle',
              value: _truncate(contract.oraclePubkey),
              onCopy: () => _copy(context, contract.oraclePubkey),
            ),
            if (contract.fundingTxId != null)
              _Row(
                label: 'Funding TX',
                value: _truncate(contract.fundingTxId!),
                onCopy: () => _copy(context, contract.fundingTxId!),
              ),
            if (contract.label != null)
              _Row(label: 'Label', value: contract.label!),
            _Row(label: 'Created', value: contract.createdAt.substring(0, 10)),
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

class _AcceptOfferButton extends StatelessWidget {
  const _AcceptOfferButton({
    required this.contract,
    required this.isActing,
    required this.onAccept,
  });
  final DlcContract contract;
  final bool isActing;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isActing ? null : onAccept,
      icon: isActing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.handshake),
      label: const Text('Accept Offer'),
    );
  }
}

class _SignCetsButton extends StatelessWidget {
  const _SignCetsButton({
    required this.contract,
    required this.isActing,
    required this.onSign,
  });
  final DlcContract contract;
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
