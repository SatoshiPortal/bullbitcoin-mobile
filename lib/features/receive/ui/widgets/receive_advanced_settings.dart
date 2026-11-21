import 'package:bb_mobile/features/receive/domain/receive_advanced_options.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:labels/labels.dart';
import 'package:label_editor/label_editor.dart';
import 'package:primitives/primitives.dart' show StringFormatting;
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_payjoin_toggle_button.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveAdvancedSettingsLink extends StatelessWidget {
  const ReceiveAdvancedSettingsLink({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final summary = state.advancedOptions.summary
        .map(
          (part) => switch (part) {
            ReceiveAdvancedSummaryPart.wallet =>
              state.wallet?.displayLabel(context) ?? '',
            ReceiveAdvancedSummaryPart.payjoin => context.loc.receivePayjoinOn,
            ReceiveAdvancedSummaryPart.message => context.loc.receiveMessage,
          },
        )
        .where((item) => item.isNotEmpty)
        .join(' · ');
    return BullSettingsEntryTile(
      label: context.loc.receiveAdvancedSettings,
      summary: summary,
      onPressed: () => ReceiveAdvancedSettings.show(context),
    );
  }
}

class ReceiveAdvancedSettings extends StatefulWidget {
  const ReceiveAdvancedSettings({super.key});

  static Future<void> show(BuildContext context) async {
    final bloc = context.read<ReceiveBloc>();
    await BullBottomSheet.show<void>(
      context: context,
      avoidKeyboard: true,
      child: BlocProvider.value(
        value: bloc,
        child: const ReceiveAdvancedSettings(),
      ),
    );
    if (!bloc.isClosed) bloc.add(const ReceiveNoteSaved());
  }

  @override
  State<ReceiveAdvancedSettings> createState() =>
      _ReceiveAdvancedSettingsState();
}

class _ReceiveAdvancedSettingsState extends State<ReceiveAdvancedSettings> {
  late final TextEditingController _message;
  Set<String> _suggestions = {};
  String? _messageError;
  final _messageFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ReceiveBloc>();
    _message = TextEditingController(text: bloc.state.note);
    bloc.fetchDistinctLabels().then((suggestions) {
      if (mounted) setState(() => _suggestions = suggestions);
    });
    _messageFocus.addListener(() {
      if (!_messageFocus.hasFocus && mounted) {
        context.read<ReceiveBloc>().add(const ReceiveNoteSaved());
      }
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final violation = NoteValidator.validate(value ?? '');
    return violation == null
        ? null
        : mapNoteViolationToLabelFailure(violation).toTranslated(context);
  }

  void _changeMessage(String value) {
    setState(() => _messageError = _validate(value));
    if (_messageError == null) {
      context.read<ReceiveBloc>().add(ReceiveNoteChanged(value));
    }
  }

  Widget _section(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        BullIcon(icon),
        const Gap(16),
        Text(
          title,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  Future<void> _pickWallet(ReceiveState state) async {
    final bloc = context.read<ReceiveBloc>();
    await BullBottomSheet.show<void>(
      context: context,
      child: BullPickerSheet(
        title: context.loc.receiveInto,
        options: state.wallets,
        isSelected: (wallet) => wallet.id == state.wallet?.id,
        label: (wallet) => wallet.displayLabel(context),
        onSelected: (sheetContext, wallet) {
          Navigator.of(sheetContext).pop();
          if (!bloc.isClosed && bloc.state.type == ReceiveType.bitcoin) {
            bloc.add(ReceiveBitcoinStarted(wallet));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final wallet = state.wallet;
    final messageReadOnly = state.creatingSwap;
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) => previous.note != current.note,
      listener: (context, next) {
        if (!_messageFocus.hasFocus && _message.text != next.note) {
          _message.text = next.note;
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullTopBar(
              title: context.loc.receiveAdvancedSettings,
              onAction: () => Navigator.of(context).pop(),
            ),
            if (state.advancedOptions.showWalletPicker) ...[
              _section(BullIcons.accountBalanceWallet, context.loc.receiveInto),
              if (wallet != null)
                BullBorderedTile(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                  backgroundColor: context.appColors.surface,
                  onTap: () => _pickWallet(state),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        color: wallet.signsLocally
                            ? context.appColors.onTertiary
                            : context.appColors.secondary,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          wallet.displayLabel(context),
                          style: context.bullType.body,
                        ),
                      ),
                      const Gap(8),
                      BullFieldAction(
                        label: context.loc.receiveInto,
                        icon: BullIcons.expandMore,
                        onPressed: () => _pickWallet(state),
                      ),
                    ],
                  ),
                ),
              const Gap(16),
            ],
            _section(
              BullIcons.chatBubbleOutline,
              context.loc.receiveRecipientMessage,
            ),
            BullInputText(
              controller: _message,
              focusNode: _messageFocus,
              value: _message.text,
              onChanged: _changeMessage,
              disabled: messageReadOnly,
              hint: context.loc.receiveRecipientMessageHint,
            ),
            if (_messageError case final error?)
              Text(
                error,
                style: context.bullType.label.copyWith(
                  color: context.appColors.error,
                ),
              ),
            if (!messageReadOnly)
              Wrap(
                spacing: 8,
                children: [
                  for (final suggestion in _suggestions)
                    BullInlineTextButton(
                      child: Text(suggestion),
                      onPressed: () {
                        _message.text = suggestion;
                        _changeMessage(suggestion);
                      },
                    ),
                ],
              ),
            const Gap(12),
            if (state.advancedOptions.showPayjoin) ...[
              const ReceivePayjoinToggleTile(topGap: 0),
              BullSettingsEntryItem(
                icon: BullIcons.settings,
                contentPadding: EdgeInsets.zero,
                title: context.loc.receivePayjoinSettings,
                onTap: () =>
                    context.pushNamed(SettingsRoute.payjoinSettings.name),
              ),
            ],
            if (state.advancedOptions.showNewAddress) ...[
              BullSettingsEntryItem(
                icon: BullIcons.sync,
                contentPadding: EdgeInsets.zero,
                title: context.loc.receiveNewAddress,
                trailing: const SizedBox.shrink(),
                subtitle: StringFormatting.truncateMiddle(
                  state.addressOrInvoiceOnly,
                ),
                onTap: () {
                  context.read<ReceiveBloc>().add(
                    const ReceiveNewAddressGenerated(),
                  );
                  BullSnackBar.show(
                    context,
                    message: context.loc.receiveNewAddress,
                  );
                },
              ),
              if (state.advancedOptions.showHardwareVerification &&
                  wallet?.signerDevice?.isLedger == true)
                const VerifyAddressOnLedgerButton(),
              if (state.advancedOptions.showHardwareVerification &&
                  wallet?.signerDevice?.isBitBox == true)
                const VerifyAddressOnBitBoxButton(),
            ],
          ],
        ),
      ),
    );
  }
}
