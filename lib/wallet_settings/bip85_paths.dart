import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class Bip85PathsPage extends StatelessWidget {
  const Bip85PathsPage({super.key, required this.wallet});

  final String wallet;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: createWalletSettingsCubit(wallet)..loadBIP85Derivations(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'BIP85 Paths',
            onBack: context.pop,
          ),
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletSettingsCubit, WalletSettingsState>(
      listener: (context, state) {
        if (state.errUpdatingBip85Derivations.isNotEmpty) {
          context.showToast(state.errUpdatingBip85Derivations);
        }
      },
      buildWhen: (previous, current) =>
          previous.bip85Derivations.length != current.bip85Derivations.length ||
          current.bip85Derivations.entries.any((entry) {
            final prev = previous.bip85Derivations[entry.key];
            return prev == null ||
                prev.label != entry.value.label ||
                prev.status != entry.value.status;
          }),
      builder: (context, state) {
        final activeBip85Paths = state.bip85Derivations.entries
            .where(
              (entry) => entry.value.status == BIP85DerivationStatus.active,
            )
            .toList();
        final deprecatedBip85Paths = state.bip85Derivations.entries
            .where(
              (entry) => entry.value.status == BIP85DerivationStatus.revoked,
            )
            .toList();

        return state.updatingBip85Derivations
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BBText.body('Active bip85 paths'),
                          const Gap(8),
                          _buildBip85List(context, activeBip85Paths),
                          if (deprecatedBip85Paths.isNotEmpty) ...[
                            const BBText.body('Revoked bip85 paths'),
                            const Gap(8),
                            _buildBip85List(
                              context,
                              deprecatedBip85Paths,
                              isDeprecated: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: ElevatedButton(
                      onPressed: () => _showCreateDialog(context),
                      child: const Text('Create New Derivation Path'),
                    ),
                  ),
                ],
              );
      },
    );
  }

  Widget _buildBip85List(
    BuildContext context,
    List<MapEntry<String, BIP85Derivation>> paths, {
    bool isDeprecated = false,
  }) {
    if (paths.isEmpty) {
      return const Text('No paths available');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = paths[index];
        return InkWell(
          onTap: isDeprecated ? null : () => _showEditDialog(context, entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDeprecated ? Colors.grey : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: isDeprecated ? Colors.grey : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    MapEntry<String, BIP85Derivation> entry,
  ) {
    final labelController = TextEditingController(text: entry.value.label);
    final cubit = context.read<WalletSettingsCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) =>
          BlocConsumer<WalletSettingsCubit, WalletSettingsState>(
        bloc: cubit,
        listener: (context, state) {
          if (!state.updatingBip85Derivations) {
            Navigator.pop(dialogContext);
          }
        },
        builder: (context, state) => AlertDialog(
          title: const BBText.body('Edit Label'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Label',
              floatingLabelStyle: TextStyle(color: Colors.black),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              focusedBorder: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: state.updatingBip85Derivations
                  ? null
                  : () {
                      if (labelController.text.isNotEmpty) {
                        cubit.updateBIP85LabelClicked(
                          entry.key,
                          labelController.text,
                        );
                      }
                    },
              child: state.updatingBip85Derivations
                  ? const CircularProgressIndicator()
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final labelController = TextEditingController();
    final cubit = context.read<WalletSettingsCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) =>
          BlocConsumer<WalletSettingsCubit, WalletSettingsState>(
        bloc: cubit,
        listener: (context, state) {
          if (!state.updatingBip85Derivations) {
            Navigator.pop(dialogContext);
          }
        },
        builder: (context, state) => AlertDialog(
          title: const BBText.body('Create Derivation Path'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Label',
              floatingLabelStyle: TextStyle(color: Colors.black),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              focusedBorder: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: state.updatingBip85Derivations
                  ? null
                  : () {
                      if (labelController.text.isNotEmpty) {
                        cubit.createNewBIP85BackupKeyClicked(
                          labelController.text,
                        );
                      }
                    },
              child: state.updatingBip85Derivations
                  ? const CircularProgressIndicator()
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
