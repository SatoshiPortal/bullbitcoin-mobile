import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServiceStatusIndicator extends StatefulWidget {
  const ServiceStatusIndicator({super.key});

  @override
  State<ServiceStatusIndicator> createState() => _ServiceStatusIndicatorState();
}

class _ServiceStatusIndicatorState extends State<ServiceStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final serviceStatus = state.serviceStatus;
        final isChecking = state.isCheckingServiceStatus;

        if (serviceStatus == null && !isChecking) {
          return const SizedBox.shrink();
        }

        // Determine if we should pulse (only for error states)
        final shouldPulse = _shouldPulse(serviceStatus, isChecking);

        // Control animation based on status
        if (shouldPulse && !_animationController.isAnimating) {
          _animationController.repeat(reverse: true);
        } else if (!shouldPulse && _animationController.isAnimating) {
          _animationController.stop();
        }

        return GestureDetector(
          onTap: () => _showStatusBottomSheet(context, serviceStatus),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: shouldPulse ? _animation.value : 1.0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(
                        context,
                        serviceStatus,
                        isChecking,
                      ),
                    ),
                    child:
                        isChecking
                            ? Center(
                              child: SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.colour.onPrimary,
                                  ),
                                ),
                              ),
                            )
                            : null,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _shouldPulse(AllServicesStatus? serviceStatus, bool isChecking) {
    if (isChecking) return false; // Don't pulse while checking

    if (serviceStatus == null) return true; // Pulse if no status

    // Only pulse if any service is offline or unknown
    return serviceStatus.hasAnyServiceOffline;
  }

  Color _getStatusColor(
    BuildContext context,
    AllServicesStatus? serviceStatus,
    bool isChecking,
  ) {
    if (isChecking) {
      return context.colour.primary;
    }

    if (serviceStatus == null) {
      return context.colour.surfaceContainerHighest;
    }

    return serviceStatus.allServicesOnline
        ? context.colour.inverseSurface
        : serviceStatus.hasAnyServiceOffline
        ? context.colour.error
        : context.colour.surfaceContainerHighest;
  }

  void _showStatusBottomSheet(
    BuildContext context,
    AllServicesStatus? serviceStatus,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colour.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => ServiceStatusBottomSheet(serviceStatus: serviceStatus),
    );
  }
}

class ServiceStatusBottomSheet extends StatelessWidget {
  final AllServicesStatus? serviceStatus;

  const ServiceStatusBottomSheet({super.key, required this.serviceStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BBText(
                'Service Status',
                style: context.font.headlineSmall,
                color: context.colour.onSurface,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: context.colour.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (serviceStatus == null)
            BBText(
              'Status not available',
              style: context.font.bodyMedium,
              color: context.colour.onSurfaceVariant,
            )
          else
            Column(
              children: [
                _ServiceStatusItem(service: serviceStatus!.internetConnection),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.bitcoinElectrum),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.liquidElectrum),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.boltz),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.payjoin),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.pricer),
                const SizedBox(height: 12),
                _ServiceStatusItem(service: serviceStatus!.mempool),
                const SizedBox(height: 16),
                BBText(
                  'Last checked: ${_formatDateTime(serviceStatus!.lastChecked)}',
                  style: context.font.bodySmall,
                  color: context.colour.onSurfaceVariant,
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
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
