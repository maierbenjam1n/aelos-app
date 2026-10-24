/// Small date and time formats for the luthier screens (no intl package).
abstract final class LuthierFormat {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "16:31"
  static String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// "18 Oct"
  static String day(DateTime t) => '${t.day} ${_months[t.month - 1]}';

  /// "1 Sep 2026"
  static String date(DateTime t) => '${day(t)} ${t.year}';

  /// "Sat 18 Oct"
  static String weekday(DateTime t) => '${_weekdays[t.weekday - 1]} ${day(t)}';

  /// "Today", "Yesterday" or "Sat 18 Oct".
  static String dayHeading(DateTime t, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final days = today.difference(_midnight(t)).inDays;
    return switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => weekday(t),
    };
  }

  /// "Today · 16:31", "Yesterday · 16:31" or "18 Oct · 16:31".
  static String when(DateTime t, {DateTime? now}) {
    final days = _midnight(now ?? DateTime.now()).difference(_midnight(t)).inDays;
    final prefix = switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => day(t),
    };
    return '$prefix · ${clock(t)}';
  }

  /// "just now", "4 min ago", "3 h ago", "6 days ago".
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    final days = d.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }

  /// "7 weeks", "3 months", "1 year 2 months"
  static String span(DateTime since, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(since);
    if (d.inDays < 14) return d.inDays <= 1 ? 'a day' : '${d.inDays} days';
    if (d.inDays < 63) return '${d.inDays ~/ 7} weeks';
    final months = d.inDays ~/ 30.4;
    if (months < 12) return '$months months';
    final years = months ~/ 12;
    final rest = months % 12;
    return '$years ${years == 1 ? 'year' : 'years'}'
        '${rest == 0 ? '' : ' $rest ${rest == 1 ? 'month' : 'months'}'}';
  }

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// Initials for a monogram, e.g. "Sofia Bianchi" → "SB".
String initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();
