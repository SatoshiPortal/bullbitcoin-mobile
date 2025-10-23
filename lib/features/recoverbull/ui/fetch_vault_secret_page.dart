import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/test_completed_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/view_vault_key_page.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FetchVaultSecretPage extends StatefulWidget {
  const FetchVaultSecretPage({super.key});

  @override
  State<FetchVaultSecretPage> createState() => _FetchVaultSecretPageState();
}

class _FetchVaultSecretPageState extends State<FetchVaultSecretPage> {
  bool _hasNavigatedAway = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && _hasNavigatedAway) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fetch Vault Secret')),
      body: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listenWhen:
            (previous, current) =>
                previous.error != current.error ||
                current.decryptedVault != null &&
                    previous.decryptedVault != current.decryptedVault ||
                current.vaultKey != null &&
                    previous.vaultKey != current.vaultKey,
        listener: (context, state) {
          if (state.error != null) {
            SnackBarUtils.showSnackBar(context, state.error!.message);
          }
          if (state.decryptedVault != null && state.vaultKey != null) {
            _hasNavigatedAway = true;
            switch (state.flow) {
              case RecoverBullFlow.viewVaultKey:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ViewVaultKeyPage(vaultKey: state.vaultKey!),
                  ),
                );
              case RecoverBullFlow.testVault:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => TestCompletedPage(state.decryptedVault!),
                  ),
                );
              case RecoverBullFlow.recoverVault:
                context.goNamed(WalletRoute.walletHome.name);
              case RecoverBullFlow.secureVault:
                break; // should not fetch anything
            }
          }
        },
        builder: (context, state) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.isLoading)
                const ProgressScreen(
                  isLoading: true,
                  title: 'Fetching Vault Key',
                  description:
                      'Connecting to Key Server over Tor.\nThis can take upto a minute.',
                ),
            ],
          );
        },
      ),
    );
  }
}
