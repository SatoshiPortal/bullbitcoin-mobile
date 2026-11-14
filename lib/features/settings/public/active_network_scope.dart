import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recreates network-bound presentation state when the active network changes.
class ActiveNetworkScope extends StatelessWidget {
  final Widget child;

  const ActiveNetworkScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final environment = context.select(
      (SettingsCubit cubit) => cubit.state.environment,
    );
    return KeyedSubtree(key: ValueKey(environment), child: child);
  }
}
