import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SnapScrollList<T> extends StatefulWidget {
  const SnapScrollList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemHeight,
    this.visibleItemCount = 1,
    this.onExpand,
    this.showExpandHint = true,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemHeight;
  final int visibleItemCount;
  final VoidCallback? onExpand;
  final bool showExpandHint;

  @override
  State<SnapScrollList<T>> createState() => _SnapScrollListState<T>();
}

class _SnapScrollListState<T> extends State<SnapScrollList<T>> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCount = widget.visibleItemCount.clamp(1, widget.items.length);
    final totalHeight = widget.itemHeight * visibleCount;
    final hasMore = widget.items.length > visibleCount;
    final remainingCount = widget.items.length - visibleCount;

    if (visibleCount >= widget.items.length) {
      return SizedBox(
        height: totalHeight,
        child: Column(
          children: widget.items.asMap().entries.map((entry) {
            return SizedBox(
              height: widget.itemHeight,
              child: widget.itemBuilder(context, entry.value, entry.key),
            );
          }).toList(),
        ),
      );
    }

    return GestureDetector(
      onTap: hasMore ? widget.onExpand : null,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: (widget.items.length / visibleCount).ceil(),
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * visibleCount;
                return Column(
                  children: List.generate(visibleCount, (i) {
                    final itemIndex = startIndex + i;
                    if (itemIndex >= widget.items.length) {
                      return SizedBox(height: widget.itemHeight);
                    }
                    return SizedBox(
                      height: widget.itemHeight,
                      child: widget.itemBuilder(
                        context,
                        widget.items[itemIndex],
                        itemIndex,
                      ),
                    );
                  }),
                );
              },
            ),
            if (hasMore && widget.showExpandHint)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.appColors.background.withValues(alpha: 0),
                          context.appColors.background.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$remainingCount items',
                            style: context.font.labelSmall?.copyWith(
                              color: context.appColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 12,
                            color: context.appColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
