import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// Screens and windows the panel must fit, from cramped to roomy.
const smallPhone = Size(320, 568);
const largePhone = Size(430, 932);
const landscapePhone = Size(844, 390);
const desktopWindow = Size(1440, 900);

const azerty = [
  'a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', //
  'q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', //
  'w', 'x', 'c', 'v', 'b', 'n', //
];
const eAcute = 'é';
const eGrave = 'è';

const languages = [
  BullKeyboardLanguage(code: 'EN', name: 'English'),
  BullKeyboardLanguage(code: 'FR', name: 'French'),
];

Future<void> pumpKeyboard(
  WidgetTester tester, {
  Set<String>? enabledLetters,
  bool canBackspace = true,
  bool canAdvance = true,
  void Function(String)? onLetter,
  VoidCallback? onBackspace,
  VoidCallback? onEnter,
  List<String> layout = BullMnemonicKeyboard.qwerty,
  List<int> rows = const [10, 9, 7],
  bool scrollable = false,
  List<String> accents = const [],
  Map<String, List<String>> variants = const {},
  List<String> suggestions = const [],
  ValueChanged<String>? onSuggestion,
  String? suggestionNotice,
  ValueChanged<int>? onLanguage,
  Size? screen,
}) async {
  if (screen != null) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = screen;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    wrapWithTheme(
      Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            BullMnemonicKeyboard(
              enabledLetters: enabledLetters ?? {...layout, ...accents},
              canBackspace: canBackspace,
              canAdvance: canAdvance,
              onLetter: onLetter ?? (_) {},
              onBackspace: onBackspace ?? () {},
              onEnter: onEnter ?? () {},
              shuffleActive: false,
              onToggleShuffle: () {},
              shuffleHint: 'shuffle',
              layout: layout,
              rows: rows,
              scrollable: scrollable,
              accents: accents,
              variants: variants,
              suggestions: suggestions,
              onSuggestion: onSuggestion ?? (_) {},
              suggestionNotice: suggestionNotice,
              languages: languages,
              onLanguage: onLanguage ?? (_) {},
              languageHint: 'language',
            ),
          ],
        ),
      ),
    ),
  );
}

Finder keyCap(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(BullKeyCap));

Rect keyRect(WidgetTester tester, String label) =>
    tester.getRect(keyCap(label).first);

Finder backspace() => find.ancestor(
  of: find.byIcon(Icons.backspace_outlined),
  matching: find.byType(BullKeyCap),
);

Finder enter() => find.byKey(const Key('mnemonicEnterKey'));
Finder scramble() => find.byKey(const Key('mnemonicParanoidToggle'));
Finder languageKey() => find.byKey(const Key('mnemonicLanguageKey'));
Finder pageKey() => find.byKey(const Key('mnemonicPageKey'));

const keypad = BullKeypadColors.light;
const type = BullTypography.standard;

TextStyle? styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

Color? fillOf(WidgetTester tester, Finder key) => tester
    .widget<BullKeyCap>(
      find
          .descendant(
            of: key,
            matching: find.byType(BullKeyCap),
            matchRoot: true,
          )
          .first,
    )
    .fill;

void main() {
  group('BullMnemonicKeyboard keys', () {
    testWidgets('renders every letter of the alphabet as a key', (
      tester,
    ) async {
      await pumpKeyboard(tester);
      for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        expect(find.text(letter), findsOneWidget, reason: 'missing $letter');
      }
    });

    testWidgets('an enabled key reports its letter', (tester) async {
      String? tapped;
      await pumpKeyboard(
        tester,
        enabledLetters: const {'a'},
        onLetter: (l) => tapped = l,
      );
      await tester.tap(find.text('a'));
      expect(tapped, equals('a'));
    });

    testWidgets(
      'a disabled key loses its fill, fades its glyph, ignores taps',
      (tester) async {
        var fired = false;
        await pumpKeyboard(
          tester,
          enabledLetters: const {'a'},
          onLetter: (_) => fired = true,
        );
        await tester.tap(find.text('b'), warnIfMissed: false);
        expect(fired, isFalse);

        final on = tester.widget<BullKeyCap>(keyCap('a'));
        final off = tester.widget<BullKeyCap>(keyCap('b'));
        expect(on.fill, keypad.key);
        expect(off.fill, testBullTheme.transparent);
        expect(styleOf(tester, 'b')?.color, keypad.disabledGlyph);
        expect(styleOf(tester, 'a')?.color, keypad.onKey);
      },
    );

    testWidgets('backspace and enter report only when enabled', (tester) async {
      var backspaces = 0;
      var enters = 0;
      await pumpKeyboard(
        tester,
        onBackspace: () => backspaces++,
        onEnter: () => enters++,
      );
      await tester.tap(backspace());
      await tester.tap(enter());
      expect((backspaces, enters), (1, 1));

      await pumpKeyboard(
        tester,
        canBackspace: false,
        canAdvance: false,
        onBackspace: () => backspaces++,
        onEnter: () => enters++,
      );
      await tester.tap(backspace(), warnIfMissed: false);
      await tester.tap(enter(), warnIfMissed: false);
      expect((backspaces, enters), (1, 1));
    });

    testWidgets('the keys sit on the keypad panel', (tester) async {
      await pumpKeyboard(tester);
      final panel = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BullMnemonicKeyboard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(panel.color, keypad.panel);
    });

    testWidgets('function key glyphs read the keypad roles', (tester) async {
      await pumpKeyboard(tester, canBackspace: false);
      Color? iconColor(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color;
      expect(iconColor(Icons.keyboard_return), keypad.onFunctionKey);
      expect(iconColor(Icons.backspace_outlined), keypad.onFunctionKeyDisabled);
      expect(fillOf(tester, backspace()), keypad.functionKey);
    });

    testWidgets('glyphs ignore the system text size, the key already scales', (
      tester,
    ) async {
      await pumpKeyboard(tester, screen: largePhone);
      final plain = tester.getSize(find.text('q'));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpKeyboard(tester, screen: largePhone);
      expect(tester.getSize(find.text('q')), plain);
      expect(
        tester.widget<Text>(find.text('q')).textScaler,
        TextScaler.noScaling,
      );
    });

    testWidgets('secondary key labels never fall below the caption size', (
      tester,
    ) async {
      await pumpKeyboard(
        tester,
        screen: landscapePhone,
        accents: const [eAcute, eGrave],
      );
      final code = styleOf(tester, 'EN')?.fontSize;
      final page = styleOf(tester, '$eAcute$eGrave')?.fontSize;
      for (final size in [code, page]) {
        expect(size, greaterThanOrEqualTo(type.caption.fontSize ?? 0));
      }
    });

    testWidgets('a combining mark key shows a base and reports the bare mark', (
      tester,
    ) async {
      String? tapped;
      await pumpKeyboard(
        tester,
        layout: const ['゙'],
        scrollable: true,
        onLetter: (letter) => tapped = letter,
      );
      expect(find.text('゙'), findsNothing);
      await tester.tap(find.text('◌゙'));
      expect(tapped, '゙');
    });
  });

  group('BullMnemonicKeyboard layout', () {
    testWidgets('lays out the rows the owner gives, AZERTY included', (
      tester,
    ) async {
      await pumpKeyboard(tester, layout: azerty, rows: const [10, 10, 6]);
      final a = keyRect(tester, 'a');
      final q = keyRect(tester, 'q');
      final w = keyRect(tester, 'w');
      expect(a.top, lessThan(q.top));
      expect(q.top, lessThan(w.top));
      // A full second row starts at the left edge, like the first.
      expect(q.left, closeTo(a.left, 0.01));
      expect(
        keyRect(tester, 'm').right,
        closeTo(keyRect(tester, 'p').right, 1),
      );
    });

    testWidgets('backspace closes the third row on the right, 1.5 keys wide', (
      tester,
    ) async {
      await pumpKeyboard(tester);
      final bs = tester.getRect(backspace());
      final m = keyRect(tester, 'm');
      final p = keyRect(tester, 'p');
      expect(bs.top, closeTo(m.top, 0.01));
      expect(bs.left, greaterThan(m.right));
      expect(bs.right, closeTo(p.right, 1));
      expect(
        bs.width,
        closeTo(1.5 * p.width + 0.5 * BullMnemonicKeyboard.keyGap, 1),
      );
    });

    testWidgets('bottom row: language, page, scramble centred, enter right', (
      tester,
    ) async {
      await pumpKeyboard(
        tester,
        layout: azerty,
        rows: const [10, 10, 6],
        accents: const [eAcute, eGrave],
      );
      final language = tester.getRect(languageKey());
      final page = tester.getRect(pageKey());
      final shuffle = tester.getRect(scramble());
      final ret = tester.getRect(enter());
      final bs = tester.getRect(backspace());
      final a = keyRect(tester, 'a');
      final p = keyRect(tester, 'p');

      expect(language.left, closeTo(a.left, 0.01));
      expect(page.left, greaterThan(language.right));
      expect(shuffle.left, greaterThan(page.right));
      expect(ret.left, greaterThan(shuffle.right));
      expect(ret.right, closeTo(p.right, 1));
      expect(shuffle.center.dx, closeTo((a.left + p.right) / 2, 1));
      for (final key in [language, page, shuffle, ret]) {
        expect(key.size.width, closeTo(bs.width, 1));
        expect(key.size.height, closeTo(bs.height, 0.01));
        expect(key.top, closeTo(language.top, 0.01));
      }
      // Function keys share one look, distinct from the letters.
      for (final finder in [languageKey(), pageKey(), scramble(), enter()]) {
        final cap = find.descendant(
          of: finder,
          matching: find.byType(BullKeyCap),
          matchRoot: true,
        );
        expect(tester.widget<BullKeyCap>(cap.first).fill, keypad.functionKey);
      }
    });

    testWidgets('without accents the page slot stays empty', (tester) async {
      await pumpKeyboard(tester);
      expect(pageKey(), findsNothing);
      expect(scramble(), findsOneWidget);
    });

    testWidgets('the page key opens the accents and returns with abc', (
      tester,
    ) async {
      final typed = <String>[];
      await pumpKeyboard(
        tester,
        layout: azerty,
        rows: const [10, 10, 6],
        accents: const [eAcute, eGrave],
        onLetter: typed.add,
      );
      expect(find.text('$eAcute$eGrave'), findsOneWidget);
      await tester.tap(pageKey());
      await tester.pump();
      expect(find.text('a'), findsNothing);
      expect(find.text('abc'), findsOneWidget);
      await tester.tap(find.text(eAcute));
      await tester.pump();
      expect(typed, [eAcute]);
      // An accent is one letter of a word: the letters come back.
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('a long press offers the variants and types the chosen one', (
      tester,
    ) async {
      final typed = <String>[];
      await pumpKeyboard(
        tester,
        layout: azerty,
        rows: const [10, 10, 6],
        accents: const [eAcute, eGrave],
        variants: const {
          'e': [eAcute, eGrave],
        },
        onLetter: typed.add,
      );
      await tester.longPress(find.text('e'));
      await tester.pumpAndSettle();
      expect(find.text(eAcute), findsOneWidget);
      expect(find.text(eGrave), findsOneWidget);
      // The popup sits above the key.
      expect(
        tester.getRect(find.text(eGrave)).bottom,
        lessThan(keyRect(tester, 'e').top),
      );
      await tester.tap(find.text(eGrave));
      await tester.pumpAndSettle();
      expect(typed, [eGrave]);
      expect(find.text(eAcute), findsNothing);
    });

    testWidgets('a key with variants exposes no long press action', (
      tester,
    ) async {
      // Variants depend on the prefix typed, so an action that comes and
      // goes would tell an accessibility service about the secret word.
      final handle = tester.ensureSemantics();
      try {
        await pumpKeyboard(
          tester,
          layout: azerty,
          rows: const [10, 10, 6],
          accents: const [eAcute, eGrave],
          variants: const {
            'e': [eAcute, eGrave],
          },
        );
        expect(
          find.semantics.byPredicate(
            (node) =>
                node.getSemanticsData().hasAction(SemanticsAction.longPress),
          ),
          findsNothing,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('sliding onto a variant and releasing types it', (
      tester,
    ) async {
      final typed = <String>[];
      await pumpKeyboard(
        tester,
        layout: azerty,
        rows: const [10, 10, 6],
        variants: const {
          'e': [eAcute, eGrave],
        },
        onLetter: typed.add,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('e')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(find.text(eGrave)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(typed, [eGrave]);
    });

    testWidgets('the language key lists the wordlists and reports a choice', (
      tester,
    ) async {
      int? chosen;
      await pumpKeyboard(tester, onLanguage: (index) => chosen = index);
      expect(
        find.descendant(of: languageKey(), matching: find.text('EN')),
        findsOneWidget,
      );
      await tester.tap(languageKey());
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(
        tester.getRect(find.text('French')).bottom,
        lessThan(tester.getRect(languageKey()).top),
      );
      expect(styleOf(tester, 'English')?.fontSize, type.body.fontSize);
      expect(styleOf(tester, 'FR')?.fontSize, type.caption.fontSize);
      await tester.tap(find.text('French'));
      await tester.pumpAndSettle();
      expect(chosen, 1);
      expect(find.text('French'), findsNothing);
    });
  });

  group('BullMnemonicKeyboard suggestions', () {
    testWidgets('the best suggestion sits in the middle, in bold', (
      tester,
    ) async {
      String? tapped;
      await pumpKeyboard(
        tester,
        suggestions: const ['able', 'about', 'above'],
        onSuggestion: (word) => tapped = word,
      );
      final best = tester.getCenter(find.text('able'));
      expect(tester.getCenter(find.text('about')).dx, lessThan(best.dx));
      expect(tester.getCenter(find.text('above')).dx, greaterThan(best.dx));
      expect(
        tester.widget<Text>(find.text('able')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('about')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(styleOf(tester, 'able')?.fontSize, type.body.fontSize);
      await tester.tap(find.text('above'));
      expect(tapped, 'above');
    });

    testWidgets('a notice stands in while there is no suggestion', (
      tester,
    ) async {
      await pumpKeyboard(tester, suggestionNotice: '128 possible last words');
      expect(find.text('128 possible last words'), findsOneWidget);
      expect(
        styleOf(tester, '128 possible last words')?.fontSize,
        type.label.fontSize,
      );
    });
  });

  group('BullMnemonicKeyboard grid', () {
    final hanzi = [
      for (var i = 0; i < 300; i++) String.fromCharCode(0x4e00 + i),
    ];

    testWidgets('exposes no key count or extent', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpKeyboard(tester, layout: hanzi, scrollable: true);
        expect(
          find.semantics.byPredicate(
            (node) =>
                node.scrollChildCount != null ||
                node.scrollIndex != null ||
                node.scrollExtentMax != null,
          ),
          findsNothing,
        );
        expect(find.bySemanticsLabel(hanzi.first), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('backspace sits right of the grid, level with its last row', (
      tester,
    ) async {
      await pumpKeyboard(tester, layout: hanzi, scrollable: true);
      final grid = tester.getRect(find.byType(GridView));
      final bs = tester.getRect(backspace());
      expect(bs.left, greaterThan(grid.right));
      expect(bs.bottom, closeTo(grid.bottom, 0.01));
      expect(pageKey(), findsNothing);
      expect(scramble(), findsOneWidget);
    });
  });

  group('BullMnemonicKeyboard sizing', () {
    for (final (name, size) in [
      ('small phone', smallPhone),
      ('large phone', largePhone),
      ('desktop window', desktopWindow),
    ]) {
      testWidgets('takes 35% of a $name and fits it', (tester) async {
        await pumpKeyboard(tester, screen: size);
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byType(BullMnemonicKeyboard));
        expect(panel.height, closeTo(size.height * 0.35, 0.01));
        expect(panel.bottom, closeTo(size.height, 0.01));
        // The keys fill it: four rows, three gaps, the strip and the margin.
        final key = tester.getSize(enter()).height;
        expect(
          4 * key +
              3 * BullMnemonicKeyboard.rowGap +
              BullMnemonicKeyboard.suggestionHeight +
              BullMnemonicKeyboard.minBottomPadding,
          closeTo(panel.height, 0.01),
        );
      });
    }

    testWidgets('a landscape phone keeps usable keys, without overflow', (
      tester,
    ) async {
      await pumpKeyboard(tester, screen: landscapePhone);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(enter()).height,
        closeTo(BullMnemonicKeyboard.minKeyHeight, 0.01),
      );
      final panel = tester.getRect(find.byType(BullMnemonicKeyboard));
      expect(panel.bottom, lessThanOrEqualTo(landscapePhone.height));
    });

    testWidgets('the grid of another script fits a landscape phone', (
      tester,
    ) async {
      await pumpKeyboard(
        tester,
        layout: [for (var i = 0; i < 40; i++) String.fromCharCode(0x4e00 + i)],
        scrollable: true,
        screen: landscapePhone,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wide window caps the key width and centres the keys', (
      tester,
    ) async {
      await pumpKeyboard(tester, screen: desktopWindow);
      final q = keyRect(tester, 'q');
      final p = keyRect(tester, 'p');
      expect(q.width, closeTo(BullMnemonicKeyboard.maxKeyWidth, 0.01));
      expect((q.left + p.right) / 2, closeTo(desktopWindow.width / 2, 0.5));
    });

    test('the panel height follows the screen, above a floor', () {
      expect(
        BullMnemonicKeyboard.panelHeightFor(const Size(393, 851), 18),
        closeTo(851 * 0.35, 0.01),
      );
      final floor = BullMnemonicKeyboard.panelHeightFor(
        const Size(800, 200),
        0,
      );
      expect(
        BullMnemonicKeyboard.keyHeightFor(floor, 0),
        closeTo(BullMnemonicKeyboard.minKeyHeight, 0.01),
      );
    });
  });
}
