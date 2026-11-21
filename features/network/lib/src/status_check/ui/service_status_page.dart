import '../domain/service_status.dart';
import '../../network_l10n.dart';
import '../presentation/service_status_cubit.dart';
import '../presentation/service_status_state.dart';
import '../presentation/status_check_failure_l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullPullableBody, BullText, BullTypographyX;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.statusCheckTitle),
        actions: [
          IconButton(
            tooltip: context.loc.statusCheckRefresh,
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: () => _refreshIndicatorKey.currentState?.show(),
          ),
        ],
      ),
      body: BlocBuilder<ServiceStatusCubit, ServiceStatusState>(
        builder: (context, state) {
          final serviceStatus = state.serviceStatus;
          final cubit = context.read<ServiceStatusCubit>();

          return BullPullableBody(
            indicatorKey: _refreshIndicatorKey,
            onRefresh: cubit.checkStatus,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (state.failure case final failure?) ...[
                      BullText(
                        failure.toTranslated(context),
                        style: context.bullType.body,
                        color: context.bull.error,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ServiceStatusItem(
                      service: serviceStatus.internetConnection,
                      label: context.loc.statusCheckInternetConnection,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.bitcoinElectrum,
                      label: context.loc.statusCheckBitcoinElectrum,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.liquidElectrum,
                      label: context.loc.statusCheckLiquidElectrum,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.payjoin,
                      label: context.loc.statusCheckPayjoin,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.pricer,
                      label: context.loc.statusCheckPricer,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.mempool,
                      label: context.loc.statusCheckMempool,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.tor,
                      label: context.loc.statusCheckTor,
                    ),
                    const SizedBox(height: 12),
                    _ServiceStatusItem(
                      service: serviceStatus.recoverbull,
                      label: context.loc.statusCheckRecoverBull,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: .center,
                      children: [
                        if (serviceStatus.lastChecked case final lastChecked?)
                          BullText(
                            context.loc.statusCheckLastChecked(
                              _formatDateTime(lastChecked),
                            ),
                            style: context.bullType.label.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                            color: context.bull.onSurfaceVariant,
                          ),
                      ],
                    ),
                    if (state.failure != null &&
                        serviceStatus.lastChecked != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: .center,
                        children: [
                          BullText(
                            context.loc.statusCheckResultsMayBeOutdated,
                            style: context.bullType.label.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                            color: context.bull.warning,
                          ),
                        ],
                      ),
                    ],
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
  final String label;

  const _ServiceStatusItem({required this.service, required this.label});

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
        Expanded(
          child: BullText(
            label,
            style: context.bullType.body,
            color: context.bull.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        BullText(
          _getStatusText(context),
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.bull.onSurfaceVariant,
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
        return context.bull.textMuted;
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
