import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class NostrKeyFormScreen extends StatefulWidget {
  final KeychainManifestEntry? entry;

  const NostrKeyFormScreen({super.key, this.entry});

  @override
  State<NostrKeyFormScreen> createState() => _NostrKeyFormScreenState();
}

final class _NostrKeyFormScreenState extends State<NostrKeyFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final key = widget.entry?.materializations.singleOrNull;
    _name = TextEditingController(
      text: key is KeychainManifestNostrKey ? key.purpose : null,
    );
    _description = TextEditingController(
      text: key is KeychainManifestNostrKey ? key.description : null,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<NostrKeysCubit>();
    final entry = widget.entry;
    final success = entry == null
        ? await cubit.create(_name.text, description: _description.text)
        : await cubit.update(
            entry: entry,
            name: _name.text,
            description: _description.text,
          );
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NostrKeysCubit, NostrKeysState>(
      builder: (context, state) {
        final error = state.formError;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.entry == null
                  ? context.loc.settingsNostrKeysCreate
                  : context.loc.settingsNostrKeysEditTitle,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                maxLength: KeychainManifestNostrKey.maxPurposeLength,
                onChanged: (_) =>
                    context.read<NostrKeysCubit>().clearFormError(),
                decoration: InputDecoration(
                  labelText: context.loc.settingsNostrKeysName,
                  hintText: context.loc.settingsNostrKeysNameHint,
                  errorText:
                      error == NostrKeyFormError.nameRequired ||
                          error == NostrKeyFormError.nameTooLong ||
                          error == NostrKeyFormError.invalidCharacters
                      ? error!.toTranslated(context)
                      : null,
                ),
              ),
              TextField(
                controller: _description,
                maxLength: KeychainManifestNostrKey.maxDescriptionLength,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) =>
                    context.read<NostrKeysCubit>().clearFormError(),
                decoration: InputDecoration(
                  labelText: context.loc.settingsNostrKeysDescription,
                  hintText: context.loc.settingsNostrKeysDescriptionHint,
                  errorText:
                      error == NostrKeyFormError.descriptionTooLong ||
                          error == NostrKeyFormError.invalidCharacters
                      ? error!.toTranslated(context)
                      : null,
                ),
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
