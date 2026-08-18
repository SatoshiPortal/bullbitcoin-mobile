/// The Bull Bitcoin design-system component library.
///
/// Import this single barrel; it re-exports a curated `show` list of Flutter
/// layout/foundation primitives plus every `Bull*` component and the theme.
/// Internals live under `lib/src/`.
library;

// Curated re-export of Flutter foundation/layout primitives (Decision D5).
// A blanket `export 'package:flutter/widgets.dart'` is deliberately avoided —
// the list grows on demand as components need more symbols.
export 'package:flutter/widgets.dart'
    show
        Align,
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
        EdgeInsets,
        EdgeInsetsGeometry,
        Expanded,
        Flexible,
        FontFeature,
        FontWeight,
        FractionallySizedBox,
        GestureDetector,
        HitTestBehavior,
        IconData,
        Key,
        ListView,
        MainAxisAlignment,
        MainAxisSize,
        Navigator,
        NeverScrollableScrollPhysics,
        Opacity,
        Padding,
        PageController,
        PageView,
        Positioned,
        Radius,
        Row,
        SafeArea,
        SingleChildScrollView,
        SizedBox,
        Spacer,
        Stack,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        TextAlign,
        TextBaseline,
        TextDecoration,
        TextDirection,
        TextEditingController,
        TextOverflow,
        TextStyle,
        ValueChanged,
        ValueKey,
        VerticalDirection,
        VoidCallback,
        Widget,
        Wrap,
        WrapCrossAlignment;

// Material/services symbols required by component public APIs.
export 'package:flutter/material.dart'
    show DropdownMenuItem, FormFieldValidator, RefreshCallback, TextTheme;
export 'package:flutter/services.dart' show TextInputFormatter;
export 'package:flutter/widgets.dart' show FocusNode;

export 'src/layout/gap.dart' show Gap;

// Theme.
export 'src/theme/bull_icon.dart';
export 'src/theme/bull_theme.dart';
export 'src/theme/bull_tokens.dart';

// Chrome.
export 'src/chrome/bull_scaffold.dart';
export 'src/chrome/bull_selection_action_bar.dart';
export 'src/chrome/bull_success_screen.dart';
export 'src/chrome/bull_top_bar.dart';

// Buttons.
export 'src/buttons/bull_button.dart';
export 'src/buttons/bull_sync_button.dart';
export 'src/buttons/bull_tab_menu_vertical_button.dart';
export 'src/buttons/bull_tool_button.dart';
export 'src/buttons/bull_viewer_action_button.dart';

// Inputs.
export 'src/inputs/bull_amount_input_formatter.dart';
export 'src/inputs/bull_checkbox.dart';
export 'src/inputs/bull_dial_pad.dart';
export 'src/inputs/bull_dropdown.dart';
export 'src/inputs/bull_filter_chip.dart';
export 'src/inputs/bull_input_text.dart';
export 'src/inputs/bull_lowercase_input_formatter.dart';
export 'src/inputs/bull_paste_input.dart';
export 'src/inputs/bull_selectable_list.dart';

// Controls.
export 'src/controls/bull_segmented.dart';
export 'src/controls/bull_swipe_action.dart';
export 'src/controls/bull_switch.dart';

// Feedback.
export 'src/feedback/bull_countdown.dart';
export 'src/feedback/bull_async_status.dart';
export 'src/feedback/bull_fading_linear_progress.dart';
export 'src/feedback/bull_refresh_indicator.dart';
export 'src/feedback/bull_shimmer.dart';
export 'src/feedback/bull_snack_bar.dart';

// Layout.
export 'src/layout/bull_pullable_body.dart';
export 'src/layout/bull_scrollable_column.dart';
export 'src/layout/bull_stacked_page.dart';

// Data display.
export 'src/data_display/bull_address_text.dart';
export 'src/data_display/bull_backup_option_card.dart';
export 'src/data_display/bull_badge.dart';
export 'src/data_display/bull_bordered_tile.dart';
export 'src/data_display/bull_details_table.dart';
export 'src/data_display/bull_info_bar.dart';
export 'src/data_display/bull_info_card.dart';
export 'src/data_display/bull_label_chip.dart';
export 'src/data_display/bull_options_tag.dart';
export 'src/data_display/bull_price_card.dart';
export 'src/data_display/bull_settings_entry_item.dart';
export 'src/data_display/bull_stat_tile.dart';
export 'src/data_display/bull_text.dart';
export 'src/data_display/bull_transaction_direction_badge.dart';

// Overlays.
export 'src/overlays/bull_bottom_sheet.dart';
export 'src/overlays/bull_dialog.dart';
export 'src/overlays/bull_instructions_sheet.dart';
export 'src/overlays/bull_picker_sheet.dart';
