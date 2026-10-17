import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// A place's regular opening hours, as the traveller entered them: the same
/// hours every open day, plus weekdays it is closed. Times are local minutes;
/// a closing time at or before the opening time means it closes after midnight.
class OpeningHours {
  OpeningHours({required this.opens, required this.closes, Set<int> closedWeekdays = const {}})
    : closedWeekdays = Set.unmodifiable(closedWeekdays) {
    if (opens < 0 || opens >= 1440 || closes < 0 || closes > 1440) {
      throw const DomainException('Opening hours must be within the day');
    }
    if (closedWeekdays.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw const DomainException('Closed days must be Monday–Sunday');
    }
    if (closedWeekdays.length == 7) throw const DomainException('A place cannot be closed every day');
  }

  /// Minutes after midnight.
  final int opens;
  final int closes;

  /// `DateTime.monday` (1) … `DateTime.sunday` (7).
  final Set<int> closedWeekdays;

  bool get overnight => closes <= opens;

  /// Closing time on the opening day's timeline (may exceed 1440).
  int get closesAbsolute => overnight ? closes + 1440 : closes;

  bool isClosedOn(LocalDate day) => closedWeekdays.contains(day.toDateTime().weekday);

  /// Whether a visit from [start] to [end] minutes on [day] fits the hours.
  bool covers(LocalDate day, int start, int end) => !isClosedOn(day) && start >= opens && end <= closesAbsolute;

  @override
  bool operator ==(Object other) =>
      other is OpeningHours &&
      other.opens == opens &&
      other.closes == closes &&
      other.closedWeekdays.length == closedWeekdays.length &&
      other.closedWeekdays.containsAll(closedWeekdays);

  @override
  int get hashCode => Object.hash(opens, closes, Object.hashAllUnordered(closedWeekdays));
}
