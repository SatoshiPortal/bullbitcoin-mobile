import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_failure_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInputText, BullSpacing, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NostrKeyFormScreen extends StatefulWidget {
  const NostrKeyFormScreen({super.key});

  @override
  State<NostrKeyFormScreen> createState() => _NostrKeyFormScreenState();
}

class _NostrKeyFormScreenState extends State<NostrKeyFormScreen> {
  String _purpose = '';
  String _description = '';
  bool _submitted = false;

  String? get _validationError {
    if (_purpose.trim().isEmpty) {
      return context.loc.settingsNostrKeysNameRequiredError;
    }
    if (_purpose.trim().length > NostrKeyRecord.maxPurposeLength) {
      return context.loc.settingsNostrKeysNameTooLongError;
    }
    if (_description.trim().length > NostrKeyRecord.maxDescriptionLength) {
      return context.loc.settingsNostrKeysDescriptionTooLongError;
    }
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch('$_purpose$_description')) {
      return context.loc.settingsNostrKeysInvalidCharactersError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NostrKeysCubit, NostrKeysState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(context.loc.settingsNostrKeysCreate)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(BullSpacing.lg),
              children: [
                Text(context.loc.settingsNostrKeysName),
                const Gap(BullSpacing.sm),
                BullInputText(
                  uiKey: const ValueKey('nostr-key-name'),
                  value: _purpose,
                  onChanged: (value) => setState(() => _purpose = value),
                  hint: context.loc.settingsNostrKeysNameHint,
                  maxLength: NostrKeyRecord.maxPurposeLength,
                  disabled: state.creating,
                ),
                const Gap(BullSpacing.lg),
                Text(context.loc.settingsNostrKeysDescription),
                const Gap(BullSpacing.sm),
                BullInputText(
                  uiKey: const ValueKey('nostr-key-description'),
                  value: _description,
                  onChanged: (value) => setState(() => _description = value),
                  hint: context.loc.settingsNostrKeysDescriptionHint,
                  maxLength: NostrKeyRecord.maxDescriptionLength,
                  disabled: state.creating,
                ),
                const Gap(BullSpacing.lg),
                if (_submitted && _validationError != null)
                  Text(
                    _validationError!,
                    style: TextStyle(color: context.appColors.error),
                  ),
                if (state.failure != null)
                  Text(
                    state.failure!.toTranslated(context),
                    style: TextStyle(color: context.appColors.error),
                  ),
                const Gap(BullSpacing.lg),
                BullButton.big(
                  key: const ValueKey('save-nostr-key'),
                  label: context.loc.settingsNostrKeysSave,
                  loading: state.creating,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_validationError != null) return;
    final record = await context.read<NostrKeysCubit>().create(
      purpose: _purpose,
      description: _description,
    );
    if (record != null && mounted) Navigator.of(context).pop(record);
  }
}
