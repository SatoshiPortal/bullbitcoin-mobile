import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServiceStatusPage extends StatelessWidget {
  const ServiceStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Status')),
      body: BlocBuilder<ServiceStatusCubit, ServiceStatusState>(
        builder: (context, state) {
          final serviceStatus = state.serviceStatus;
          final cubit = context.read<ServiceStatusCubit>();

          return RefreshIndicator(
            onRefresh: () async => await cubit.checkStatus(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (serviceStatus == null)
                      FadingLinearProgress(trigger: serviceStatus == null)
                    else
                      Column(
                        children: [
                          _ServiceStatusItem(
                            service: serviceStatus.internetConnection,
                          ),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(
                            service: serviceStatus.bitcoinElectrum,
                          ),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(
                            service: serviceStatus.liquidElectrum,
                          ),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.boltz),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.payjoin),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.pricer),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.mempool),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.tor),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(
                            service: serviceStatus.recoverbull,
                          ),
                          const SizedBox(height: 12),
                          _ServiceStatusItem(service: serviceStatus.ark),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BBText(
                                'Last checked: ${_formatDateTime(serviceStatus.lastChecked)}',
                                style: context.font.bodySmall,
                                color: context.colour.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

class _ServiceStatusItem extends StatelessWidget {
  final ServiceStatusInfo service;

  const _ServiceStatusItem({required this.service});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(context),
          ),
        ),
        const SizedBox(width: 12),
        BBText(
          service.name,
          style: context.font.bodyMedium,
          color: context.colour.onSurface,
        ),
        const Spacer(),
        BBText(
          _getStatusText(),
          style: context.font.bodySmall,
          color: context.colour.onSurfaceVariant,
        ),
      ],
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (service.status) {
      case ServiceStatus.online:
        return context.colour.inverseSurface;
      case ServiceStatus.offline:
        return context.colour.error;
      case ServiceStatus.unknown:
        return context.colour.surfaceContainerHighest;
    }
  }

  String _getStatusText() {
    switch (service.status) {
      case ServiceStatus.online:
        return 'Online';
      case ServiceStatus.offline:
        return 'Offline';
      case ServiceStatus.unknown:
        return 'Unknown';
    }
  }
}
