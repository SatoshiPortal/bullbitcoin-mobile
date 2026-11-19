import 'package:ark/ark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/ui/widgets/internal_transfer_form.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart';
import 'package:bull_ark/src/ui/ark_amount.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart'
    show FontLoader, SystemChannels, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:novlang/novlang.dart';
import 'package:primitives/primitives.dart';

import '../../../features/ark/test/ark_payment_cubit_test.dart' as payment;
import '../../../features/ark/test/ark_receive_flow_test.dart' as receive;
import '../../../features/ark/test/fake_ark_client.dart';
import '../swap/internal_transfer_fixture.dart' as transfer;

const address = 'ark1pu6h30w3zqkx8m2d7lq0e5ny6h4t3s8r2k9j7jxhs4u9xvf';

Widget app(
  Widget screen,
  AppThemeType theme, {
  String language = 'en',
  double scale = 1,
  bool hidden = false,
}) => m.MaterialApp(
  theme: AppTheme.themeData(theme),
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    ArkLocalizations.delegate,
    ...novlangLocalizationsDelegates(NovlangPolicy.apple),
    bullUiLocalizationsDelegate,
  ],
  builder: (context, child) {
    if (child == null) throw StateError('Missing app child');
    return m.MediaQuery(
      data: m.MediaQuery.of(context)
          .copyWith(textScaler: m.TextScaler.linear(scale)),
      child: child,
    );
  },
  home: BullAmountScope(
    snapshot: BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: hidden,
      isReady: true,
    ),
    writeUnit: (_) async => false,
    child: screen,
  ),
);

void viewport(WidgetTester tester) {
  tester.view.physicalSize = const m.Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder detail(String name) => find.byWidgetPredicate(
  (widget) => widget is BullDetailsTableItem && widget.label == name,
);

void main() {
  setUpAll(() async {
    for (final font in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final theme in AppThemeType.values) {
    for (final scale in [1.0, 1.5]) {
      for (final language in ['en', 'fr']) {
        testWidgets(
          'Receive compact card keeps real Copy edge active ${theme.name}/$scale/$language',
          (tester) async {
            viewport(tester);
            final owner = receive.controller(FakeArkClient());
            addTearDown(owner.close);
            owner.emit(
              ArkReceiveReady(
                ArkReceiveDestination(
                  kind: ArkDestinationKind.ark,
                  value: address,
                ),
              ),
            );
            final writes = <String>[];
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              (call) async {
                if (call.method == 'Clipboard.setData') {
                  if (call.arguments case {'text': final String text}) {
                    writes.add(text);
                  }
                }
                return null;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(SystemChannels.platform, null),
            );
            await tester.pumpWidget(
              app(
                ArkReceiveScreen(cubit: owner),
                theme,
                language: language,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byType(BullCopyField);
            if (language == 'en') {
              expect(
                tester.getSize(field).height,
                lessThanOrEqualTo(scale == 1 ? 80 : 104),
              );
            }
            final copy = find.descendant(
              of: field,
              matching: find.byType(m.IconButton),
            );
            expect(copy, findsOneWidget);
            await tester.ensureVisible(copy);
            await tester.pumpAndSettle();
            final box = tester.getRect(copy);
            expect(box.width, greaterThanOrEqualTo(48));
            expect(box.height, greaterThanOrEqualTo(48));
            final loc = ArkLocalizations.of(tester.element(field));
            if (loc == null) throw StateError('Missing Receive localization');
            final additional = find.ancestor(
              of: find.text(loc.additionalInformation),
              matching: find.byType(BullBorderedTile),
            );
            expect(tester.getSize(additional).height, greaterThanOrEqualTo(92));
            expect(
              tester.getTopLeft(additional).dy -
                  tester.getBottomRight(field).dy,
              inInclusiveRange(0, BullSpacing.md),
            );
            await tester.tapAt(box.topLeft + m.Offset(1, box.height / 2));
            await tester.pumpAndSettle();
            expect(writes, [address]);
            expect(find.text(loc.copied), findsOneWidget);
            expect(find.widgetWithText(BullButton, loc.share), findsNothing);
            expect(tester.takeException(), isNull);
            BullSnackBar.dismiss();
            await tester.pumpAndSettle();
          },
        );
      }
    }

    for (final privacy in ['visible', 'missing', 'hidden']) {
      testWidgets(
        'Confirm binds visible Amount fiat and full W1 ${theme.name}/$privacy',
        (tester) async {
          viewport(tester);
          final rig = payment.PaymentRig();
          final quote = ArkQuote(
            id: 'public-reviewed-quote',
            account: rig.cubit.account,
            generation: 2,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
            kind: ArkOperationKind.payment,
            amount: Sats.fromInt(100100),
            fee: Sats.fromInt(100),
            net: Sats.fromInt(100000),
            destination: address,
            observedTip: 100,
            validUntil: DateTime.utc(2030),
          );
          rig.cubit.emit(ArkPaymentReview(quote));
          await tester.pumpWidget(
            app(
              ArkPaymentScreen(
                cubit: rig.cubit,
                onReconcile: () {},
                displayData: ArkDisplayData(
                  account: rig.cubit.account,
                  walletId: 'public-observed-source',
                  available: Sats.fromInt(999999),
                  price: privacy == 'missing'
                      ? null
                      : BitcoinPrice(
                          currency: SupportedCurrency.usd,
                          fiatAmount: 75400,
                          fetchedAt: DateTime.utc(2026, 11, 19),
                        ),
                ),
              ),
              theme,
              hidden: privacy == 'hidden',
            ),
          );
          await tester.pumpAndSettle();
          final amount = detail('Amount');
          expect(
            find.descendant(of: amount, matching: find.text('100,000 sats')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: amount, matching: find.text('75.40 USD')),
            privacy == 'visible' ? findsOneWidget : findsNothing,
          );
          final fiatRow = find.ancestor(
            of: find.byType(ArkFiatAmount),
            matching: find.byType(BullDetailsTableItem),
          );
          expect(fiatRow, findsOneWidget);
          expect(tester.element(fiatRow), same(tester.element(amount)));
          final recipient = tester.widget<BullDetailsTableItem>(detail('To'));
          expect(recipient.copyValue, address);
          expect(
            find.descendant(of: detail('To'), matching: find.text(address)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: detail('Network fees'),
              matching: find.text('100 sats'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: detail('Total'),
              matching: find.text('100,100 sats'),
            ),
            findsOneWidget,
          );
          final context = tester.element(find.byType(ArkPaymentScreen));
          final confirm = tester.widget<BullButton>(
            find.widgetWithText(BullButton, 'Confirm'),
          );
          expect(confirm.bgColor, context.bull.primary);
          expect(confirm.textColor, context.bull.onPrimary);
          expect(confirm.outlined, isFalse);
          expect(rig.client.calls, isEmpty);
          expect(rig.ids, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final scale in [1.0, 1.5]) {
      for (final language in ['en', 'fr']) {
        testWidgets(
          'Scan camera grows and stays filled ${theme.name}/$scale/$language',
          (tester) async {
            viewport(tester);
            final rig = payment.PaymentRig();
            var scans = 0;
            Future<String?> scan() async {
              scans++;
              return null;
            }

            Widget cameraPage(double factor) => app(
              ArkPaymentScreen(
                cubit: rig.cubit,
                onReconcile: () {},
                onScan: scan,
              ),
              theme,
              language: language,
              scale: factor,
            );
            double? frenchNominalFont;
            if (language == 'fr' && scale == 1.5) {
              await tester.pumpWidget(cameraPage(1));
              await tester.pumpAndSettle();
              final normalLoc = ArkLocalizations.of(
                tester.element(find.byType(ArkPaymentScreen)),
              );
              if (normalLoc == null) {
                throw StateError('Missing nominal French localization');
              }
              final normalCamera = find.widgetWithText(
                BullButton,
                normalLoc.openCamera,
              );
              final normalParagraph = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: normalCamera,
                  matching: find.byType(m.RichText),
                ),
              );
              final normalFont = normalParagraph.text.style?.fontSize;
              if (normalFont == null) {
                throw StateError('Missing nominal rendered font');
              }
              final normalButton = tester.widget<BullButton>(normalCamera);
              final nominalToken =
                  normalButton.textStyle?.fontSize ??
                  tester.element(normalCamera).bullType.subtitle.fontSize;
              if (nominalToken == null) {
                throw StateError('Missing nominal button font token');
              }
              frenchNominalFont = normalParagraph.textScaler.scale(normalFont);
              expect(frenchNominalFont, closeTo(nominalToken, 0.1));
              expect(normalParagraph.text.toPlainText(), normalLoc.openCamera);
              expect(normalParagraph.didExceedMaxLines, isFalse);
              expect(scans, 0);
              expect(rig.client.calls, isEmpty);
            }
            await tester.pumpWidget(cameraPage(scale));
            await tester.pumpAndSettle();
            final loc = ArkLocalizations.of(
              tester.element(find.byType(ArkPaymentScreen)),
            );
            if (loc == null) throw StateError('Missing Scan localization');
            final camera = find.widgetWithText(BullButton, loc.openCamera);
            final box = tester.getRect(camera);
            expect(box.width, greaterThanOrEqualTo(196));
            expect(box.width, lessThanOrEqualTo(390));
            expect(box.left, greaterThanOrEqualTo(0));
            expect(box.right, lessThanOrEqualTo(390));
            if (language == 'en' && scale == 1) {
              expect(box.height, 52);
            } else {
              expect(box.height, greaterThanOrEqualTo(52));
            }
            final renderedLabel = find.descendant(
              of: camera,
              matching: find.byType(m.RichText),
            );
            expect(renderedLabel, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(
              renderedLabel,
            );
            expect(paragraph.text.toPlainText(), loc.openCamera);
            expect(paragraph.didExceedMaxLines, isFalse);
            if (language == 'fr' && scale == 1.5) {
              final font = paragraph.text.style?.fontSize;
              if (font == null) {
                throw StateError('Missing rendered camera font');
              }
              expect(font, greaterThan(0));
              expect(paragraph.text.style?.fontFamily, 'Golos Text');
              final normal = frenchNominalFont;
              if (normal == null) {
                throw StateError('Missing French scale1 control');
              }
              final enlarged = paragraph.textScaler.scale(font);
              expect(enlarged, greaterThan(normal));
              expect(enlarged, closeTo(normal * 1.5, 0.1));
            }
            final label = tester.getRect(find.text(loc.openCamera));
            expect(label.left, greaterThanOrEqualTo(box.left));
            expect(label.right, lessThanOrEqualTo(box.right));
            final button = tester.widget<BullButton>(camera);
            final context = tester.element(camera);
            expect(button.outlined, isFalse);
            expect(button.bgColor, context.bull.secondary);
            expect(button.textColor, context.bull.onSecondary);
            await tester.tap(camera);
            await tester.pumpAndSettle();
            expect(scans, 1);
            expect(rig.client.calls, isEmpty);
            expect(
              find.byKey(const ValueKey('ark-payment-address')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final from in [false, true]) {
      testWidgets(
        'Transfer menu placement preserves real pick ${theme.name}/from=$from',
        (tester) async {
          viewport(tester);
          var edits = 0;
          var continued = 0;
          await tester.pumpWidget(
            app(
              InternalTransferForm(
                wallets: [
                  transfer.transferWallet(),
                  transfer.transferWallet(
                    id: 'liquid',
                    kind: TransferWalletKind.liquid,
                  ),
                ],
                ark: transfer.transferContext(),
                initialAmount: '100000',
                onEdit: () => edits++,
                onExternal: () {},
                onContinue: (_) => continued++,
              ),
              theme,
            ),
          );
          await tester.pumpAndSettle();
          final field = find.byKey(
            ValueKey(from ? 'transfer-from' : 'transfer-to'),
          );
          final rect = tester.getRect(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          final options = find.byType(m.PopupMenuItem<int>);
          expect(options, findsNWidgets(3));
          final first = tester.getRect(options.first);
          if (from) {
            expect(first.top, greaterThanOrEqualTo(rect.bottom));
          } else {
            expect(first.top, lessThan(rect.bottom));
            expect(first.bottom, greaterThan(rect.top));
          }
          await tester.tap(
            find.descendant(
              of: options.at(1),
              matching: find.text('Instant payments'),
            ),
          );
          await tester.pumpAndSettle();
          expect(edits, 1);
          expect(continued, 0);
          expect(tester.widget<BullDropdown<String>>(field).value, 'liquid');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
