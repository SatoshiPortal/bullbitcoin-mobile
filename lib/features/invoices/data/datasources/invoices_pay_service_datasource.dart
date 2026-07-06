import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';

/// Implements [InvoicesPayServicePort] over the shared `bullnym` client.
/// It maps commands → wire DTOs and DTOs → domain entities, and translates
/// every `BullnymException` into an `InvoicesException` so no wire type or raw
/// server reason escapes upward.
class InvoicesPayServiceDatasource implements InvoicesPayServicePort {
  final BullnymFacade _bullnym;

  const InvoicesPayServiceDatasource({required this._bullnym});

  @override
  Future<CreateInvoiceResult> createInvoice({
    required BullnymAuthSigner signer,
    required CreateInvoiceCommand command,
    String? bitcoinAddress,
    String? liquidAddress,
    String? liquidBlindingKeyHex,
  }) async {
    final fields = BullnymCreateInvoiceFields(
      amountSat: command.amountSat,
      fiatAmountMinor: command.fiatAmountMinor,
      fiatCurrency: command.fiatCurrency,
      publicDescription: command.publicDescription,
      recipientName: command.recipientName,
      invoiceNumber: command.invoiceNumber,
      acceptBtc: command.acceptBtc,
      acceptLn: command.acceptLn,
      acceptLiquid: command.acceptLiquid,
      bitcoinAddress: bitcoinAddress,
      liquidAddress: liquidAddress,
      liquidBlindingKeyHex: liquidBlindingKeyHex,
      expiresAtUnix: _toUnix(command.expiresAt),
    );

    final BullnymCreateInvoiceResponse response;
    try {
      response = await _bullnym.createInvoice(
        signer: signer,
        nym: command.linkToPageNym,
        fields: fields,
      );
    } on BullnymException catch (e) {
      throw InvoicesException.fromBullnym(e);
    }

    return CreateInvoiceResult(
      invoiceId: _invoiceId(response.invoiceId),
      shareUrl: _invoiceUrl(response.shareUrl),
    );
  }

  @override
  Future<CancelInvoiceResult> cancelInvoice({
    required BullnymAuthSigner signer,
    required CancelInvoiceCommand command,
  }) async {
    final BullnymCancelInvoiceResponse response;
    try {
      response = await _bullnym.cancelInvoice(
        signer: signer,
        nym: command.nymOwner,
        invoiceId: command.invoiceId.value,
      );
    } on BullnymException catch (e) {
      throw InvoicesException.fromBullnym(e);
    }
    return CancelInvoiceResult(
      invoiceId: _invoiceId(response.invoiceId),
      finalStatus: InvoiceStatus.fromWire(response.status),
    );
  }

  @override
  Future<ListInvoicesResult> listInvoices({
    required BullnymAuthSigner signer,
    required ListInvoicesCommand command,
  }) async {
    final BullnymListInvoicesResponse response;
    try {
      response = await _bullnym.listInvoices(
        signer: signer,
        page: command.page,
        pageSize: command.pageSize,
        status: command.status?.wire,
      );
    } on BullnymException catch (e) {
      throw InvoicesException.fromBullnym(e);
    }
    return ListInvoicesResult(
      invoices: response.invoices.map(_toInvoice).toList(),
      page: response.page,
      pageSize: response.pageSize,
      hasMore: response.hasMore,
    );
  }

  @override
  Future<InvoiceStatusSnapshot> getInvoiceStatus(InvoiceId invoiceId) async {
    final BullnymInvoiceStatus status;
    try {
      status = await _bullnym.getInvoiceStatus(invoiceId: invoiceId.value);
    } on BullnymException catch (e) {
      throw InvoicesException.fromBullnym(e);
    }
    return InvoiceStatusSnapshot(
      status: InvoiceStatus.fromWire(status.status),
      pricingMode: status.pricingMode,
      settlementStatus: status.settlementStatus,
      amountSat: status.amountSat,
      fiatAmountMinor: status.fiatAmountMinor,
      fiatCurrency: status.fiatCurrency,
      remainingAmountSat: status.remainingAmountSat,
      paymentToleranceSat: status.paymentToleranceSat,
      rateMinorPerBtc: status.rateMinorPerBtc,
      rateLocksUntil: _fromUnix(status.rateLocksUntilUnix),
      expiresAt: _fromUnix(status.expiresAtUnix),
      paidVia: PaymentMethod.fromWire(status.paidVia),
      paidAt: status.paidAtUnix == null ? null : _fromUnix(status.paidAtUnix!),
      paidAmountSat: status.paidAmountSat,
      lightningPr: status.lightningPr,
      liquidAddress: status.liquidAddress,
      bitcoinAddress: status.bitcoinAddress,
      bitcoinChainAddress: status.bitcoinChainAddress,
      bitcoinChainBip21: status.bitcoinChainBip21,
      acceptBtc: status.acceptBtc,
      acceptLn: status.acceptLn,
      acceptLiquid: status.acceptLiquid,
    );
  }

  Invoice _toInvoice(BullnymInvoiceListItem item) {
    return Invoice(
      id: _invoiceId(item.id),
      nymOwner: item.nymOwner,
      status: InvoiceStatus.fromWire(item.status),
      amountSat: item.amountSat,
      remainingAmountSat: item.remainingAmountSat,
      fiatAmountMinor: item.fiatAmountMinor,
      fiatCurrency: item.fiatCurrency,
      publicDescription: item.publicDescription,
      recipientName: item.recipientName,
      invoiceNumber: item.invoiceNumber,
      acceptBtc: item.acceptBtc,
      acceptLn: item.acceptLn,
      acceptLiquid: item.acceptLiquid,
      bitcoinAddress: item.bitcoinAddress,
      liquidAddress: item.liquidAddress,
      createdAt: _fromUnix(item.createdAtUnix),
      expiresAt: _fromUnix(item.expiresAtUnix),
      paidVia: PaymentMethod.fromWire(item.paidVia),
      paidAt: item.paidAtUnix == null ? null : _fromUnix(item.paidAtUnix!),
      paidAmountSat: item.paidAmountSat,
    );
  }

  int _toUnix(DateTime dateTime) =>
      dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;

  DateTime _fromUnix(int unix) =>
      DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true);

  InvoiceId _invoiceId(String raw) {
    try {
      return InvoiceId(raw);
    } on ArgumentError {
      throw const InvoicesException.invalidServerResponse();
    }
  }

  InvoiceUrl _invoiceUrl(String raw) {
    try {
      return InvoiceUrl(raw);
    } on ArgumentError {
      throw const InvoicesException.invalidServerResponse();
    }
  }
}
