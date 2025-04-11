class StringFormatting {
  static String truncateMiddle(
    String input, {
    int head = 8,
    int tail = 8,
    String placeholder = '...',
  }) {
    if (input.length <= head + tail + placeholder.length) return input;
    return '${input.substring(0, head)}$placeholder${input.substring(input.length - tail)}';
  }
}
