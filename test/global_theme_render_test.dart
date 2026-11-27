import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final type in AppThemeType.values) {
    for (final name in [
      'BullAmountInput',
      'BullBorderedTile',
      'BullCopyField',
      'BullPasteInput',
      'BullInputText',
      'BullSecretTextInput',
      'BullSearchBar',
      'BullDropdown',
      'BullPaymentDestinationInput',
      'BullPinDots',
      'BullServerTile',
      'BullFieldAction',
      'BullSegmented',
      'BullBottomSheet',
      'BullPickerSheet',
      'BullInstructionsSheet',
      'BullDialog',
      'MaterialBottomSheet',
      'MaterialFields',
    ]) {
      testWidgets('global $name ${type.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = TextEditingController(text: '25000');
        addTearDown(controller.dispose);
        Widget content(BuildContext context) => switch (name) {
          'BullAmountInput' => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BullAmountInput(
                amountController: controller,
                canonicalUnit: BitcoinUnit.sats,
                framed: true,
                inCard: true,
              ),
              const Gap(24),
              BullAmountInput(
                amountController: controller,
                canonicalUnit: BitcoinUnit.sats,
                compact: true,
              ),
            ],
          ),
          'BullBorderedTile' => const BullBorderedTile(
            child: Text('Public destination'),
          ),
          'BullCopyField' => const BullCopyField(
            text: 'Public reference',
            copiedMessage: 'Copied',
          ),
          'BullPasteInput' => BullPasteInput(
            text: 'Public reference',
            onChanged: (_) {},
          ),
          'BullInputText' => BullInputText(
            value: 'Public label',
            onChanged: (_) {},
            rightIcon: const Icon(Icons.edit),
            onRightTap: () {},
            rightActionLabel: 'Edit label',
          ),
          'BullSecretTextInput' => BullSecretTextInput(
            label: 'Empty private field',
            hint: 'No secret data',
            showLabel: 'Show',
            hideLabel: 'Hide',
            onChanged: (_) {},
          ),
          'BullSearchBar' => BullSearchBar(
            hint: 'Search',
            value: 'Public query',
            onChanged: (_) {},
            onCleared: () {},
            clearTooltip: 'Clear',
          ),
          'BullDropdown' => BullDropdown<String>(
            items: const [
              BullPickerItem(value: 'BTC', label: 'Bitcoin'),
              BullPickerItem(value: 'CAD', label: 'Canadian dollar'),
            ],
            value: 'BTC',
            onChanged: (_) {},
          ),
          'BullPaymentDestinationInput' => BullPaymentDestinationInput(
            value: 'Public destination',
            validAddress: const Text('Public destination'),
            onChanged: (_) {},
            label: 'To',
            hint: 'Destination',
            pasteLabel: 'Paste',
            scanLabel: 'Scan',
            clearLabel: 'Clear',
            onPaste: () {},
            onScan: () {},
            onClear: () {},
            onRemove: () {},
            removeLabel: 'Remove',
          ),
          'BullPinDots' => BullPinDots(
            value: '',
            obscure: true,
            onToggleObscure: () {},
            showLabel: 'Show',
            hideLabel: 'Hide',
            hint: 'Empty field; no private data',
          ),
          'BullServerTile' => BullServerTile(
            title: 'Public server',
            statusColor: context.bull.success,
            statusLabel: 'Connected',
            badgeLabel: 'Active',
            onDelete: () {},
            deleteTooltip: 'Remove server',
          ),
          'BullFieldAction' => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              BullFieldAction(label: 'MAX', onPressed: () {}),
              BullFieldAction(
                label: 'Edit',
                icon: BullIcons.edit,
                onPressed: () {},
              ),
              const BullFieldAction(
                label: 'Disabled',
                icon: Icons.lock,
                onPressed: null,
              ),
            ],
          ),
          'BullSegmented' => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BullSegmented(
                items: const {'Fast', 'Economy', 'Slow', 'Custom'},
                initialValue: 'Fast',
                onSelected: (_) {},
              ),
              const Gap(24),
              BullSegmented(
                items: const {'Rate (sat/vB)', 'Total (sats)'},
                initialValue: 'Rate (sat/vB)',
                onSelected: (_) {},
              ),
            ],
          ),
          'MaterialFields' => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Public label')),
              Gap(24),
              TextField(
                decoration: InputDecoration(labelText: 'Disabled label'),
                enabled: false,
              ),
            ],
          ),
          _ => BullButton.secondary(
            label: 'Open preview',
            onPressed: () {
              final child = Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Public sheet content',
                      style: context.bullType.subtitle,
                    ),
                    const Gap(16),
                    const BullBorderedTile(child: Text('Field surface')),
                    const Gap(16),
                    BullSegmented(
                      items: const {'Bitcoin', 'Lightning', 'Liquid'},
                      onSelected: (_) {},
                    ),
                    const Gap(24),
                  ],
                ),
              );
              switch (name) {
                case 'BullDialog':
                  unawaited(
                    BullDialog.show<void>(
                      context: context,
                      builder: (_) => const Text('Public details'),
                    ),
                  );
                case 'BullPickerSheet':
                  unawaited(
                    BullBottomSheet.show<void>(
                      context: context,
                      child: BullPickerSheet<String>(
                        title: 'Choose wallet',
                        options: const ['Bitcoin', 'Savings'],
                        isSelected: (v) => v == 'Bitcoin',
                        label: (v) => v,
                      ),
                    ),
                  );
                case 'BullInstructionsSheet':
                  unawaited(
                    BullInstructionsSheet.show(
                      context,
                      title: 'Public instructions',
                      instructions: const [
                        'Review the public details.',
                        'Close this preview.',
                      ],
                    ),
                  );
                case 'MaterialBottomSheet':
                  unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => child,
                    ),
                  );
                default:
                  unawaited(
                    BullBottomSheet.show<void>(context: context, child: child),
                  );
              }
            },
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(type),
            localizationsDelegates: bullUiLocalizationsDelegates,
            supportedLocales: BullUiLocalizations.supportedLocales,
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(name, style: context.bullType.subtitle),
                        const Gap(32),
                        content(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (name.endsWith('Sheet') || name == 'BullDialog') {
          await tester.tap(find.text('Open preview'));
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
