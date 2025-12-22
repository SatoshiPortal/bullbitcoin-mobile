import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SetCustomServerBottomSheet extends StatefulWidget {
  final String? initialUrl;

  const SetCustomServerBottomSheet({super.key, this.initialUrl});

  @override
  State<SetCustomServerBottomSheet> createState() =>
      _SetCustomServerBottomSheetState();
}

class _SetCustomServerBottomSheetState
    extends State<SetCustomServerBottomSheet> {
  late final TextEditingController _urlController;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            widget.initialUrl == null
                ? context.loc.mempoolCustomServerAdd
                : context.loc.mempoolCustomServerEdit,
            style: context.font.titleLarge,
          ),
          const Gap(8),
          BBText(
            context.loc.mempoolCustomServerBottomSheetDescription,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(24),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: context.loc.mempoolCustomServerUrl,
              hintText: 'mempool.space',
              border: const OutlineInputBorder(),
              prefixText: 'https://',
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          const Gap(24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isValidating
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(context.loc.cancel),
              ),
              const Gap(8),
              ElevatedButton(
                onPressed: _isValidating ? null : _saveServer,
                child: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.loc.save),
              ),
            ],
          ),
          const Gap(16),
        ],
      ),
    );
  }

  Future<void> _saveServer() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.mempoolCustomServerUrlEmpty),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }

    setState(() => _isValidating = true);

    final success =
        await context.read<MempoolSettingsCubit>().setCustomServer(url);

    setState(() => _isValidating = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.mempoolCustomServerSaveSuccess),
          backgroundColor: context.appColors.success,
        ),
      );
    }
  }
}
