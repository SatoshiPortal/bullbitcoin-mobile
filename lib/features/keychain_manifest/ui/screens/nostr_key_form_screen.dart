import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText;

final class NostrKeyFormScreen extends StatefulWidget {
  const NostrKeyFormScreen({super.key});

  @override
  State<NostrKeyFormScreen> createState() => _NostrKeyFormScreenState();
}

final class _NostrKeyFormScreenState extends State<NostrKeyFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<NostrKeysCubit>();
    final success = await cubit.create(
      _name.text,
      description: _description.text,
    );
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NostrKeysCubit, NostrKeysState>(
      builder: (context, state) {
        final error = state.formError;
        final nameError =
            error == NostrKeyFormError.nameRequired ||
                error == NostrKeyFormError.nameTooLong ||
                error == NostrKeyFormError.invalidNameCharacters
            ? error!.toTranslated(context)
            : null;
        final descriptionError =
            error == NostrKeyFormError.descriptionTooLong ||
                error == NostrKeyFormError.invalidDescriptionCharacters
            ? error!.toTranslated(context)
            : null;
        return Scaffold(
          appBar: AppBar(title: Text(context.loc.settingsNostrKeysCreate)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BullInputText(
                controller: _name,
                value: _name.text,
                maxLength: KeychainManifestNostrKey.maxPurposeLength,
                onChanged: (_) =>
                    context.read<NostrKeysCubit>().clearFormError(),
                label: context.loc.settingsNostrKeysName,
                hint: context.loc.settingsNostrKeysNameHint,
                errorText: nameError,
              ),
              BullInputText(
                controller: _description,
                value: _description.text,
                maxLength: KeychainManifestEntry.maxDescriptionLength,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) =>
                    context.read<NostrKeysCubit>().clearFormError(),
                label: context.loc.settingsNostrKeysDescription,
                hint: context.loc.settingsNostrKeysDescriptionHint,
                errorText: descriptionError,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BBButton.big(
                label: context.loc.settingsNostrKeysSave,
                onPressed: _save,
                disabled: state.busy,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
