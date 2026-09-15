import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_recovery_kit_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Local PDF creation. No server, font download, private-key lookup or receipt.
final class VaultRecoveryKitRepositoryImpl
    implements VaultRecoveryKitRepository {
  final AssetBundle _assets;
  VaultRecoveryKitRepositoryImpl({AssetBundle? assets})
    : _assets = assets ?? rootBundle;

  @override
  Future<Result<Uint8List, BackupSettingsFailure>> create(
    VaultRecoveryKit kit,
    VaultRecoveryKitCopy copy,
  ) async {
    if (!kit.isValid) return const Err(BackupSettingsInvalidFileFailure());
    try {
      final bodyFont = pw.Font.ttf(
        await _assets.load('assets/fonts/GolosText.ttf'),
      );
      final titleFont = pw.Font.ttf(
        await _assets.load('assets/fonts/BebasNeue-Regular.ttf'),
      );
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: bodyFont, bold: bodyFont),
      );
      final policy = kit.policy;
      final id = kit.walletId.substring(0, kit.walletId.length.clamp(0, 8));
      pw.Widget header() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BULLVAULT',
            style: pw.TextStyle(font: titleFont, fontSize: 42),
          ),
          pw.Text(
            '${copy.title}  /  $id',
            style: const pw.TextStyle(fontSize: 16),
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 3, color: PdfColor.fromHex('#E52428')),
          pw.SizedBox(height: 20),
        ],
      );
      pw.Widget footer(pw.Context context) => pw.Column(
        children: [
          pw.Divider(),
          pw.Text(
            '$id  /  ${policy.network.name}  /  ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      );
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          maxPages: 8,
          header: (_) => header(),
          footer: footer,
          build: (_) => [
            if (kit.message.trim().isNotEmpty) ...[
              pw.Text(kit.message, style: const pw.TextStyle(fontSize: 13)),
              pw.SizedBox(height: 20),
            ],
            pw.Text(
              copy.instructions,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 20),
            pw.Text(copy.dates, style: const pw.TextStyle(fontSize: 17)),
            pw.SizedBox(height: 8),
            for (final timestamp in (copy.schedule.keys.toList()..sort())) ...[
              pw.Text(
                '${copy.schedule[timestamp]}: ${_utc(timestamp)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
            ],
            pw.SizedBox(height: 20),
            // Keep the handwriting fields together, including the label and
            // its blank passphrase line, even when instructions fill a page.
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(copy.words, style: const pw.TextStyle(fontSize: 17)),
                  pw.SizedBox(height: 12),
                  pw.Table(
                    columnWidths: const {
                      0: pw.FlexColumnWidth(),
                      1: pw.FlexColumnWidth(),
                    },
                    children: [
                      for (var index = 0; index < kit.wordCount; index += 2)
                        pw.TableRow(
                          children: [
                            for (var col = 0; col < 2; col++)
                              pw.Padding(
                                padding: const pw.EdgeInsets.fromLTRB(
                                  0,
                                  10,
                                  18,
                                  10,
                                ),
                                child: pw.Text(
                                  index + col < kit.wordCount
                                      ? '${index + col + 1}. ______________________'
                                      : '',
                                  style: const pw.TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    copy.passphrase,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    '________________________________________________________',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(copy.footer, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );
      // Dedicated large QR page with a generous quiet zone. The full text is
      // always present on subsequent pages, never shortened or ellipsized.
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => pw.Column(
            children: [
              header(),
              pw.SizedBox(height: 20),
              pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(24),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(
                    errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                  ),
                  data: policy.descriptor,
                  width: 475,
                  height: 475,
                  drawText: false,
                ),
              ),
              pw.Spacer(),
              footer(context),
            ],
          ),
        ),
      );
      final descriptorLines = <String>[
        for (var start = 0; start < policy.descriptor.length; start += 76)
          policy.descriptor.substring(
            start,
            (start + 76).clamp(0, policy.descriptor.length),
          ),
      ];
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          maxPages: 8,
          header: (_) => header(),
          footer: footer,
          build: (_) => [
            pw.Text(copy.descriptor, style: const pw.TextStyle(fontSize: 17)),
            pw.SizedBox(height: 12),
            pw.Text(copy.joinLines, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 20),
            for (final line in descriptorLines)
              pw.Text(
                line,
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 9,
                  lineSpacing: 3,
                ),
              ),
          ],
        ),
      );
      return Ok(await pdf.save());
    } on Exception {
      return const Err(BackupSettingsFileSaveFailure());
    }
  }

  static String _utc(int timestamp) =>
      '${DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toIso8601String().replaceFirst('T', ' ').replaceFirst('.000Z', '')} UTC';
}
