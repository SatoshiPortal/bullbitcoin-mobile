// Catalogue use-cases for the bull_ui design system.
//
// Use-cases live HERE in the catalogue app, never in bull_ui — the design
// system stays codegen-free and Widgetbook-free. Each `@widgetbook.UseCase`
// renders one Bull* component; build_runner aggregates them into the generated
// `main.directories.g.dart`.
//
// Many components are wrapped in `_Frame` / sheets so they get a bounded,
// padded canvas. Knobs drive the interesting variants.

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' as m;
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Centres a use-case widget on the active surface with some breathing room.
m.Widget _frame(m.BuildContext context, m.Widget child) {
  return m.ColoredBox(
    color: context.bull.surface,
    child: m.Center(
      child: m.Padding(padding: const m.EdgeInsets.all(16), child: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Theme / foundations
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Default', type: BullIcon)
m.Widget bullIconUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullIcon(
      BullIcons.accountBalanceWallet,
      size: context.knobs.double.slider(
        label: 'size',
        initialValue: 48,
        min: 12,
        max: 96,
      ),
      color: context.bull.primary,
    ),
  );
}

@widgetbook.UseCase(name: 'Type scale', type: BullText)
m.Widget bullTextUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullText(
      context.knobs.string(label: 'text', initialValue: 'The quick brown fox'),
      style: m.Theme.of(context).textTheme.headlineMedium,
      color: context.bull.text,
    ),
  );
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Big', type: BullButton)
m.Widget bullButtonBigUseCase(m.BuildContext context) {
  final disabled = context.knobs.boolean(label: 'disabled');
  final outlined = context.knobs.boolean(label: 'outlined');
  return _frame(
    context,
    BullButton.big(
      label: context.knobs.string(label: 'label', initialValue: 'Continue'),
      onPressed: () {},
      bgColor: context.bull.primary,
      textColor: context.bull.onPrimary,
      iconData: context.knobs.boolean(label: 'with icon')
          ? BullIcons.check
          : null,
      outlined: outlined,
      borderColor: context.bull.border,
      disabled: disabled,
    ),
  );
}

@widgetbook.UseCase(name: 'Small', type: BullButton)
m.Widget bullButtonSmallUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullButton.small(
      label: context.knobs.string(label: 'label', initialValue: 'Action'),
      onPressed: () {},
      bgColor: context.bull.secondary,
      textColor: context.bull.onSecondary,
      disabled: context.knobs.boolean(label: 'disabled'),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullToolButton)
m.Widget bullToolButtonUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullToolButton(
      label: context.knobs.string(label: 'label', initialValue: 'Freeze'),
      icon: BullIcons.acUnit,
      onPressed: () {},
      primary: context.knobs.boolean(label: 'primary'),
      disabled: context.knobs.boolean(label: 'disabled'),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullSyncButton)
m.Widget bullSyncButtonUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullSyncButton(
      label: context.knobs.string(label: 'label', initialValue: 'Sync'),
      syncing: context.knobs.boolean(label: 'syncing', initialValue: true),
      onPressed: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullViewerActionButton)
m.Widget bullViewerActionButtonUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullViewerActionButton(
      icon: BullIcons.contentCopy,
      label: context.knobs.string(label: 'label', initialValue: 'Copy'),
      onTap: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullTabMenuVerticalButton)
m.Widget bullTabMenuVerticalButtonUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullTabMenuVerticalButton(
      icon: BullIcon(BullIcons.accountBalanceWallet, color: context.bull.text),
      title: context.knobs.string(label: 'title', initialValue: 'Wallet'),
      onTap: () {},
    ),
  );
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Default', type: BullScaffold)
m.Widget bullScaffoldUseCase(m.BuildContext context) {
  return BullScaffold(
    body: m.Column(
      children: [
        const BullTopBar(title: 'Bull Scaffold'),
        m.Expanded(
          child: m.Center(
            child: BullText('Body content', style: m.Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullTopBar)
m.Widget bullTopBarUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullTopBar(
        title: context.knobs.string(label: 'title', initialValue: 'Coins'),
        onBack: () {},
        onAction: () {},
        actionIcon: BullIcons.tune,
        actionBadge: context.knobs.boolean(label: 'action badge'),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullSelectionActionBar)
m.Widget bullSelectionActionBarUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullSelectionActionBar(
        summary: context.knobs.string(
          label: 'summary',
          initialValue: '2 selected',
        ),
        actions: [
          BullToolButton(label: 'Freeze', icon: BullIcons.acUnit, onPressed: () {}),
          BullToolButton(label: 'Tag', icon: BullIcons.sell, onPressed: () {}),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Single select', type: BullSegmented)
m.Widget bullSegmentedUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullSegmented(
        items: const {'All', 'Spendable', 'Frozen'},
        initialValue: 'All',
        onSelected: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'With disabled item', type: BullSegmented)
m.Widget bullSegmentedDisabledUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullSegmented(
        items: const {'Bitcoin', 'Lightning', 'Liquid'},
        initialValue: 'Bitcoin',
        disabledItems: const {'Liquid'},
        onSelected: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullSwipeAction)
m.Widget bullSwipeActionUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullSwipeAction(
        actionLabel: 'Freeze',
        actionIcon: BullIcons.acUnit,
        actionColor: context.bull.info,
        onAction: () {},
        enabled: context.knobs.boolean(label: 'enabled', initialValue: true),
        child: BullBorderedTile(
          child: m.Column(
            crossAxisAlignment: m.CrossAxisAlignment.start,
            mainAxisSize: m.MainAxisSize.min,
            children: [
              BullText(
                'Swipe me left',
                style: m.Theme.of(context).textTheme.bodyLarge,
              ),
              const Gap(BullSpacing.xxs),
              BullText(
                'to reveal the Freeze action',
                style: m.Theme.of(context).textTheme.bodySmall,
                color: context.bull.textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'On', type: BullSwitch)
m.Widget bullSwitchOnUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullSwitch(value: true, onChanged: (_) {}),
  );
}

@widgetbook.UseCase(name: 'Off', type: BullSwitch)
m.Widget bullSwitchOffUseCase(m.BuildContext context) {
  final enabled = context.knobs.boolean(label: 'enabled', initialValue: true);
  return _frame(
    context,
    BullSwitch(value: false, onChanged: enabled ? (_) {} : null),
  );
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Checked', type: BullCheckbox)
m.Widget bullCheckboxCheckedUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullCheckbox(checked: true, onChanged: (_) {}),
  );
}

@widgetbook.UseCase(name: 'Unchecked', type: BullCheckbox)
m.Widget bullCheckboxUncheckedUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullCheckbox(
      checked: false,
      disabled: context.knobs.boolean(label: 'disabled'),
      onChanged: (_) {},
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullDialPad)
m.Widget bullDialPadUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullDialPad(
        onNumberPressed: (_) {},
        onBackspacePressed: () {},
        onlyDigits: context.knobs.boolean(label: 'only digits'),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Closed', type: BullDropdown)
m.Widget bullDropdownClosedUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullDropdown<String>(
        label: context.knobs.string(label: 'label', initialValue: 'Network'),
        value: 'Mainnet',
        items: const [
          m.DropdownMenuItem(value: 'Mainnet', child: m.Text('Mainnet')),
          m.DropdownMenuItem(value: 'Testnet', child: m.Text('Testnet')),
          m.DropdownMenuItem(value: 'Signet', child: m.Text('Signet')),
        ],
        onChanged: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Open menu (interact)', type: BullDropdown)
m.Widget bullDropdownOpenUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullDropdown<int>(
        hint: const m.Text('Choose fee priority'),
        value: null,
        items: const [
          m.DropdownMenuItem(value: 1, child: m.Text('Slow')),
          m.DropdownMenuItem(value: 2, child: m.Text('Medium')),
          m.DropdownMenuItem(value: 3, child: m.Text('Fast')),
        ],
        onChanged: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullFilterChip)
m.Widget bullFilterChipUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullFilterChip(
      label: context.knobs.string(label: 'label', initialValue: 'Frozen'),
      onRemove: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullInputText)
m.Widget bullInputTextUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullInputText(
        value: context.knobs.string(label: 'value', initialValue: ''),
        hint: context.knobs.string(label: 'hint', initialValue: 'Enter label'),
        disabled: context.knobs.boolean(label: 'disabled'),
        onChanged: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullPasteInput)
m.Widget bullPasteInputUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullPasteInput(text: '', onChanged: (_) {}),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullSelectableList)
m.Widget bullSelectableListUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullSelectableList(
        selectedValue: 'btc',
        items: const [
          BullSelectableListItem(
            title: 'Bitcoin',
            subtitle1: 'On-chain',
            subtitle2: 'BTC',
            value: 'btc',
          ),
          BullSelectableListItem(
            title: 'Lightning',
            subtitle1: 'Instant',
            subtitle2: 'LN',
            value: 'ln',
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Data display
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Default', type: BullAddressText)
m.Widget bullAddressTextUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullAddressText(
      address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
      onCopied: () {},
      head: context.knobs.int.slider(label: 'head', initialValue: 8, min: 4, max: 16),
      tail: context.knobs.int.slider(label: 'tail', initialValue: 8, min: 4, max: 16),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullBackupOptionCard)
m.Widget bullBackupOptionCardUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullBackupOptionCard(
        icon: BullIcon(BullIcons.accountTree, color: context.bull.text),
        title: context.knobs.string(label: 'title', initialValue: 'Recovery phrase'),
        description: 'Write down 12 words and store them safely.',
        tag: context.knobs.boolean(label: 'with tag', initialValue: true)
            ? 'Recommended'
            : null,
        onTap: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Label', type: BullBadge)
m.Widget bullBadgeUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullBadge(
      label: context.knobs.string(label: 'label', initialValue: 'Frozen'),
      background: context.bull.info.withValues(alpha: 0.15),
      foreground: context.bull.info,
      icon: context.knobs.boolean(label: 'with icon', initialValue: true)
          ? BullIcons.acUnit
          : null,
      uppercase: context.knobs.boolean(label: 'uppercase'),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullBorderedTile)
m.Widget bullBorderedTileUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullBorderedTile(
        onTap: () {},
        child: m.Row(
          children: [
            BullText('Setting row', style: m.Theme.of(context).textTheme.bodyMedium, color: context.bull.text),
            const m.Spacer(),
            BullIcon(BullIcons.chevronRight, color: context.bull.textMuted),
          ],
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullDetailsTable)
m.Widget bullDetailsTableUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: const BullDetailsTable(
        items: [
          BullDetailsTableItem(label: 'Amount', displayValue: '0.0123 BTC'),
          BullDetailsTableItem(label: 'Fee', displayValue: '142 sats'),
          BullDetailsTableItem(
            label: 'Txid',
            displayValue: 'a1b2…f9e8',
            copyValue: 'a1b2c3d4f9e8',
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullInfoBar)
m.Widget bullInfoBarUseCase(m.BuildContext context) {
  final tone = context.knobs.object.dropdown<BullInfoTone>(
    label: 'tone',
    options: BullInfoTone.values,
    labelBuilder: (t) => t.name,
  );
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullInfoBar(
        message: context.knobs.string(
          label: 'message',
          initialValue: 'This UTXO is frozen and will not be spent.',
        ),
        tone: tone,
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullInfoCard)
m.Widget bullInfoCardUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullInfoCard(
        title: context.knobs.string(label: 'title', initialValue: 'Heads up'),
        description: 'Your change output stays on the same keychain.',
        tagColor: context.bull.warning,
        bgColor: context.bull.warning.withValues(alpha: 0.12),
        boldDescription: context.knobs.boolean(label: 'bold description'),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullLabelChip)
m.Widget bullLabelChipUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullLabelChip(
      label: context.knobs.string(label: 'label', initialValue: 'savings'),
      onRemove: context.knobs.boolean(label: 'removable', initialValue: true)
          ? () {}
          : null,
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullOptionsTag)
m.Widget bullOptionsTagUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullOptionsTag(
      text: context.knobs.string(label: 'text', initialValue: 'NEW'),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullPriceCard)
m.Widget bullPriceCardUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullPriceCard(
      text: context.knobs.string(label: 'text', initialValue: '1 BTC = \$98,420'),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullSettingsEntryItem)
m.Widget bullSettingsEntryItemUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 360,
      child: BullSettingsEntryItem(
        icon: BullIcons.tune,
        title: context.knobs.string(label: 'title', initialValue: 'Preferences'),
        isSuperUser: context.knobs.boolean(label: 'super user'),
        onTap: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullStatTile)
m.Widget bullStatTileUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullStatTile(
      label: context.knobs.string(label: 'label', initialValue: 'Balance'),
      value: context.knobs.string(label: 'value', initialValue: '0.5421 BTC'),
      sub: '\$53,210',
      accent: context.bull.success,
    ),
  );
}

@widgetbook.UseCase(name: 'Incoming', type: BullTransactionDirectionBadge)
m.Widget bullTxDirIncomingUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullTransactionDirectionBadge(
      isIncoming: true,
      isSwap: context.knobs.boolean(label: 'is swap'),
    ),
  );
}

@widgetbook.UseCase(name: 'Outgoing', type: BullTransactionDirectionBadge)
m.Widget bullTxDirOutgoingUseCase(m.BuildContext context) {
  return _frame(
    context,
    const BullTransactionDirectionBadge(isIncoming: false),
  );
}

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Counting down', type: BullCountdown)
m.Widget bullCountdownUseCase(m.BuildContext context) {
  final minutes = context.knobs.int.slider(
    label: 'minutes',
    initialValue: 10,
    min: 1,
    max: 60,
  );
  return _frame(
    context,
    BullCountdown(
      until: DateTime.now().add(Duration(minutes: minutes)),
      onTimeout: () {},
      textStyle: m.Theme.of(context).textTheme.headlineLarge?.copyWith(fontFeatures: const [m.FontFeature.tabularFigures()], color: context.bull.text),
    ),
  );
}

@widgetbook.UseCase(name: 'Almost done', type: BullCountdown)
m.Widget bullCountdownShortUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullCountdown(
      until: DateTime.now().add(const Duration(seconds: 30)),
      onTimeout: () {},
      textStyle: m.Theme.of(context).textTheme.headlineLarge?.copyWith(fontFeatures: const [m.FontFeature.tabularFigures()], color: context.bull.warning),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullFadingLinearProgress)
m.Widget bullFadingLinearProgressUseCase(m.BuildContext context) {
  return _frame(
    context,
    m.SizedBox(
      width: 320,
      child: BullFadingLinearProgress(
        trigger: context.knobs.boolean(label: 'trigger', initialValue: true),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullRefreshIndicator)
m.Widget bullRefreshIndicatorUseCase(m.BuildContext context) {
  return BullRefreshIndicator(
    onRefresh: () async {},
    child: m.ListView(
      children: [
        for (var i = 0; i < 12; i++)
          BullBorderedTile(
            child: BullText('Pull to refresh — row $i', style: m.Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Box', type: BullShimmerBox)
m.Widget bullShimmerBoxUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullShimmerBox(
      height: context.knobs.double.slider(
        label: 'height',
        initialValue: 80,
        min: 16,
        max: 200,
      ),
      width: 240,
    ),
  );
}

@widgetbook.UseCase(name: 'Line', type: BullShimmerLine)
m.Widget bullShimmerLineUseCase(m.BuildContext context) {
  return _frame(
    context,
    const m.SizedBox(width: 280, child: BullShimmerLine()),
  );
}

@widgetbook.UseCase(name: 'Show (tap)', type: BullSnackBar)
m.Widget bullSnackBarUseCase(m.BuildContext context) {
  final withAction = context.knobs.boolean(label: 'with action', initialValue: true);
  return _frame(
    context,
    BullButton.big(
      label: 'Show snack bar',
      bgColor: context.bull.secondary,
      textColor: context.bull.onSecondary,
      onPressed: () {
        BullSnackBar.show(
          context,
          message: 'Address copied to clipboard',
          leadingIcon: BullIcons.checkCircle,
          actionLabel: withAction ? 'Undo' : null,
          onAction: withAction ? () {} : null,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Default', type: BullScrollableColumn)
m.Widget bullScrollableColumnUseCase(m.BuildContext context) {
  return BullScrollableColumn(
    spacing: 12,
    children: [
      for (var i = 0; i < 8; i++)
        BullBorderedTile(
          child: BullText('Scrollable row $i', style: m.Theme.of(context).textTheme.bodyMedium),
        ),
    ],
  );
}

@widgetbook.UseCase(name: 'Default', type: BullStackedPage)
m.Widget bullStackedPageUseCase(m.BuildContext context) {
  return BullStackedPage(
    bottomChild: BullButton.big(
      label: 'Confirm',
      bgColor: context.bull.primary,
      textColor: context.bull.onPrimary,
      onPressed: () {},
    ),
    child: m.Center(
      child: BullText('Scrolling content', style: m.Theme.of(context).textTheme.bodyMedium),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BullPullableBody)
m.Widget bullPullableBodyUseCase(m.BuildContext context) {
  return BullPullableBody(
    onRefresh: () async {},
    slivers: [
      m.SliverList.builder(
        itemCount: 10,
        itemBuilder: (_, i) => BullBorderedTile(
          child: BullText('Sliver row $i', style: m.Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Overlays (rendered inline so they show without a launch action)
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Inline', type: BullBottomSheet)
m.Widget bullBottomSheetUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullBottomSheet(
      child: m.Column(
        mainAxisSize: m.MainAxisSize.min,
        children: [
          BullText('Bottom sheet title', style: m.Theme.of(context).textTheme.headlineMedium, color: context.bull.text),
          const Gap(12),
          BullText('Sheet body content goes here.', style: m.Theme.of(context).textTheme.bodyMedium, color: context.bull.textMuted),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Inline', type: BullDialog)
m.Widget bullDialogUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullDialog(
      child: m.Column(
        mainAxisSize: m.MainAxisSize.min,
        children: [
          BullText('Confirm action', style: m.Theme.of(context).textTheme.headlineMedium, color: context.bull.text),
          const Gap(12),
          BullButton.small(
            label: 'OK',
            bgColor: context.bull.primary,
            textColor: context.bull.onPrimary,
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Inline', type: BullInstructionsSheet)
m.Widget bullInstructionsSheetUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullInstructionsSheet(
      title: context.knobs.string(label: 'title', initialValue: 'Before you start'),
      subtitle: 'Follow these steps carefully.',
      instructions: const [
        'Write down your recovery phrase.',
        'Store it somewhere safe and offline.',
        'Never share it with anyone.',
      ],
      onClose: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Inline', type: BullPickerSheet)
m.Widget bullPickerSheetUseCase(m.BuildContext context) {
  return _frame(
    context,
    BullPickerSheet<String>(
      title: 'Choose a network',
      options: const ['Mainnet', 'Testnet', 'Signet'],
      isSelected: (o) => o == 'Mainnet',
      label: (o) => o,
    ),
  );
}
