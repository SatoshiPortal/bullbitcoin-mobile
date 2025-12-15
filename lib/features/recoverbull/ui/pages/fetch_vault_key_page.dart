import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core_deprecated/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/test_completed_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_recovery_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FetchVaultKeyPage extends StatefulWidget {
  final String input;
  final InputType inputType;

  const FetchVaultKeyPage({
    super.key,
    required this.input,
    required this.inputType,
  });

  @override
  State<FetchVaultKeyPage> createState() => _FetchVaultKeyPageState();
}

class _FetchVaultKeyPageState extends State<FetchVaultKeyPage> {
  bool _hasNavigatedAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        switch (widget.inputType) {
          case InputType.pin || InputType.password:
            context.read<RecoverBullBloc>().add(
              OnVaultPasswordSet(password: widget.input),
            );
          case InputType.vaultKey:
            context.read<RecoverBullBloc>().add(
              OnVaultDecryption(vaultKey: widget.input),
            );
        }
      }
    });
  }

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
      appBar: AppBar(
        title: Text(context.loc.recoverbullFetchVaultKey),
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
                current.decryptedVault != null &&
                    previous.decryptedVault != current.decryptedVault ||
                current.vaultKey != null &&
                    previous.vaultKey != current.vaultKey,
        listener: (context, state) {
          if (state.error != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.error!.toTranslated(context),
            );
            context.read<RecoverBullBloc>().add(const OnClearError());
            Navigator.of(context).pop();
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
                    builder: (context) => const TestCompletedPage(),
                  ),
                );
              case RecoverBullFlow.recoverVault:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VaultRecoveryPage(),
                  ),
                );
              case RecoverBullFlow.secureVault:
                break; // should not fetch anything
              case RecoverBullFlow.settings:
                throw UnimplementedError();
            }
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: .start,
                  children: [
                    if (state.isLoading)
                      ProgressScreen(
                        isLoading: true,
                        title: context.loc.recoverbullFetchingVaultKey,
                        description: context.loc.recoverbullConnectingTor,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
