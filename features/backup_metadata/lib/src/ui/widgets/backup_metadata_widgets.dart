import 'package:bull_ui/bull_ui.dart';

class BackupPage extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? footer;
  final bool loading;

  const BackupPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    this.footer,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => BullScaffold(
    backgroundColor: context.bull.background,
    body: SafeArea(
      child: Column(
        children: [
          BullTopBar(title: title, onBack: onBack),
          BullFadingLinearProgress(trigger: loading),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(BullSpacing.md),
              children: children,
            ),
          ),
          if (footer case final action?)
            Padding(
              padding: const EdgeInsets.all(BullSpacing.md),
              child: SizedBox(width: double.infinity, child: action),
            ),
        ],
      ),
    ),
  );
}

class BackupSectionTitle extends StatelessWidget {
  final String title;

  const BackupSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: BullSpacing.xs),
      child: Text(
        title,
        style: context.bullType.label.copyWith(color: context.bull.textMuted),
      ),
    ),
  );
}

class BackupRowText extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;

  const BackupRowText({
    super.key,
    required this.title,
    this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: context.bullType.body.copyWith(
          fontWeight: FontWeight.w500,
          color: selected ? context.bull.primary : context.bull.text,
        ),
      ),
      if (subtitle case final detail?)
        Text(
          detail,
          style: context.bullType.label.copyWith(
            color: context.bull.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
    ],
  );
}

class BackupPickerRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const BackupPickerRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final content = Container(
      constraints: BoxConstraints(minHeight: icon == null ? 48 : 64),
      padding: const EdgeInsets.symmetric(
        horizontal: BullSpacing.sm,
        vertical: BullSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? colors.surfaceContainerHighest : null,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (icon case final glyph?) ...[
            BullIcon(glyph, color: selected ? colors.primary : colors.text),
            const Gap(BullSpacing.md),
          ],
          Expanded(
            child: BackupRowText(
              title: title,
              subtitle: subtitle,
              selected: selected,
            ),
          ),
        ],
      ),
    );
    if (onTap case final select?) {
      return Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        onTap: select,
        label: [title, ?subtitle].join('\n'),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: select,
            child: content,
          ),
        ),
      );
    }
    return content;
  }
}

class BackupSummaryEntry extends StatelessWidget {
  final String title;
  final String summary;
  final IconData icon;
  final VoidCallback onTap;

  const BackupSummaryEntry({
    super.key,
    required this.title,
    required this.summary,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BullSettingsEntryItem(
    icon: icon,
    title: title,
    onTap: onTap,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.bullType.label.copyWith(
              color: context.bull.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const BullIcon(BullIcons.chevronRight),
      ],
    ),
  );
}

class BackupInlineAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const BackupInlineAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            label,
            style: context.bullType.label.copyWith(color: context.bull.primary),
          ),
        ),
      ),
    ),
  );
}
