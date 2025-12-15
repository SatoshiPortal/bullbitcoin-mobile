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

  static String capitalize(String input) =>
      input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);

  static String camelCaseToTitleCase(String input, {String separator = ''}) {
    final spaced = input.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (match) => '${match.group(1)}$separator${match.group(2)}',
    );

    return spaced
        .split(separator)
        .map((word) => capitalize(word))
        .join(separator);
  }
}
