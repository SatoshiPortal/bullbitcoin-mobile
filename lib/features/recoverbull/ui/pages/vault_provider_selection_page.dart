import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/selectors/recoverbull_vault_provider_selector.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_created_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_selected_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VaultProviderSelectionPage extends StatelessWidget {
  const VaultProviderSelectionPage({super.key});

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

          if (state.vault != null && state.vaultProvider != null) {
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
                    builder:
                        (context) => VaultSelectedPage(
                          provider: state.vaultProvider!,
                          vault: state.vault!,
                          flow: state.flow,
                        ),
                  ),
                );
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              FadingLinearProgress(
                trigger: state.isLoading,
                backgroundColor: context.colour.surface,
                foregroundColor: context.colour.primary,
                height: 2.0,
              ),

              if (state.flow == RecoverBullFlow.secureVault && state.isLoading)
                const Center(
                  child: ProgressScreen(
                    isLoading: true,
                    title: 'Creating Encrypted Vault',
                    description:
                        'Connecting to Key Server over Tor.\nThis can take upto a minute.',
                  ),
                ),

              if (!state.isLoading)
                RecoverbullVaultProviderSelector(
                  onProviderSelected: (provider) {
                    context.read<RecoverBullBloc>().add(
                      OnVaultProviderSelection(provider: provider),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
