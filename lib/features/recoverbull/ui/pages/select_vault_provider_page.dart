import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/selectors/recoverbull_vault_provider_selector.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_created_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SelectVaultProviderPage extends StatelessWidget {
  const SelectVaultProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Select Vault Provider',
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: KeyServerStatusWidget(),
          ),
        ],
      ),
      body: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listenWhen:
            (previous, current) =>
                previous.error != current.error ||
                current.vault != null && previous.vault != current.vault,
        listener: (context, state) {
          if (state.error != null) {
            SnackBarUtils.showSnackBar(context, state.error!.message);
          }

          if (state.vault != null) {
            switch (state.flow) {
              case RecoverBullFlow.secureVault:
                SnackBarUtils.showSnackBar(
                  context,
                  'Vault created successfully',
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VaultCreatedPage(),
                  ),
                );
              default:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PasswordInputPage(),
                  ),
                );
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              if (!state.isLoading)
                RecoverbullVaultProviderSelector(
                  onProviderSelected: (provider) {
                    context.read<RecoverBullBloc>().add(
                      OnVaultProviderSelection(provider: provider),
                    );
                  },
                ),

              if (state.isLoading)
                const Center(
                  child: ProgressScreen(
                    isLoading: true,
                    title: 'Creating Encrypted Vault',
                    description:
                        'Connecting to Key Server over Tor.\nThis can take upto a minute.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
