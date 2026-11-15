import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Hides network-dependent navigation. Operation boundaries still authorize IO.
class NetworkCapabilityVisibility extends StatelessWidget {
  final NetworkCapability capability;
  final Widget child;

  const NetworkCapabilityVisibility({
    super.key,
    required this.capability,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => NetworkCapabilityBuilder(
    capability: capability,
    builder: (context, supported) =>
        supported ? child : const SizedBox.shrink(),
  );
}

/// Builds with whether the active network supports [capability], for a layout
/// that changes shape instead of hiding one child.
class NetworkCapabilityBuilder extends StatelessWidget {
  final NetworkCapability capability;
  final Widget Function(BuildContext context, bool supported) builder;

  const NetworkCapabilityBuilder({
    super.key,
    required this.capability,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final environment = context.select(
      (SettingsCubit cubit) => cubit.state.storedSettings?.activeNetwork,
    );
    final network = switch (environment) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
      NetworkEnv.signet || null => null,
    };
    return builder(
      context,
      network != null && NetworkCapabilities.supports(network, capability),
    );
  }
}
