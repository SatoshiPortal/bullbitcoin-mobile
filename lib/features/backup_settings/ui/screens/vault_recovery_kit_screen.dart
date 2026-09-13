import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_kit_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class VaultRecoveryKitScreen extends StatefulWidget {
  final BullVaultPolicy policy;
  final String walletId;
  final VaultRecoveryKitKind kind;
  const VaultRecoveryKitScreen({
    super.key,
    required this.policy,
    required this.walletId,
    required this.kind,
  });

  static String title(BuildContext context, VaultRecoveryKitKind kind) =>
      switch (kind) {
        VaultRecoveryKitKind.mobile => context.loc.bullVaultMobileKit,
        VaultRecoveryKitKind.cold => context.loc.bullVaultColdKit,
        VaultRecoveryKitKind.secondCold => context.loc.bullVaultColdKeyTwo,
        VaultRecoveryKitKind.inheritance => context.loc.bullVaultInheritanceKit,
      };

  @override
  State<VaultRecoveryKitScreen> createState() => _VaultRecoveryKitScreenState();
}

class _VaultRecoveryKitScreenState extends State<VaultRecoveryKitScreen> {
  final _message = TextEditingController();
  int _wordCount = 12;
  bool _sharing = false;
  bool get _inheritance => widget.kind == VaultRecoveryKitKind.inheritance;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VaultRecoveryKitCubit, VaultRecoveryKitState>(
        listener: (context, state) {
          if (state.failure case final failure?) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.toTranslated(context))),
            );
          }
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(VaultRecoveryKitScreen.title(context, widget.kind)),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  context.loc.bullVaultKitInstructions,
                  style: context.font.bodyLarge,
                ),
                const Gap(24),
                Text(
                  _inheritance
                      ? context.loc.bullVaultKitInheritanceHelp
                      : context.loc.bullVaultKitPassphraseHint,
                ),
                const Gap(24),
                if (_inheritance) ...[
                  TextField(
                    controller: _message,
                    maxLength: 1200,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: context.loc.bullVaultKitPersonalMessage,
                    ),
                  ),
                  const Gap(24),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _wordCount,
                  decoration: InputDecoration(
                    labelText: context.loc.bullVaultKitWordCount,
                  ),
                  items: [
                    for (final count in const [12, 15, 18, 21, 24])
                      DropdownMenuItem(value: count, child: Text('$count')),
                  ],
                  onChanged: state.busy || _sharing
                      ? null
                      : (value) => setState(() => _wordCount = value!),
                ),
                const Gap(24),
                Text(context.loc.bullVaultKitRecoveryInstructions),
                const Gap(24),
                Text(context.loc.bullVaultKitTiming),
                if (_inheritance &&
                    widget.policy.lastResortActivationTimestamp != null) ...[
                  const Gap(16),
                  Text(context.loc.bullVaultKitInheritanceWindow),
                ],
                const Gap(32),
                FilledButton(
                  onPressed: state.busy || _sharing ? null : _create,
                  child: state.busy
                      ? const CircularProgressIndicator()
                      : Text(context.loc.bullVaultPrintKit),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _create() async {
    final policy = widget.policy;
    final copy = VaultRecoveryKitCopy(
      title: VaultRecoveryKitScreen.title(context, widget.kind),
      instructions: context.loc.bullVaultKitRecoveryInstructions,
      words: context.loc.bullVaultKitWords,
      passphrase: _inheritance
          ? context.loc.bullVaultKitPassphrase
          : context.loc.bullVaultKitHint,
      dates: context.loc.bullVaultKitDates,
      descriptor: context.loc.bullVaultKitDescriptor,
      joinLines: context.loc.bullVaultKitJoinLines,
      footer:
          '${context.loc.bullVaultKitManualDetails}\n\n${context.loc.bullVaultKitTiming}${_inheritance && policy.lastResortActivationTimestamp != null ? '\n\n${context.loc.bullVaultKitInheritanceWindow}' : ''}',
      schedule: {
        ?policy.coldActivationTimestamp: policy.secondColdKey == null
            ? context.loc.bullVaultColdDelay
            : context.loc.bullVaultEitherColdRecoveryPath,
        ?policy.recoveryActivationTimestamp: policy.inheritanceKey == null
            ? context.loc.bullVaultKitMobileAlone
            : context.loc.bullVaultRecoveryDelay,
        ?policy.inheritanceActivationTimestamp:
            context.loc.bullVaultKitInheritanceAlone,
        ?policy.lastResortActivationTimestamp:
            context.loc.bullVaultKitMobileAlone,
      },
    );
    final bytes = await context.read<VaultRecoveryKitCubit>().create(
      VaultRecoveryKit(
        policy: policy,
        walletId: widget.walletId,
        kind: widget.kind,
        wordCount: _wordCount,
        message: _inheritance ? _message.text : '',
      ),
      copy,
    );
    if (bytes == null || !mounted) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [
            'bullvault-${widget.kind.name}-${policy.id.substring(0, 8)}.pdf',
          ],
          sharePositionOrigin: box != null && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
      // Generating or sharing a template is not a successful recovery test.
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.oopsSomethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
