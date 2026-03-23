import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_and_submit_cets_usecase.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DlcContractDetailScreen extends StatelessWidget {
  const DlcContractDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DlcContractsCubit, DlcContractsState>(
      listener: (context, state) {
        if (state.error != null && !state.isActing) {
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
                onPressed: state.isActing
                    ? null
                    : () => context
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
                  _SigningSection(
                    isActing: state.isActing,
                    signingStep: state.signingStep,
                    error: state.error,
                    onSign: () => context
                        .read<DlcContractsCubit>()
                        .signAndSubmitMaker(dlcId: contract.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Signing section ──────────────────────────────────────────────────────────

class _SigningSection extends StatelessWidget {
  const _SigningSection({
    required this.isActing,
    required this.signingStep,
    required this.error,
    required this.onSign,
  });

  final bool isActing;
  final DlcSigningStep? signingStep;
  final Exception? error;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    if (isActing) {
      return _SigningProgressCard(currentStep: signingStep);
    }
    if (error != null) {
      return _SigningErrorCard(error: error!, onRetry: onSign);
    }
    return _SignButton(onSign: onSign);
  }
}

class _SignButton extends StatelessWidget {
  const _SignButton({required this.onSign});
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onSign,
      icon: const Icon(Icons.draw),
      label: const Text('Sign & Submit CETs'),
    );
  }
}

/// Shows the four signing steps with the current one animated.
class _SigningProgressCard extends StatelessWidget {
  const _SigningProgressCard({required this.currentStep});

  final DlcSigningStep? currentStep;

  static const _steps = [
    (DlcSigningStep.fetchingContext, Icons.cloud_download_outlined, 'Fetching sign context'),
    (DlcSigningStep.preparingKey, Icons.key_outlined, 'Preparing wallet key'),
    (DlcSigningStep.signing, Icons.draw_outlined, 'Signing transactions'),
    (DlcSigningStep.submitting, Icons.upload_outlined, 'Submitting signatures'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = currentStep == null
        ? -1
        : _steps.indexWhere((s) => s.$1 == currentStep);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Signing in progress…',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _steps.length; i++)
              _StepRow(
                icon: _steps[i].$2,
                label: _steps[i].$3,
                status: i < currentIndex
                    ? _StepStatus.done
                    : i == currentIndex
                        ? _StepStatus.active
                        : _StepStatus.pending,
              ),
          ],
        ),
      ),
    );
  }
}

enum _StepStatus { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, Widget leading) = switch (status) {
      _StepStatus.done => (
          theme.colorScheme.primary,
          Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary),
        ),
      _StepStatus.active => (
          theme.colorScheme.secondary,
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _StepStatus.pending => (
          theme.colorScheme.outlineVariant,
          Icon(icon, size: 20, color: theme.colorScheme.outlineVariant),
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: status == _StepStatus.active
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _SigningErrorCard extends StatelessWidget {
  const _SigningErrorCard({required this.error, required this.onRetry});

  final Exception error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signing failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status banner ─────────────────────────────────────────────────────────────

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
              backgroundColor:
                  isActive ? Colors.blue.shade200 : Colors.grey.shade300,
              child: Icon(
                Icons.handshake_outlined,
                color: isActive
                    ? Colors.blue.shade900
                    : Colors.grey.shade700,
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

// ─── Detail card ───────────────────────────────────────────────────────────────

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
            child:
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
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
