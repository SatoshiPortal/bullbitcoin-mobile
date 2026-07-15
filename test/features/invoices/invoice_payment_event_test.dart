import 'package:bb_mobile/features/invoices/domain/entities/invoice_payment_event.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invoice settlement presentation', () {
    test('payment evidence is provisional until settlement is explicit', () {
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'none',
          presentationStatus: 'payment_detected',
          hasPaymentEvidence: true,
        ),
        InvoiceSettlementState.pending,
      );
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'future_state',
          presentationStatus: null,
          hasPaymentEvidence: true,
        ),
        InvoiceSettlementState.pending,
      );
    });

    test('explicit finality and problems remain distinct', () {
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'pending',
          presentationStatus: 'settled',
          hasPaymentEvidence: true,
        ),
        InvoiceSettlementState.pending,
      );
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'settled',
          presentationStatus: 'payment_detected',
          hasPaymentEvidence: true,
        ),
        InvoiceSettlementState.settled,
      );
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'reorged',
          presentationStatus: 'settled',
          hasPaymentEvidence: true,
        ),
        InvoiceSettlementState.problem,
      );
    });

    test('no evidence and no known state stays neutral', () {
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'none',
          presentationStatus: 'awaiting_payment',
          hasPaymentEvidence: false,
        ),
        InvoiceSettlementState.none,
      );
      expect(
        invoiceSettlementStateFromWire(
          settlementStatus: 'pending',
          presentationStatus: 'awaiting_payment',
          hasPaymentEvidence: false,
        ),
        InvoiceSettlementState.none,
      );
    });
  });

  group('payment event evidence', () {
    test('confirmation changes do not imply configurable finality', () {
      expect(
        invoicePaymentEventStateFromWire(
          state: 'mempool',
          confirmations: 0,
          invoiceSettlement: InvoiceSettlementState.pending,
        ),
        InvoicePaymentEventState.pending,
      );
      expect(
        invoicePaymentEventStateFromWire(
          state: 'confirmed',
          confirmations: 2,
          invoiceSettlement: InvoiceSettlementState.pending,
        ),
        InvoicePaymentEventState.confirming,
      );
      expect(
        invoicePaymentEventStateFromWire(
          state: 'confirmed',
          confirmations: 3,
          invoiceSettlement: InvoiceSettlementState.settled,
        ),
        InvoicePaymentEventState.settled,
      );
    });

    test('eviction, reorg, conflict and replacement stay visible', () {
      expect(
        invoicePaymentProblemFromWire('mempool_evicted'),
        InvoicePaymentProblem.evicted,
      );
      expect(
        invoicePaymentProblemFromWire('reorged'),
        InvoicePaymentProblem.reorged,
      );
      expect(
        invoicePaymentProblemFromWire('double_spend_conflict'),
        InvoicePaymentProblem.conflicted,
      );
      expect(
        invoicePaymentProblemFromWire('replaced'),
        InvoicePaymentProblem.replaced,
      );
    });

    test('invalid amounts and inconsistent problem state are rejected', () {
      expect(
        () => InvoicePaymentEvent(
          rail: PaymentMethod.btc,
          amountSat: -1,
          firstSeenAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
          state: InvoicePaymentEventState.pending,
          confirmations: 0,
          isLate: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => InvoicePaymentEvent(
          rail: PaymentMethod.btc,
          amountSat: 1,
          firstSeenAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
          state: InvoicePaymentEventState.problem,
          confirmations: 0,
          isLate: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
