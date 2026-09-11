import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppLifecycleState;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_cubit.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// This sealed screen owns the short-lived credential controller. Its callbacks
/// never return words to the app or put them in presentation state.
class PortableBackupPrototypeScreen extends StatefulWidget {
  final String network;
  final String? demoMetadataJson;
  final String? demoDescriptor;
  final FutureOr<Result<String, PortableBackupFailure>> Function()?
  deriveDemoWords;

  const PortableBackupPrototypeScreen({
    super.key,
    this.network = 'testnet4',
    this.demoMetadataJson,
    this.demoDescriptor,
    this.deriveDemoWords,
  });

  @override
  State<PortableBackupPrototypeScreen> createState() =>
      _PortableBackupPrototypeScreenState();
}

class _PortableBackupPrototypeScreenState
    extends State<PortableBackupPrototypeScreen>
    with PrivacyScreen, WidgetsBindingObserver {
  final _words = TextEditingController();
  final _file = TextEditingController();
  late final Future<void> _protection;
  late final PortableBackupCubit _cubit;
  var _relay = 'wss://nos.lol';
  var _active = true;
  var _revealed = false;
  var _deriving = false;
  var _generation = 0;
  PortableBackupFailure? _localFailure;
  bool _copied = false;
  bool _copyFailed = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PortableBackupCubit>();
    WidgetsBinding.instance.addObserver(this);
    _protection = _protect();
  }

  Future<void> _protect() async {
    if (!ScreenCaptureProtection.instance.enabledByUser) {
      throw const ScreenCaptureProtectionException();
    }
    await enableScreenPrivacy();
  }

  void _clear() {
    _generation++;
    _words.clear();
    _file.clear();
    _cubit.cancel();
    _revealed = false;
    _deriving = false;
    _localFailure = null;
    _copied = false;
    _copyFailed = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _active = state == AppLifecycleState.resumed;
      if (!_active) _clear();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clear();
    _words.dispose();
    _file.dispose();
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  String _takeWords() {
    final words = _words.text;
    setState(() {
      _generation++;
      _words.clear();
      _revealed = false;
      _localFailure = null;
      _copied = false;
      _copyFailed = false;
    });
    return words;
  }

  Future<void> _derive() async {
    final derive = widget.deriveDemoWords;
    if (derive == null) return;
    _clear();
    final generation = ++_generation;
    setState(() => _deriving = true);
    final result = await derive();
    if (!mounted || !_active || generation != _generation) return;
    setState(() {
      _deriving = false;
      switch (result) {
        case Ok(:final value):
          _words.text = value;
          _revealed = true;
        case Err(:final failure):
          _localFailure = failure;
      }
    });
  }

  Future<void> _copyFile(Uint8List file) async {
    final generation = ++_generation;
    setState(() {
      _copied = false;
      _copyFailed = false;
    });
    try {
      await Clipboard.setData(ClipboardData(text: base64Encode(file)));
      if (mounted && generation == _generation) setState(() => _copied = true);
    } on Exception {
      if (mounted && generation == _generation) {
        setState(() => _copyFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => BullScaffold(
    body: PrivacyGate(
      protection: _protection,
      unprotected: const PrivacyUnavailableNotice(standalone: false),
      builder: (context) {
        if (!_active) return const SizedBox.shrink();
        if (!ScreenCaptureProtection.instance.enabledByUser) {
          return const PrivacyUnavailableNotice(standalone: false);
        }
        return SafeArea(
          child: BlocBuilder<PortableBackupCubit, PortableBackupState>(
            builder: (context, state) {
              final busy = state.busy || _deriving;
              final files = state.files;
              final recovered = state.recovered;
              final failure = _localFailure ?? state.failure;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.loc.portableBackupTitle),
                    const Gap(BullSpacing.sm),
                    Text(context.loc.portableBackupNotice),
                    if (widget.demoDescriptor != null &&
                        widget.demoMetadataJson != null)
                      Text(context.loc.bip138PrototypeNotice),
                    Text(widget.network),
                    const Gap(BullSpacing.md),
                    BullPasteInput(
                      key: const ValueKey('portable-relay'),
                      text: _relay,
                      hint: context.loc.bip138PrototypeRelay,
                      enabled: !busy,
                      onChanged: (value) => setState(() {
                        _clear();
                        _relay = value;
                      }),
                    ),
                    const Gap(BullSpacing.sm),
                    Text(context.loc.portableBackupWords),
                    ExcludeSemantics(
                      child: BullInputText(
                        key: const ValueKey('portable-words'),
                        controller: _words,
                        value: _words.text,
                        disabled: busy,
                        obscure: !_revealed,
                        maxLines: 1,
                        enableSuggestions: false,
                        autocorrect: false,
                        smartQuotesType: SmartQuotesType.disabled,
                        smartDashesType: SmartDashesType.disabled,
                        onChanged: (_) => setState(() {
                          _generation++;
                          _cubit.cancel();
                          _localFailure = null;
                          _copied = false;
                          _copyFailed = false;
                        }),
                      ),
                    ),
                    if (widget.deriveDemoWords != null)
                      _button(
                        context.loc.portableBackupDeriveDemo,
                        _derive,
                        disabled: busy,
                      ),
                    _button(
                      _revealed
                          ? context.loc.portableBackupHideWords
                          : context.loc.portableBackupShowWords,
                      () => setState(() => _revealed = !_revealed),
                      disabled: busy || _words.text.isEmpty,
                    ),
                    _button(
                      context.loc.portableBackupFetch,
                      () => _cubit.fetch(
                        words: _takeWords(),
                        network: widget.network,
                        relay: _relay,
                      ),
                      key: const ValueKey('portable-fetch'),
                      disabled: busy || _words.text.isEmpty,
                    ),
                    if (widget.demoMetadataJson != null &&
                        widget.demoDescriptor != null)
                      _button(
                        context.loc.portableBackupPreparePublish,
                        () => _cubit.prepareAndPublish(
                          words: _takeWords(),
                          metadataJson: widget.demoMetadataJson!,
                          descriptor: widget.demoDescriptor!,
                          network: widget.network,
                          relay: _relay,
                        ),
                        key: const ValueKey('portable-publish'),
                        disabled: busy || _words.text.isEmpty,
                      ),
                    const Gap(BullSpacing.md),
                    Text(context.loc.portableBackupLocalFile),
                    BullInputText(
                      key: const ValueKey('portable-metadata-file'),
                      controller: _file,
                      value: _file.text,
                      disabled: busy,
                      maxLines: 3,
                      enableSuggestions: false,
                      autocorrect: false,
                      onChanged: (_) => setState(() {
                        _generation++;
                        _cubit.cancel();
                        _localFailure = null;
                        _copied = false;
                        _copyFailed = false;
                      }),
                    ),
                    _button(
                      context.loc.portableBackupOpenMetadata,
                      () {
                        final encodedFile = _file.text;
                        _file.clear();
                        unawaited(
                          _cubit.openMetadata(
                            words: _takeWords(),
                            encodedFile: encodedFile,
                            network: widget.network,
                          ),
                        );
                      },
                      key: const ValueKey('portable-open-metadata'),
                      disabled:
                          busy || _words.text.isEmpty || _file.text.isEmpty,
                    ),
                    if (busy) Text(context.loc.bip138PrototypeWorking),
                    if (failure != null) Text(failure.toTranslated(context)),
                    if (state.publishedEventId != null) ...[
                      Text(context.loc.portableBackupPublished),
                      Text(
                        state.publishedEventId!,
                        key: const ValueKey('portable-published-event'),
                      ),
                    ],
                    if (files != null) ...[
                      _button(
                        context.loc.portableBackupCopyMetadata,
                        () => _copyFile(files.metadata),
                      ),
                      _button(
                        context.loc.portableBackupCopyVault,
                        () => _copyFile(files.vault),
                      ),
                    ],
                    if (_copied) Text(context.loc.portableBackupCopied),
                    if (_copyFailed) Text(context.loc.oopsSomethingWentWrong),
                    if (state.metadataOpened)
                      Text(
                        context.loc.portableBackupMetadataOpened,
                        key: const ValueKey('portable-metadata-opened'),
                      ),
                    if (recovered != null) ...[
                      if (recovered.incomplete)
                        Text(context.loc.bip138PrototypeIncomplete),
                      if (recovered.rejectedEvents > 0)
                        Text(context.loc.bip138PrototypeRejected),
                      if (recovered.candidates.isEmpty)
                        Text(context.loc.portableBackupEmpty),
                      for (final candidate in recovered.candidates) ...[
                        Text(context.loc.portableBackupRecovered),
                        ExcludeSemantics(
                          child: Text(
                            candidate.artifact.contents,
                            key: ValueKey(
                              'portable-descriptor-${candidate.eventId}',
                            ),
                          ),
                        ),
                        _button(
                          context.loc.portableBackupCopyVault,
                          () => _copyFile(candidate.encryptedFile),
                        ),
                      ],
                    ],
                    _button(
                      context.loc.portableBackupClear,
                      () => setState(_clear),
                      key: const ValueKey('portable-clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );

  Widget _button(
    String label,
    VoidCallback onPressed, {
    Key? key,
    bool disabled = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.sm),
    child: BullButton.big(
      key: key,
      label: label,
      onPressed: onPressed,
      disabled: disabled,
      bgColor: context.bull.primary,
      textColor: context.bull.onPrimary,
    ),
  );
}
