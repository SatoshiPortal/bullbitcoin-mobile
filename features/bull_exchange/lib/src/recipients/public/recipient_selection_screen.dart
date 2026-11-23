import 'package:bull_exchange/src/recipients/ui/screens/recipients_screen.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/src/recipients/public/recipient_selection.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_failure_l10n.dart';
import 'package:flutter/widgets.dart';

/// Public recipients picker that does not expose recipients feature internals.
class RecipientSelectionScreen extends StatefulWidget {
  const RecipientSelectionScreen({
    required this.types,
    required Future<void>? Function(RecipientSelection, {required bool isNew})
    this._onRecipientSelected,
    this.isOwner,
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
    super.key,
  }) : returnsSelection = false;

  const RecipientSelectionScreen.returning({
    required this.types,
    this.isOwner,
    super.key,
  }) : returnsSelection = true,
       _onRecipientSelected = null,
       isHookRunning = null,
       onRecipientAddedHookError = null,
       onRecipientSelectedHookError = null;

  final List<RecipientType> types;
  final bool? isOwner;
  final Future<void>? Function(RecipientSelection, {required bool isNew})?
  _onRecipientSelected;
  final bool returnsSelection;
  final bool? isHookRunning;
  final String? onRecipientAddedHookError;
  final String? onRecipientSelectedHookError;

  @override
  State<RecipientSelectionScreen> createState() =>
      _RecipientSelectionScreenState();
}

class _RecipientSelectionScreenState extends State<RecipientSelectionScreen> {
  bool _hasPopped = false;
  RecipientsFailure? _newSelectionFailure;
  RecipientsFailure? _savedSelectionFailure;

  Future<void> _onSelected(
    RecipientViewModel recipient, {
    required bool isNew,
  }) async {
    if (_hasPopped || !mounted) return;
    final selection = _toSelection(recipient);
    if (widget.returnsSelection) {
      if (!widget.types.contains(recipient.type) ||
          (widget.isOwner != null && recipient.isOwner != widget.isOwner)) {
        setState(() {
          if (isNew) {
            _newSelectionFailure = const RecipientsSavedButNotSelectedFailure();
          } else {
            _savedSelectionFailure = const RecipientsSelectionFailure();
          }
        });
        return;
      }
      _hasPopped = true;
      Navigator.of(context).pop(selection);
    } else {
      await widget._onRecipientSelected?.call(selection, isNew: isNew);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _hasPopped = true;
      },
      child: RecipientsScreen(
        filter: RecipientFilterCriteria(
          types: widget.types,
          isOwner: widget.isOwner,
        ),
        onRecipientSelected: _onSelected,
        enforceRecipientFilter: widget.returnsSelection,
        fixedRecipientType: widget.returnsSelection && widget.types.length == 1
            ? widget.types.single
            : null,
        isHookRunning: widget.isHookRunning,
        onRecipientAddedHookError:
            _newSelectionFailure?.toTranslated(context) ??
            widget.onRecipientAddedHookError,
        onRecipientSelectedHookError:
            _savedSelectionFailure?.toTranslated(context) ??
            widget.onRecipientSelectedHookError,
      ),
    );
  }

  RecipientSelection _toSelection(RecipientViewModel recipient) {
    return RecipientSelection(
      id: recipient.id,
      type: recipient.type,
      displayName: recipient.displayName,
      email: recipient.email,
      securityQuestion: recipient.securityQuestion,
      securityAnswer: recipient.securityAnswer,
      payeeName: recipient.payeeName,
      payeeCode: recipient.payeeCode,
      payeeAccountNumber: recipient.payeeAccountNumber,
      institutionNumber: recipient.institutionNumber,
      transitNumber: recipient.transitNumber,
      accountNumber: recipient.accountNumber,
      iban: recipient.iban,
      clabe: recipient.clabe,
      phoneNumber: recipient.phoneNumber,
      debitcard: recipient.debitcard,
      bankAccount: recipient.bankAccount,
      isVirtualPayeeActive: recipient.isVirtualPayeeActive,
    );
  }
}
