import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Joinstr entry on the wallet home screen. Gated on the superuser flag, like
/// the settings entry: the feature is an experimental, testnet-only coinjoin,
/// so it stays hidden for ordinary users until it graduates.
class WalletJoinstrTile extends StatelessWidget {
  const WalletJoinstrTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser =
        context.select((SettingsCubit cubit) => cubit.state.isSuperuser) ??
        false;
    if (!isSuperuser) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.shuffle),
          title: Text(context.loc.joinstrTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(SettingsRoute.joinstr.name),
        ),
      ),
    );
  }
}
