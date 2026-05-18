import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_constants.dart';
import 'base_robot.dart';

/// Robot for the receive screen (ReceiveQrPage).
///
/// This screen shows:
///   - QR code for the receive address
///   - The address text (in a CopyInput widget)
///   - Copy button
///   - Network selection (Bitcoin vs Liquid)
///   - Optional: amount entry, note
class ReceiveRobot extends BaseRobot {
  ReceiveRobot(super.$);

  /// Verify the receive screen is visible.
  Future<void> expectReceiveScreenVisible() async {
    // Look for "Receive Address" text or QR code Image widget
    final hasText = await waitForText(
      TestStrings.receiveAddress,
      timeout: TestTimeouts.standard,
    );

    if (!hasText) {
      // Fallback: check for QR Image widget
      final hasImage = $.tester.any(find.byType(Image));
      expect(hasImage, isTrue,
          reason: 'Receive screen did not appear (no address text or QR image)');
    }
  }

  /// Check that the QR display area is present on the receive screen.
  ///
  /// The app uses QrDisplayWidget which either shows:
  ///   - LoadingBoxContent (while address generates)
  ///   - QrImageView (once address is ready)
  /// We check for the wrapper widget which is always present.
  Future<void> expectQrDisplayVisible() async {
    final found = await waitForType(
      QrDisplayWidget,
      timeout: TestTimeouts.standard,
    );
    expect(found, isTrue,
        reason: 'No QR display widget found on receive screen');
  }

  /// Check that an address string is displayed.
  ///
  /// Bitcoin addresses start with bc1, tb1 (testnet), or 1/3 (legacy).
  /// Liquid addresses start with ex1, lq1, or VJL/VTp.
  /// Returns true if any address-like text is found.
  Future<bool> hasAddressDisplayed() async {
    await $.pump(const Duration(seconds: 2));

    // Look for common address prefixes in any Text widget
    final allText = $.tester.widgetList<Text>(find.byType(Text));
    for (final widget in allText) {
      final data = widget.data ?? '';
      if (data.startsWith('bc1') ||
          data.startsWith('tb1') ||
          data.startsWith('lq1') ||
          data.startsWith('ex1') ||
          data.startsWith('VJL') ||
          data.startsWith('VTp') ||
          data.startsWith('AzpH')) {
        return true;
      }
    }
    return false;
  }

  /// Navigate back from the receive screen.
  ///
  /// The app uses a custom TopBar with IconButton(Icons.arrow_back),
  /// not Flutter's standard BackButton widget.
  Future<void> goBack() async {
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pump(const Duration(seconds: 2));
  }
}
