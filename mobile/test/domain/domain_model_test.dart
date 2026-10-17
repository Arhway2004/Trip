import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/sharing/domain/trip_package.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  Trip trip({String title = 'T', int travelers = 1, double? budget, LocalDate? start, LocalDate? end}) => Trip(
    id: 'x',
    title: title,
    timeZone: 'UTC',
    travelerCount: travelers,
    totalBudget: budget,
    startDate: start,
    endDate: end,
    createdAt: now,
    updatedAt: now,
    banner: BannerConfig.defaultFor('x'),
  );

  group('Trip invariants', () {
    test('title is required and trimmed', () {
      expect(trip(title: '  Rome ').title, 'Rome');
      expect(() => trip(title: ' '), throwsA(isA<DomainException>()));
    });
    test('traveler count is clamped, budget cannot be negative', () {
      expect(trip(travelers: 0).travelerCount, 1);
      expect(trip(travelers: 5000).travelerCount, Trip.maxTravelers);
      expect(() => trip(budget: -1), throwsA(isA<DomainException>()));
    });
    test('an end date without a start date is dropped; duration is inclusive', () {
      expect(trip(end: const LocalDate(2026, 1, 5)).endDate, isNull);
      expect(trip(start: const LocalDate(2026, 1, 1), end: const LocalDate(2026, 1, 5)).durationDays, 5);
    });
    test('clearing dates resets departure time and confirmation', () {
      final t = Trip(
        id: 'x',
        title: 'T',
        timeZone: 'UTC',
        createdAt: now,
        updatedAt: now,
        startDate: const LocalDate(2026, 2, 1),
        departureTime: '08:00',
        datesConfirmed: true,
        banner: BannerConfig.defaultFor('x'),
      ).copyWith(clearDates: true);
      expect((t.startDate, t.departureTime, t.datesConfirmed), (null, null, false));
    });
  });

  group('BannerConfig', () {
    test('default gradient is stable for a given id', () {
      expect(BannerConfig.defaultFor('abc'), BannerConfig.defaultFor('abc'));
    });
    test('withImage resets crop; withoutImage falls back to colors', () {
      final b = const BannerConfig(colorA: 1, colorB: 2).copyWith(scale: 3, alignX: 1);
      final withImg = b.withImage('a.jpg');
      expect((withImg.kind, withImg.scale, withImg.alignX), (BannerKind.photo, 1.0, 0.0));
      expect(withImg.withoutImage().kind, BannerKind.gradient);
      expect(
        const BannerConfig(colorA: 1, kind: BannerKind.photo, imagePath: 'a').withoutImage().kind,
        BannerKind.solid,
      );
    });
  });

  group('Checklist ordering', () {
    ChecklistItem item(String id, {bool done = false, LocalDate? due, int order = 0}) =>
        ChecklistItem(id: id, tripId: 't', title: id, isDone: done, dueDate: due, sortOrder: order, createdAt: now);
    test('open before done, dated before undated, earlier first', () {
      final list = [
        item('done', done: true, due: const LocalDate(2026, 1, 1)),
        item('undated'),
        item('late', due: const LocalDate(2026, 3, 1)),
        item('early', due: const LocalDate(2026, 2, 1)),
      ]..sort(compareChecklistItems);
      expect(list.map((i) => i.id), ['early', 'late', 'undated', 'done']);
    });
  });

  group('package colors', () {
    test('accepts ints, #RRGGBB and #AARRGGBB', () {
      expect(parsePackageColor(0xFF112233), 0xFF112233);
      expect(parsePackageColor('#0E7C6B'), 0xFF0E7C6B);
      expect(parsePackageColor('800E7C6B'), 0x800E7C6B);
      expect(parsePackageColor('teal'), isNull);
    });
  });
}
