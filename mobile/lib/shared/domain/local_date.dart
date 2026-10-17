/// A calendar date with no time or zone, used for trip days.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime d) => LocalDate(d.year, d.month, d.day);

  /// Parses `yyyy-MM-dd`; returns null for null/invalid input.
  static LocalDate? tryParse(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final d = LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    final check = d.toUtc();
    return check.year == d.year && check.month == d.month && check.day == d.day ? d : null;
  }

  final int year;
  final int month;
  final int day;

  DateTime toUtc() => DateTime.utc(year, month, day);

  /// A local-midnight DateTime, for use with Material date pickers.
  DateTime toDateTime() => DateTime(year, month, day);

  LocalDate addDays(int n) => LocalDate.fromDateTime(toUtc().add(Duration(days: n)));

  /// Whole days from this date to [other] (positive if [other] is later).
  int daysUntil(LocalDate other) => other.toUtc().difference(toUtc()).inDays;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => toUtc().compareTo(other.toUtc());

  bool operator <(LocalDate o) => compareTo(o) < 0;
  bool operator >(LocalDate o) => compareTo(o) > 0;
  bool operator <=(LocalDate o) => compareTo(o) <= 0;
  bool operator >=(LocalDate o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// Parses `HH:mm` into (hour, minute).
(int, int)? parseTimeOfDay(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  if (h > 23 || min > 59) return null;
  return (h, min);
}

String formatTimeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

extension LocalDateRange on LocalDate {
  /// Days since 1970-01-01, handy for absolute minute arithmetic.
  int get epochDay => toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// Every date from this one through [last], inclusive.
  List<LocalDate> through(LocalDate last) => [for (var d = this; d <= last; d = d.addDays(1)) d];
}

/// `HH:mm` for minutes after midnight (values ≥ 1440 wrap to the next day).
String formatMinutes(int minutes) {
  final m = minutes % (24 * 60);
  return formatTimeOfDay(m ~/ 60, m % 60);
}
