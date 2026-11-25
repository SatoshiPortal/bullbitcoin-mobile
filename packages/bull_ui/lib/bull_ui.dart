/// The Bull Bitcoin design-system component library.
///
/// Import this single barrel; it re-exports a curated `show` list of Flutter
/// layout/foundation primitives plus every `Bull*` component and the theme.
/// Internals live under `lib/src/`.
library;

export 'src/buttons/bull_field_action.dart';
export 'src/chrome/bull_step_bar.dart';
export 'src/payments/bull_payment_animation.dart';
export 'src/payments/bull_payment_progress.dart';
export 'src/payments/bull_payment_step_rail.dart';
export 'src/payments/bull_payment_transition.dart';
export 'src/payments/bull_payment_view_switch.dart';

export 'package:flutter/services.dart'
    show SmartDashesType, SmartQuotesType, HapticFeedback;
export 'package:flutter/semantics.dart' show CustomSemanticsAction;

// Curated re-export of Flutter foundation/layout primitives (Decision D5).
// A blanket `export 'package:flutter/widgets.dart'` is deliberately avoided —
// the list grows on demand as components need more symbols.
export 'package:flutter/widgets.dart'
    show
        AbsorbPointer,
        Align,
        AppLifecycleListener,
        AppLifecycleState,
        Alignment,
        AlwaysScrollableScrollPhysics,
        AnimatedContainer,
        AnimatedPositioned,
        AnimatedSize,
        AspectRatio,
        Axis,
        Border,
        BorderRadius,
        BorderSide,
        BoxConstraints,
        BoxDecoration,
        BoxShape,
        BuildContext,
        Center,
        Color,
        Column,
        ConstrainedBox,
        Container,
        CrossAxisAlignment,
        Curves,
        DragTarget,
        DragTargetDetails,
        EdgeInsets,
        EdgeInsetsGeometry,
        Expanded,
        ExcludeSemantics,
        Semantics,
        Flexible,
        FontFeature,
        FontWeight,
        FractionallySizedBox,
        GestureDetector,
        GlobalKey,
        HitTestBehavior,
        IconData,
        IgnorePointer,
        IntrinsicHeight,
        Key,
        LayoutBuilder,
        Locale,
        Localizations,
        LocalizationsDelegate,
        ListView,
        LongPressDraggable,
        MainAxisAlignment,
        MainAxisSize,
        MediaQuery,
        MergeSemantics,
        Navigator,
        NeverScrollableScrollPhysics,
        Opacity,
        Overlay,
        OverlayState,
        Padding,
        PageController,
        PageScrollPhysics,
        PageView,
        PlaceholderAlignment,
        Positioned,
        PopScope,
        Radius,
        Row,
        SafeArea,
        ScrollController,
        SingleChildScrollView,
        SizedBox,
        Spacer,
        StackFit,
        Stack,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        TextAlign,
        TextBaseline,
        TextDecoration,
        TextDecorationStyle,
        TextDirection,
        TextEditingController,
        TextOverflow,
        TextSpan,
        TextStyle,
        ValueChanged,
        ValueKey,
        VerticalDirection,
        VoidCallback,
        Widget,
        WidgetsBinding,
        WidgetsBindingObserver,
        WidgetSpan,
        Wrap,
        WrapCrossAlignment;

// Material/services symbols required by component public APIs.
export 'package:material_ui/material_ui.dart'
    show
        FormFieldValidator,
        MaterialPageRoute,
        RefreshCallback,
        RefreshIndicatorState,
        TextTheme;
export 'package:flutter/services.dart' show TextInputFormatter;
export 'package:flutter/widgets.dart' show FocusNode;

export 'src/layout/gap.dart' show Gap;

// Theme.
export 'src/theme/bull_icon.dart';
export 'src/theme/bull_keypad_colors.dart';
export 'src/theme/bull_loader_theme.dart';
export 'src/theme/bull_shapes.dart';
export 'src/theme/bull_theme.dart';
export 'src/theme/bull_tokens.dart';
export 'src/theme/payment_animation_palette.dart';
export 'src/theme/bull_typography.dart';
export 'src/theme/bull_ui_extensions.dart';

// Chrome.
export 'src/chrome/bull_scaffold.dart';
export 'src/chrome/bull_selection_action_bar.dart';
export 'src/chrome/bull_success_screen.dart';
export 'src/chrome/bull_top_bar.dart';
export 'src/chrome/bull_transaction_details_page.dart';

// Buttons.
export 'src/buttons/bull_advanced_options_link.dart'
    show BullAdvancedOptionsLink;
export 'src/buttons/bull_button.dart';
export 'src/buttons/bull_receive_send_buttons.dart';
export 'src/buttons/bull_inline_buttons.dart';
export 'src/buttons/bull_sync_button.dart';
export 'src/buttons/bull_tab_menu_vertical_button.dart';
export 'src/buttons/bull_tool_button.dart';
export 'src/buttons/bull_quick_action.dart';
export 'src/buttons/bull_viewer_action_button.dart';

// Inputs.
export 'src/inputs/bull_amount_input.dart';
export 'src/inputs/bull_amount_input_value.dart';
export 'src/inputs/bull_amount_input_formatter.dart';
export 'src/inputs/bull_checkbox.dart';
export 'src/inputs/bull_copy_field.dart';
export 'src/inputs/bull_dropdown.dart';
export 'src/inputs/bull_dropdown_menu.dart' show showBullDropdownMenu;
export 'src/inputs/bull_filter_chip.dart';
export 'src/inputs/bull_input_text.dart';
export 'src/inputs/bull_payment_destination_input.dart';
export 'src/inputs/bull_keypad.dart' show BullKeyScramble;
export 'src/inputs/bull_language_picker.dart';
export 'src/inputs/bull_picker_chip.dart';
export 'src/inputs/bull_picker_item.dart';
export 'src/inputs/bull_keyboard_actions.dart';
export 'src/inputs/bull_labeled_text_input.dart';
export 'src/inputs/bull_lowercase_input_formatter.dart';
export 'src/inputs/bull_mnemonic_keyboard.dart';
export 'src/inputs/bull_paste_input.dart';
export 'src/inputs/bull_search_bar.dart';
export 'src/inputs/bull_pin_dots.dart';
export 'src/inputs/bull_pin_pad.dart';
export 'src/inputs/bull_secret_text_input.dart';
export 'src/inputs/bull_selectable_list.dart';

// Controls.
export 'src/controls/bull_segmented.dart';
export 'src/controls/bull_swipe_action.dart';
export 'src/controls/bull_switch.dart';

// Feedback.
export 'src/feedback/bull_screen_privacy_gate.dart';
export 'src/feedback/bull_countdown.dart';
export 'src/feedback/bull_error_state.dart';
export 'src/feedback/bull_async_status.dart';
export 'src/feedback/bull_fading_linear_progress.dart';
export 'src/feedback/bull_reference_notice.dart';
export 'src/feedback/bull_refresh_indicator.dart';
export 'src/feedback/bull_shimmer.dart';
export 'src/feedback/bull_loader.dart';
export 'src/feedback/bull_payment_preparation_view.dart';
export 'src/feedback/bull_snack_bar.dart';

// Layout.
export 'src/layout/bull_carousel.dart';
export 'src/layout/bull_onchain_send_info_section.dart';
export 'src/layout/bull_stream_value_builder.dart';
export 'src/layout/bull_pullable_body.dart';
export 'src/layout/bull_scrollable_column.dart';
export 'src/layout/bull_stacked_page.dart';

// Data display.
export 'src/data_display/bull_alert_card.dart';
export 'src/data_display/bull_amount.dart';
export 'src/data_display/bull_amount_scope.dart';
export 'generated/l10n/bull_ui_localizations.dart';
export 'src/data_display/bull_address_text.dart';
export 'src/data_display/bull_backup_option_card.dart';
export 'src/data_display/bull_badge.dart';
export 'src/data_display/bull_bordered_tile.dart';
export 'src/data_display/bull_date_locale.dart';
export 'src/data_display/bull_details_table.dart';
export 'src/data_display/bull_payment_confirmation.dart';
export 'src/data_display/bull_info_bar.dart';
export 'src/data_display/bull_info_card.dart';
export 'src/data_display/bull_label_chip.dart';
export 'src/data_display/bull_options_tag.dart';
export 'src/data_display/bull_price_card.dart';
export 'src/data_display/bull_qr_code.dart';
export 'src/data_display/bull_settings_entry_item.dart';
export 'src/data_display/bull_settings_entry_tile.dart';
export 'src/data_display/bull_server_tile.dart';
export 'src/data_display/bull_stat_tile.dart';
export 'src/data_display/bull_invoice_viewer.dart';
export 'src/data_display/bull_transaction_viewer.dart';
export 'src/data_display/bull_text.dart';
export 'src/data_display/bull_time_ago.dart';
export 'src/data_display/bull_transaction_direction_badge.dart';
export 'src/data_display/bull_transaction_list_item.dart';
export 'src/data_display/bull_transactions_by_day_list.dart';

// Support.
export 'src/support/bull_support_button.dart';
export 'src/support/bull_support_scope.dart';

// Overlays.
export 'src/overlays/bull_bottom_sheet.dart';
export 'src/overlays/bull_confirm_dialog.dart';
export 'src/overlays/bull_dialog.dart';
export 'src/overlays/bull_disclosure_sheet.dart';
export 'src/overlays/bull_instructions_sheet.dart';
export 'src/overlays/bull_picker_sheet.dart';

export 'src/localization/bull_ui_localizations_delegate.dart';
