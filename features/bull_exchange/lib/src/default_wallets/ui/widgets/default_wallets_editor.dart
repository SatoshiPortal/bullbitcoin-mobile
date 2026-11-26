import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../default_wallets_payout_fields.dart';
import '../../domain/validate_default_wallet_destination_usecase.dart';
import '../../presentation/default_wallets_bloc.dart';
import '../../presentation/default_wallets_failure_l10n.dart';
import '../../presentation/default_wallets_machine.dart';

typedef DefaultWalletsFooterBuilder = Widget Function(
  BuildContext context,
  DefaultWallets wallets,
  ({bool isLoading, bool isSaving, bool isEditing}) status,
);

class DefaultWalletsEditor extends StatelessWidget {
  final Exchange exchange;
  final DefaultWalletsPayoutFields payoutFields;
  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
  final DefaultWalletsFooterBuilder? footerBuilder;

  const DefaultWalletsEditor({
    required this.exchange,
    required this.payoutFields,
    this.showDescription,
    this.padding,
    this.footerBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DefaultWalletsBloc(
      exchange: exchange,
      validateDestination: ValidateDefaultWalletDestinationUsecase(
        payoutFields.validate,
      ),
    ),
    child: _SlotNotices(
      child: _EditorContent(
        payoutFields: payoutFields,
        showDescription: showDescription,
        padding: padding,
        footerBuilder: footerBuilder,
      ),
    ),
  );
}

/// Shows a slot's notice once, when the slot enters it.
class _SlotNotices extends StatefulWidget {
  final Widget child;

  const _SlotNotices({required this.child});

  @override
  State<_SlotNotices> createState() => _SlotNoticesState();
}

class _SlotNoticesState extends State<_SlotNotices> {
  late DefaultWalletsState _last = context.read<DefaultWalletsBloc>().state;

  @override
  Widget build(BuildContext context) =>
      BlocListener<DefaultWalletsBloc, DefaultWalletsState>(
        listener: (context, state) {
          final entered = _entered(_last, state);
          _last = state;
          for (final notice in entered) {
            BullSnackBar.show(context, message: _noticeText(context, notice));
          }
        },
        child: widget.child,
      );

  static List<SlotNotice> _entered(
    DefaultWalletsState previous,
    DefaultWalletsState current,
  ) {
    if (current is! WalletsReady) return const [];
    final before = previous is WalletsReady ? previous.slots : null;
    return [
      for (final network in BtcNetwork.values)
        if (current.slots.of(network) case SlotShowing(:final notice?)
            when before?.of(network) != current.slots.of(network))
          notice,
    ];
  }

  static String _noticeText(BuildContext context, SlotNotice notice) =>
      switch (notice) {
        SlotNoticeSaved() => context.loc.exchangeBitcoinWalletsSaveSuccess,
        SlotNoticeUnset() => context.loc.exchangeBitcoinWalletsUnsetSuccess,
        SlotNoticeFailed(:final failure) => failure.toTranslated(context),
      };
}

class _EditorContent extends StatelessWidget {
  static const _defaultPadding = EdgeInsets.all(16);

  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
  final DefaultWalletsFooterBuilder? footerBuilder;
  final DefaultWalletsPayoutFields payoutFields;

  const _EditorContent({
    required this.payoutFields,
    required this.showDescription,
    required this.padding,
    required this.footerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DefaultWalletsBloc>().state;
    return switch (state) {
      WalletsLoading() => Column(
        children: [
          LinearProgressIndicator(
            backgroundColor: context.appColors.surface,
            color: context.appColors.primary,
          ),
          const Spacer(),
        ],
      ),
      WalletsLoadFailed() => _Message(
        text: context.loc.exchangeBitcoinWalletsLoadFailed,
        action: (
          label: context.loc.retry,
          onPressed: () => context.read<DefaultWalletsBloc>().add(
            const WalletsRetryPressed(),
          ),
        ),
      ),
      WalletsSessionEnded() => _Message(
        text: context.loc.exchangeBitcoinWalletsSessionEnded,
      ),
      final WalletsReady ready => _ready(context, ready),
    };
  }

  Widget _ready(BuildContext context, WalletsReady ready) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: padding ?? _defaultPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDescription ?? true) ...[
              BullText(
                context.loc.exchangeBitcoinWalletsDescription,
                style: context.bullType.body.copyWith(
                  color: context.appColors.outline,
                ),
              ),
              const SizedBox(height: 24),
            ],
            _WalletAddressField(
              payoutFields: payoutFields,
              ready: ready,
              type: BtcNetwork.bitcoin,
              label: context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
            ),
            const SizedBox(height: 24),
            _WalletAddressField(
              payoutFields: payoutFields,
              ready: ready,
              type: BtcNetwork.lightning,
              label: context.loc.exchangeBitcoinWalletsLightningAddressLabel,
            ),
            const SizedBox(height: 24),
            _WalletAddressField(
              payoutFields: payoutFields,
              ready: ready,
              type: BtcNetwork.liquid,
              label: context.loc.exchangeBitcoinWalletsLiquidAddressLabel,
            ),
            if (footerBuilder case final builder?) ...[
              const SizedBox(height: 24),
              builder(context, ready.saved, (
                isLoading: false,
                isSaving: ready.slots.mutating,
                isEditing: BtcNetwork.values.any(
                  (n) => ready.slots.of(n) is! SlotShowing,
                ),
              )),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  final String text;
  final ({String label, VoidCallback onPressed})? action;

  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BullText(
            text,
            style: context.bullType.body.copyWith(
              color: context.appColors.error,
            ),
          ),
          if (action case final action?) ...[
            const SizedBox(height: 16),
            BullButton.secondary(
              label: action.label,
              onPressed: action.onPressed,
            ),
          ],
        ],
      ),
    ),
  );
}

class _WalletAddressField extends StatefulWidget {
  final BtcNetwork type;
  final String label;
  final WalletsReady ready;
  final DefaultWalletsPayoutFields payoutFields;

  const _WalletAddressField({
    required this.type,
    required this.label,
    required this.ready,
    required this.payoutFields,
  });

  @override
  State<_WalletAddressField> createState() => _WalletAddressFieldState();
}

class _WalletAddressFieldState extends State<_WalletAddressField> {
  bool _isValid = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final ready = widget.ready;
    final slot = ready.slots.of(type);
    final bloc = context.read<DefaultWalletsBloc>();
    final savedAddress = ready.saved.getWallet(type)?.address ?? '';
    final value = switch (slot) {
      SlotShowing() || SlotUnsetting() => savedAddress,
      SlotEditing(:final draft) ||
      SlotChecking(:final draft) ||
      SlotSaving(:final draft) => draft,
      SlotVerifying(:final intent) ||
      SlotUnverified(:final intent) => switch (intent) {
        SlotSaveIntent(:final draft) => draft,
        SlotUnsetIntent() => savedAddress,
      },
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: BullText(
                widget.label,
                style: context.bullType.body.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
            ),
            if (savedAddress.isNotEmpty && slot is SlotShowing)
              BullButton.secondary(
                label: context.loc.delete,
                onPressed: ready.slots.mutating
                    ? null
                    : () => bloc.add(SlotUnsetPressed(type)),
                size: BullButtonSize.small,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 8),
        widget.payoutFields.buildField(
          type: type,
          value: value,
          hint: context.loc.exchangeBitcoinWalletsEnterAddressHint,
          enabled: !slotMutating(slot),
          onChanged: (text) {
            setState(() => _isValid = false);
            bloc.add(SlotTyped(type, text));
          },
          onValidationChanged: (isValid) {
            if (_isValid != isValid) setState(() => _isValid = isValid);
          },
        ),
        ...switch (slot) {
          SlotShowing() => const [],
          SlotEditing(:final problem) => [
            if (problem != null) ...[
              const SizedBox(height: 8),
              BullText(
                problem.toTranslated(context),
                style: context.bullType.caption.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _editButtons(
              context,
              onCancel: () => bloc.add(SlotCancelPressed(type)),
              onSave: _isValid && !ready.slots.mutating
                  ? () => bloc.add(SlotSavePressed(type))
                  : null,
            ),
          ],
          SlotChecking() || SlotSaving() => [
            const SizedBox(height: 12),
            _editButtons(context, onCancel: null, onSave: null, busy: true),
          ],
          SlotUnsetting() || SlotVerifying() => [
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: context.appColors.surface,
              color: context.appColors.primary,
            ),
          ],
          SlotUnverified(:final intent) => [
            const SizedBox(height: 8),
            BullText(
              switch (intent) {
                SlotSaveIntent() =>
                  context.loc.exchangeBitcoinWalletsSaveOutcomeUnknown,
                SlotUnsetIntent() =>
                  context.loc.exchangeBitcoinWalletsUnsetOutcomeUnknown,
              },
              style: context.bullType.caption.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 12),
            BullButton.secondary(
              label: context.loc.exchangeBitcoinWalletsCheckAgain,
              onPressed: () => bloc.add(SlotVerifyRetryPressed(type)),
            ),
          ],
        },
      ],
    );
  }

  Widget _editButtons(
    BuildContext context, {
    required VoidCallback? onCancel,
    required VoidCallback? onSave,
    bool busy = false,
  }) => Row(
    children: [
      Expanded(
        child: BullButton.secondary(
          label: context.loc.cancel,
          onPressed: onCancel,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: busy
            ? Container(
                height: 52,
                decoration: BoxDecoration(
                  color: context.appColors.onSurface,
                  borderRadius: BorderRadius.circular(
                    context.bullShapes.button,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.surface,
                    ),
                  ),
                ),
              )
            : BullButton.primary(label: context.loc.save, onPressed: onSave),
      ),
    ],
  );
}
