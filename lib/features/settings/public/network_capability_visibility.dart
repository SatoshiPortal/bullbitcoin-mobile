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
    return network != null && NetworkCapabilities.supports(network, capability)
        ? child
        : const SizedBox.shrink();
  }
}
