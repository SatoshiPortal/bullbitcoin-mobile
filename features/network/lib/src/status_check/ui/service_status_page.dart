import 'dart:async';

import '../domain/service_status.dart';
import '../../network_l10n.dart';
import '../domain/network_failure.dart';
import '../presentation/network_failure_l10n.dart';
import '../status_session.dart';

import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullPullableBody, BullText, BullTypographyX;

class ServiceStatusPage extends StatefulWidget {
  final NetworkStatus status;

  const ServiceStatusPage({required this.status, super.key});

  @override
  State<ServiceStatusPage> createState() => _ServiceStatusPageState();
}

class _ServiceStatusPageState extends State<ServiceStatusPage> {
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late final StatusSession _session;
  late final Stream<Result<StatusSnapshot, NetworkFailure>> _updates;

  @override
  void initState() {
    super.initState();
    _session = widget.status.session();
    _updates = _session.watch();
    // Show the RefreshIndicator spinner and trigger the first check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    unawaited(_session.close());
    super.dispose();
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
      body: StreamBuilder<Result<StatusSnapshot, NetworkFailure>>(
        stream: _updates,
        builder: (context, update) {
          final serviceStatus = switch (update.data) {
            Ok(:final value) => value.services,
            _ => _session.snapshot.services,
          };
          final failure = switch (update.data) {
            Err(:final failure) => failure,
            _ => null,
          };

          return BullPullableBody(
            indicatorKey: _refreshIndicatorKey,
            onRefresh: () async {
              final _ = await _session.check();
            },
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (failure != null) ...[
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
                    if (serviceStatus.silent case final silent?) ...[
                      _ServiceStatusItem(
                        service: silent,
                        label: context.loc.statusCheckSilentPayments,
                      ),
                      const SizedBox(height: 12),
                    ],
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
                    if (failure != null &&
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
