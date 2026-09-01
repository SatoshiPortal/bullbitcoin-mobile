import '../../presentation/bloc.dart';
import '../../domain/recoverbull_failure.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import './password_input_page.dart';
import './test_completed_page.dart';
import './view_vault_key_page.dart';
import '../widgets/key_server_status_widget.dart';
import '../../router/flow_type.dart';
import 'package:flutter/material.dart';
import '../../l10n/context_localizations.dart';
import '../support.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            current.decryptedVault != null &&
                previous.decryptedVault != current.decryptedVault ||
            current.vaultKey != null && previous.vaultKey != current.vaultKey ||
            previous.isFlowFinished != current.isFlowFinished,
        listener: (context, state) {
          if (state.failure != null) {
            if (state.failure is ExternalTorProxyUnavailableFailure) {
              final router = GoRouter.of(context);
              context.read<RecoverBullBloc>().add(const OnClearError());
              Navigator.of(context).pop();
              router.pushNamed('torSettings');
              return;
            }
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
            context.read<RecoverBullBloc>().add(const OnClearError());
            Navigator.of(context).pop();
          }
          if (state.flow == RecoverBullFlow.recoverVault &&
              state.isFlowFinished) {
            _hasNavigatedAway = true;
            context.go('/wallet');
            return;
          }
          if (state.flow == RecoverBullFlow.testVault && state.isFlowFinished) {
            if (_hasNavigatedAway) return;
            _hasNavigatedAway = true;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TestCompletedPage(),
              ),
            );
            return;
          }
          if (state.decryptedVault != null && state.vaultKey != null) {
            if (_hasNavigatedAway) return;
            _hasNavigatedAway = true;
            switch (state.flow) {
              case RecoverBullFlow.viewVaultKey:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ViewVaultKeyPage(vaultKey: state.vaultKey!),
                  ),
                );
              case RecoverBullFlow.testVault:
                break;
              case RecoverBullFlow.recoverVault:
                // Recover flow finishes via isFlowFinished above; this branch
                // intentionally no-ops so we don't navigate before persistence.
                break;
              case RecoverBullFlow.secureVault:
                break; // should not fetch anything
              case RecoverBullFlow.settings:
                throw UnimplementedError();
            }
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: state.isLoading
                ? Center(
                    child: ProgressScreen(
                      isLoading: true,
                      title: context.loc.recoverbullFetchingVaultKey,
                      description: context.loc.recoverbullConnectingTor,
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
