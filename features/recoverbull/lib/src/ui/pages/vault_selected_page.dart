import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/drive_file_metadata.dart';
import '../../domain/entities/vault_provider.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../widgets/recoverbull_widgets.dart';
import 'password_input_page.dart';

/// The vault about to be decrypted, with access to the other Drive vaults.
class VaultSelectedPage extends StatelessWidget {
  final VaultProvider provider;
  final bool vaultKeyOnly;

  const VaultSelectedPage({
    super.key,
    required this.provider,
    this.vaultKeyOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RecoverBullAppBar(title: context.loc.recoverbullVaultSelected),
      body: BlocBuilder<VaultFlowCubit, VaultFlowState>(
        builder: (context, state) {
          final vault = state.vault;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                BullText(
                  context.loc.recoverbullVaultImportedSuccess,
                  textAlign: .left,
                  style: context.bullType.label.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Gap(16),
                if (vault != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.bull.onSurface),
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BullText(
                          vault.id,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Gap(16),
                        BullText(
                          DateFormat('yyyy-MMM-dd, HH:mm:ss')
                              .format(vault.createdAt.toLocal()),
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (provider == VaultProvider.googleDrive) ...[
                  BullButton.big(
                    label: context.loc.recoverbullSeeMoreVaults,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DriveVaultsListPage(),
                      ),
                    ),
                    bgColor: context.bull.transparent,
                    textColor: context.bull.onSurface,
                    outlined: true,
                  ),
                  const Gap(16),
                ],
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.05,
                  ),
                  child: BullButton.big(
                    label: context.loc.recoverbullDecryptVault,
                    disabled: vault == null || state.busy,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PasswordInputPage(vaultKeyOnly: vaultKeyOnly),
                      ),
                    ),
                    bgColor: context.bull.onSurface,
                    textColor: context.bull.surface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Every vault found on Google Drive; tap to choose, long-press to export or delete.
class DriveVaultsListPage extends StatefulWidget {
  const DriveVaultsListPage({super.key});

  @override
  State<DriveVaultsListPage> createState() => _DriveVaultsListPageState();
}

class _DriveVaultsListPageState extends State<DriveVaultsListPage> {
  List<DriveFileMetadata> _files = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final cubit = context.read<VaultFlowCubit>();
    await cubit.list();
    if (!mounted) return;
    final files = cubit.state.files;
    // A list skipped while another operation ran says nothing about Drive.
    if (files == null) return;
    setState(() {
      _files = [...files]
        ..sort((a, b) => b.createdTime.compareTo(a.createdTime));
      _loaded = true;
    });
  }

  Future<void> _select(DriveFileMetadata file) async {
    final cubit = context.read<VaultFlowCubit>();
    final before = cubit.state.vault;
    await cubit.select(file);
    if (!mounted) return;
    if (cubit.state.vault != null && cubit.state.vault != before) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(DriveFileMetadata file) async {
    await context.read<VaultFlowCubit>().delete(file);
    if (mounted) await _refresh();
  }

  void _showActions(DriveFileMetadata file) {
    final cubit = context.read<VaultFlowCubit>();
    unawaited(
      BullBottomSheet.show<void>(
        context: context,
        child: _SheetFrame(
          heightFactor: 0.4,
          child: Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              Builder(
                builder: (sheet) => BullButton.small(
                  label: sheet.loc.recoverbullGoogleDriveExportButton,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    unawaited(cubit.export(file));
                  },
                  bgColor: sheet.bull.secondary,
                  textColor: sheet.bull.onSecondary,
                ),
              ),
              Builder(
                builder: (sheet) => BullButton.small(
                  label: sheet.loc.recoverbullGoogleDriveDeleteButton,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    _confirmDelete(file);
                  },
                  bgColor: sheet.bull.primary,
                  textColor: sheet.bull.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DriveFileMetadata file) {
    unawaited(
      BullBottomSheet.show<void>(
        context: context,
        child: Builder(
          builder: (sheet) => _SheetFrame(
            heightFactor: 0.5,
            child: Column(
              mainAxisSize: .min,
              children: [
                BullText(
                  sheet.loc.recoverbullGoogleDriveDeleteVaultTitle,
                  style: sheet.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(16),
                BullText(
                  sheet.loc.recoverbullGoogleDriveDeleteConfirmation,
                  style: sheet.bullType.body,
                  textAlign: .center,
                ),
                const Gap(24),
                Row(
                  mainAxisAlignment: .spaceEvenly,
                  children: [
                    BullButton.small(
                      label: sheet.loc.recoverbullGoogleDriveCancelButton,
                      onPressed: () => Navigator.of(sheet).pop(),
                      bgColor: sheet.bull.secondary,
                      textColor: sheet.bull.onSecondary,
                    ),
                    BullButton.small(
                      label: sheet.loc.recoverbullGoogleDriveDeleteButton,
                      onPressed: () {
                        Navigator.of(sheet).pop();
                        unawaited(_delete(file));
                      },
                      bgColor: sheet.bull.primary,
                      textColor: sheet.bull.onPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultFlowCubit, VaultFlowState>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        final failure = state.failure;
        if (failure == null) return;
        if (failure is! VaultCancelledFailure) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
        context.read<VaultFlowCubit>().clearFailure();
      },
      builder: (context, state) => Scaffold(
        appBar: RecoverBullAppBar(
          title: context.loc.recoverbullGoogleDriveScreenTitle,
          showKeyServer: false,
        ),
        body: Column(
          children: [
            BullFadingLinearProgress(
              trigger: state.busy,
              backgroundColor: context.bull.surface,
              foregroundColor: context.bull.primary,
              height: 2,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_loaded && !state.busy && _files.isEmpty)
                        Center(
                          child: BullText(
                            context.loc.recoverbullGoogleDriveNoBackupsFound,
                            style: context.bullType.body,
                          ),
                        ),
                      for (final file in _files)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: BullText(
                              '${DateFormat('MMM dd, yyyy • HH:mm').format(file.createdTime.toLocal())} • ${file.name}',
                              style: context.bullType.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: .ellipsis,
                            ),
                            onTap: () => _select(file),
                            onLongPress: () => _showActions(file),
                            enabled: !state.busy,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final double heightFactor;
  final Widget child;

  const _SheetFrame({required this.heightFactor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * heightFactor,
      ),
      decoration: BoxDecoration(
        color: context.bull.onSecondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.bullShapes.sheet),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: child,
      ),
    );
  }
}
