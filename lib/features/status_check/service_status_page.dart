import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ServiceStatusPage extends StatefulWidget {
  const ServiceStatusPage({super.key});

  @override
  State<ServiceStatusPage> createState() => _ServiceStatusPageState();
}

class _ServiceStatusPageState extends State<ServiceStatusPage> {
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // Show the RefreshIndicator spinner and trigger the first check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.statusCheckTitle,
        onBack: context.pop,
      ),
      child: BlocBuilder<ServiceStatusCubit, ServiceStatusState>(
        builder: (context, state) {
          final serviceStatus = state.serviceStatus;
          final cubit = context.read<ServiceStatusCubit>();

          return BullPullableBody(
            indicatorKey: _refreshIndicatorKey,
            onRefresh: () async => await cubit.checkStatus(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ServiceStatusItem(
                      service: serviceStatus.internetConnection,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.bitcoinElectrum),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.liquidElectrum),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.payjoin),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.pricer),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.mempool),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.tor),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(service: serviceStatus.recoverbull),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: .center,
                      children: [
                        if (serviceStatus.lastChecked != null)
                          BullText(
                            context.loc.statusCheckLastChecked(
                              _formatDateTime(serviceStatus.lastChecked!),
                            ),
                            style: context.font.bodySmall,
                            color: context.appColors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
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
            shape: .circle,
            color: _getStatusColor(context),
          ),
        ),
        const SizedBox(width: 12),
        BullText(
          service.name,
          style: context.font.bodyMedium,
          color: context.appColors.onSurface,
        ),
        const Spacer(),
        BullText(
          _getStatusText(context),
          style: context.font.bodySmall,
          color: context.appColors.onSurfaceVariant,
        ),
      ],
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (service.status) {
      case ServiceStatus.online:
        return context.bull.success;
      case ServiceStatus.offline:
        return context.bull.error;
      case ServiceStatus.unknown:
      case ServiceStatus.disabled:
        return context.bull.onSurfaceVariant;
    }
  }

  String _getStatusText(BuildContext context) {
    switch (service.status) {
      case ServiceStatus.online:
        return context.loc.statusCheckOnline;
      case ServiceStatus.offline:
        return context.loc.statusCheckOffline;
      case ServiceStatus.unknown:
        return context.loc.statusCheckUnknown;
      case ServiceStatus.disabled:
        return context.loc.statusCheckDisabled;
    }
  }
}
