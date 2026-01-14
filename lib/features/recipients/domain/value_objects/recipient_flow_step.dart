/// Defines the current step in the recipient selection flow.
/// Used for multi-step flows like sell/withdraw where VIBAN activation may be required.
enum RecipientFlowStep {
  /// Step 1: Select jurisdiction and recipient type
  selectType,

  /// Step 2: Enter recipient details form
  enterDetails,

  /// Step 2.5: VIBAN activation (when frPayee selected without active VIBAN)
  activateVirtualIban,
}
