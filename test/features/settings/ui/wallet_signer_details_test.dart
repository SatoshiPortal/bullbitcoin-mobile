import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/dropdown/signer_device_dropdown.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_detail_fields.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_signer_details.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge, BullBorderedTile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final signers = [
    for (final (index, fingerprint) in [
      'aaaaaaaa',
      'bbbbbbbb',
      'cccccccc',
    ].indexed)
      WalletSigner.single(
        id: fingerprint,
        masterFingerprint: fingerprint,
        xpubFingerprint: fingerprint,
        xpub: 'public-account-key-$fingerprint-${'abcdef' * 20}',
        derivationPath: "m/48'/0'/0'/2'",
        signer: index == 0 ? SignerEntity.local : SignerEntity.remote,
        signerDevice: index == 0 ? null : SignerDeviceEntity.bitbox02,
      ),
  ];

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('key inspection controls fit a narrow ${theme.name} screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          WalletSignerDetails.inspection(
            signers: signers,
            onSignerDeviceChanged: (_, _) {},
            signerSummaryBuilder: (context, signer) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signer.displayFingerprint),
                BullBadge(
                  label: signer == signers.first ? 'Locked' : 'External',
                  background: context.appColors.surfaceContainerHighest,
                  foreground: context.appColors.onSurface,
                ),
              ],
            ),
          ),
          theme: theme,
        ),
      );
      expect(find.byType(BullBorderedTile), findsNWidgets(3));
      expect(find.byType(BullBadge), findsNWidgets(3));
      expect(find.byType(SignerDeviceDropdown), findsNWidgets(2));
      expect(find.byType(CopyInput), findsNWidgets(3));
      expect(find.byIcon(Icons.qr_code), findsNWidgets(3));
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('On this device'), findsNothing);
      expect(find.text('Bull Wallet (this device)'), findsNothing);
      for (final signer in signers) {
        expect(find.text(signer.displayFingerprint), findsOneWidget);
        expect(find.text(signer.descriptorKeys.single.xpub), findsOneWidget);
      }
      expect(find.text("m/48'/0'/0'/2'"), findsNWidgets(3));
      await tester.ensureVisible(find.byIcon(Icons.qr_code).first);
      await tester.tap(find.byIcon(Icons.qr_code).first);
      await tester.pumpAndSettle();
      expect(find.byType(QrDisplayWidget), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(QrDisplayWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('existing wallet details retain per-signer device editing', (
    tester,
  ) async {
    WalletSigner? edited;
    SignerDeviceEntity? selectedDevice;
    await tester.pumpWidget(
      _app(
        WalletSignerDetails(
          signers: signers,
          onSignerDeviceChanged: (signer, device) {
            edited = signer;
            selectedDevice = device;
          },
        ),
      ),
    );
    expect(find.byType(BullBorderedTile), findsNothing);
    expect(find.byType(CopyInput), findsNWidgets(3));
    expect(find.byType(SignerDeviceDropdown), findsNWidgets(2));
    tester
        .widget<SignerDeviceDropdown>(find.byType(SignerDeviceDropdown).last)
        .onChanged!(SignerDeviceEntity.krux);
    expect(edited, same(signers.last));
    expect(selectedDevice, SignerDeviceEntity.krux);
  });

  testWidgets('inspection edits only the selected external device metadata', (
    tester,
  ) async {
    WalletSigner? edited;
    SignerDeviceEntity? selected;
    await tester.pumpWidget(
      _app(
        WalletSignerDetails.inspection(
          signers: signers,
          signerSummaryBuilder: (_, signer) => Text(signer.displayFingerprint),
          onSignerDeviceChanged: (signer, device) {
            edited = signer;
            selected = device;
          },
        ),
      ),
    );
    final dropdowns = tester.widgetList<SignerDeviceDropdown>(
      find.byType(SignerDeviceDropdown),
    );
    expect(dropdowns.length, 2);
    dropdowns.last.onChanged!(SignerDeviceEntity.krux);
    expect(edited, same(signers.last));
    expect(selected, SignerDeviceEntity.krux);
    expect(edited!.signer, SignerEntity.remote);
    expect(signers.first.signer, SignerEntity.local);
  });

  testWidgets('unassigned keys have dropdowns; saving disables metadata only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WalletSignerDetails.inspection(
          signers: [
            for (final signer in signers)
              signer.copyWith(
                signer: SignerEntity.none,
                clearSignerDevice: true,
              ),
          ],
          isUpdatingSignerDevice: true,
          onSignerDeviceChanged: (_, _) => fail('Device edit while saving'),
          signerSummaryBuilder: (_, signer) => Text(signer.displayFingerprint),
        ),
      ),
    );
    expect(find.byType(SignerDeviceDropdown), findsNWidgets(3));
    for (final dropdown in tester.widgetList<SignerDeviceDropdown>(
      find.byType(SignerDeviceDropdown),
    )) {
      expect(dropdown.onChanged, isNull);
      expect(dropdown.value, isNull);
    }
    expect(find.byIcon(Icons.copy_sharp), findsNWidgets(3));
    expect(find.byIcon(Icons.qr_code), findsNWidgets(3));
  });

  for (final signer in signers) {
    testWidgets('Copy and QR export the exact account key for ${signer.id}', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(
          WalletSignerDetails.inspection(
            signers: [signer],
            signerSummaryBuilder: (_, signer) =>
                Text(signer.displayFingerprint),
          ),
        ),
      );
      final expected =
          '[${signer.displayFingerprint}/48\'/0\'/0\'/2\']${signer.descriptorKeys.single.xpub}';
      await tester.ensureVisible(find.byIcon(Icons.copy_sharp));
      await tester.tap(find.byIcon(Icons.copy_sharp));
      await tester.pump();
      expect(copied, expected);
      await tester.pump(const Duration(seconds: 4));
      await tester.ensureVisible(find.byIcon(Icons.qr_code));
      await tester.tap(find.byIcon(Icons.qr_code));
      await tester.pumpAndSettle();
      expect(
        tester.widget<QrDisplayWidget>(find.byType(QrDisplayWidget)).data,
        expected,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'exports each distinct account without guessing missing origins',
    (tester) async {
      final keys = [
        WalletDescriptorKey(
          id: 'account-one',
          signerId: 'multi',
          masterFingerprint: 'AABBCCDD',
          xpubFingerprint: '11223344',
          xpub: 'first-public-key',
          derivationPath: "m/48'/0'/0'/2'",
        ),
        WalletDescriptorKey(
          id: 'account-two',
          signerId: 'multi',
          masterFingerprint: 'AABBCCDD',
          xpubFingerprint: '55667788',
          xpub: 'second-public-key',
          derivationPath: "m/48'/0'/1'/2'",
        ),
        WalletDescriptorKey(
          id: 'unknown-origin',
          signerId: 'multi',
          masterFingerprint: '',
          xpubFingerprint: '12345678',
          xpub: 'no-master-fingerprint',
        ),
        WalletDescriptorKey(
          id: 'unknown-path',
          signerId: 'multi',
          masterFingerprint: 'AABBCCDD',
          xpubFingerprint: '12345678',
          xpub: 'no-origin-path',
        ),
      ];
      await tester.pumpWidget(
        _app(
          WalletSignerDetails.inspection(
            signers: [
              WalletSigner(
                id: 'multi',
                signer: SignerEntity.remote,
                signerDevice: null,
                descriptorKeys: [
                  ...keys,
                  keys.first.copyWith(id: 'change-branch'),
                ],
              ),
            ],
            signerSummaryBuilder: (_, signer) =>
                Text(signer.displayFingerprint),
          ),
        ),
      );
      final fields = tester
          .widgetList<WalletDetailCopyField>(find.byType(WalletDetailCopyField))
          .toList();
      expect(fields.map((f) => f.clipboardText), [
        "[aabbccdd/48'/0'/0'/2']first-public-key",
        "[aabbccdd/48'/0'/1'/2']second-public-key",
        'no-master-fingerprint',
        'no-origin-path',
      ]);
      expect(fields.every((f) => f.showQr), isTrue);
      expect(find.byIcon(Icons.copy_sharp), findsNWidgets(4));
      expect(find.byIcon(Icons.qr_code), findsNWidgets(4));
    },
  );
}

Widget _app(Widget child, {AppThemeType theme = AppThemeType.light}) =>
    MaterialApp(
      theme: AppTheme.themeData(theme),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
