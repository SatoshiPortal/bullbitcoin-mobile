import 'dart:convert';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/scanning/public/qr_scanning.dart';
import 'package:cbor/cbor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';

void main() {
  testWidgets(
    'localizes UR feedback and accepts the same result after completion',
    (tester) async {
      const cameraChannel = MethodChannel('plugins.flutter.io/camera');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        cameraChannel,
        (call) async => call.method == 'availableCameras' ? [] : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(cameraChannel, null),
      );
      final scans = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: QrScannerWidget(onScanned: scans.add)),
        ),
      );
      await tester.pumpAndSettle();

      final readerFinder = find.byType(ReaderWidget);
      final reader = tester.widget<ReaderWidget>(readerFinder);
      final labels = tester.element(readerFinder).loc;
      expect(reader.showGallery, isTrue);
      expect(reader.tryInverted, isTrue);

      final bytes = cbor.encode(CborBytes(utf8.encode('fixture')));
      final fixture = UREncoder(
        UR('bytes', Uint8List.fromList(bytes)),
        100,
      ).nextPart();
      final frame = Code(text: fixture, isValid: true);

      reader.onScan!(frame);
      await tester.pump();
      expect(scans, ['fixture']);
      expect(find.text(labels.scanningCompletedMessage), findsOneWidget);

      reader.onScan!(frame);
      await tester.pump();
      expect(scans, ['fixture', 'fixture']);
    },
  );
}
