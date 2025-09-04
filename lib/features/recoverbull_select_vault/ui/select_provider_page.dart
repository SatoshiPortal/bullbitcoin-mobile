import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/selectors/recoverbull_vault_provider_selector.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SelectProviderPage extends StatelessWidget {
  const SelectProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Recover Wallet',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: RecoverbullVaultProviderSelector(
          onProviderSelected:
              context.read<RecoverBullSelectVaultCubit>().selectProvider,
        ),
      ),
    );
  }
}
