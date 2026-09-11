import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/descriptor_backup_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

class DescriptorBackupPrototypeScreen extends StatefulWidget {
  final List<String> demoXpubs;
  final String? demoDescriptor;
  const DescriptorBackupPrototypeScreen({
    super.key,
    this.demoXpubs = const [],
    this.demoDescriptor,
  });

  @override
  State<DescriptorBackupPrototypeScreen> createState() =>
      _DescriptorBackupPrototypeScreenState();
}

class _DescriptorBackupPrototypeScreenState
    extends State<DescriptorBackupPrototypeScreen>
    with PrivacyScreen, WidgetsBindingObserver {
  var _input = '';
  var _relay = 'wss://nos.lol';
  bool? _copied;
  String? _copiedDescriptor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<DescriptorBackupCubit>().cancel();
    }
  }

  @override
  Widget build(BuildContext context) => BullScaffold(
    body: SafeArea(
      child: BlocBuilder<DescriptorBackupCubit, DescriptorBackupState>(
        builder: (context, state) {
          final cubit = context.read<DescriptorBackupCubit>();
          final result = state.result;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.loc.bip138PrototypeTitle),
                const Gap(12),
                Text(context.loc.bip138PrototypeNotice),
                Text(context.loc.bip138PrototypePublicationNotice),
                const Gap(16),
                BullPasteInput(
                  key: const ValueKey('relay-input'),
                  text: _relay,
                  enabled: !state.busy,
                  onChanged: (value) {
                    cubit.cancel();
                    setState(() {
                      _relay = value;
                      _copiedDescriptor = null;
                    });
                  },
                  hint: context.loc.bip138PrototypeRelay,
                ),
                const Gap(12),
                if (widget.demoDescriptor != null)
                  BullButton.big(
                    label: context.loc.bip138PrototypePublish,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                    disabled: state.busy,
                    onPressed: () =>
                        cubit.publish(widget.demoDescriptor!, _relay),
                  ),
                const Gap(12),
                for (var i = 0; i < widget.demoXpubs.length; i++) ...[
                  BullButton.small(
                    label: [
                      context.loc.bip138PrototypeMobile,
                      context.loc.bip138PrototypeCold,
                      context.loc.bip138PrototypeInheritance,
                    ][i],
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                    disabled: state.busy,
                    onPressed: () {
                      cubit.cancel();
                      setState(() {
                        _input = widget.demoXpubs[i];
                        _copiedDescriptor = null;
                      });
                    },
                  ),
                  const Gap(8),
                ],
                BullPasteInput(
                  key: const ValueKey('xpub-input'),
                  text: _input,
                  enabled: !state.busy,
                  onChanged: (value) {
                    cubit.cancel();
                    setState(() {
                      _input = value;
                      _copiedDescriptor = null;
                    });
                  },
                  hint: context.loc.bip138PrototypeInput,
                ),
                const Gap(12),
                BullButton.big(
                  key: const ValueKey('fetch-descriptor'),
                  label: context.loc.bip138PrototypeFetch,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                  disabled: state.busy || _input.trim().isEmpty,
                  onPressed: () => cubit.fetch(_input, _relay),
                ),
                const Gap(12),
                if (state.busy) ...[
                  Text(context.loc.bip138PrototypeWorking),
                  BullButton.small(
                    label: context.loc.cancelButton,
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                    onPressed: cubit.cancel,
                  ),
                ],
                if (state.published) Text(context.loc.bip138PrototypeAccepted),
                if (state.failure case final failure?)
                  Text(failure.toTranslated(context)),
                if (result != null) ...[
                  if (result.incomplete)
                    Text(context.loc.bip138PrototypeIncomplete),
                  if (result.rejectedEvents > 0)
                    Text(context.loc.bip138PrototypeRejected),
                  if (result.candidates.isEmpty)
                    Text(context.loc.bip138PrototypeEmpty),
                  for (final candidate in result.candidates) ...[
                    Text(context.loc.bip138PrototypeUnverified),
                    const Gap(12),
                    Text(
                      candidate.descriptor,
                      key: const ValueKey('recovered-descriptor'),
                    ),
                    const Gap(12),
                    BullButton.small(
                      label: context.loc.bip138PrototypeCopy,
                      bgColor: context.bull.surface,
                      textColor: context.bull.text,
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: candidate.descriptor),
                          );
                          if (mounted) {
                            setState(() {
                              _copied = true;
                              _copiedDescriptor = candidate.descriptor;
                            });
                          }
                        } on Exception {
                          if (mounted) {
                            setState(() {
                              _copied = false;
                              _copiedDescriptor = candidate.descriptor;
                            });
                          }
                        }
                      },
                    ),
                    if (_copiedDescriptor == candidate.descriptor)
                      Text(
                        _copied!
                            ? context.loc.bip138PrototypeCopied
                            : context.loc.oopsSomethingWentWrong,
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
