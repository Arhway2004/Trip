import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/budget/domain/budget_report.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

/// Regression: a real hand-written plan (from the user) with unconfirmed
/// flight/train times was rejected as "not a WanderPlan trip file".
void main() {
  setUpAll(initTestEnvironment);
  late TestDevice d;
  setUp(() async => d = await TestDevice.create());
  tearDown(() => d.dispose());

  final fixture = File('test/fixtures/china_winter_trip_2026.json');

  test('imports the plan, keeping unknown times unknown', () async {
    final id = await d.app.packages.importFile(fixture);
    final trip = (await d.app.trips.getTrip(id))!;
    expect(trip.title, 'China Winter Adventure 2026');
    expect(trip.destinations, hasLength(8));
    expect(trip.durationDays, 11);

    final acts = await d.app.itinerary.activitiesOf(id);
    expect(acts, hasLength(31));
    final untimed = acts.where((a) => !a.hasTime).toList();
    expect(untimed, hasLength(11), reason: 'no placeholder times are invented');
    expect(untimed.map((a) => a.title), contains('Flight: Bangkok → Kunming'));

    // "transport" is a real kind now, so from/to survive.
    final jzg = acts.firstWhere((a) => a.title == 'Travel Chengdu → Jiuzhaigou');
    expect((jzg.kind, jzg.destination.name), (ActivityKind.transport, '九寨沟景区'));
    expect(acts.firstWhere((a) => a.title == 'Chengdu hotel — nights 2–4').nights, hasLength(3));

    final todos = await d.app.checklist.itemsOf(id);
    expect(todos, hasLength(12));
    expect(todos.firstWhere((t) => t.title == 'Book hotels for all ten nights').category, TodoCategory.bookings);

    final r = await d.app.budget.watchReport(id).first;
    expect(r.planned, 49500);
    expect(r.byCategory[ExpenseCategory.transport]!.planned, 4500);
    expect(r.warnings, contains(BudgetWarning.nearLimit));
  });

  test('days with unconfirmed transport say "needs info", confirmed-time days can be feasible', () async {
    final id = await d.app.packages.importFile(fixture);
    final trip = (await d.app.trips.getTrip(id))!;
    final days = assessItinerary(
      activities: await d.app.itinerary.activitiesOf(id),
      tripStart: trip.startDate,
      tripEnd: trip.endDate,
    );
    final dec3 = days.firstWhere((x) => x.date == const LocalDate(2026, 12, 3));
    expect(dec3.status, DayStatus.unknown);
    expect(dec3.issues.map((i) => i.code), contains(IssueCode.timeNotSet));
    expect(days.firstWhere((x) => x.date == const LocalDate(2026, 12, 8)).status, DayStatus.feasible);
  });

  test('untimed activities survive export and re-import', () async {
    final id = await d.app.packages.importFile(fixture);
    final file = await d.app.packages.exportTrip(id);
    final again = await d.app.packages.importFile(file);
    final acts = await d.app.itinerary.activitiesOf(again);
    expect(acts.where((a) => !a.hasTime), hasLength(11));
  });

  test('pasted text imports, including JSON wrapped in a ```json code fence', () async {
    final text = await fixture.readAsString();
    final a = await d.app.packages.importText(text);
    final b = await d.app.packages.importText('```json\n$text\n```');
    expect(a, isNot(b));
    expect((await d.app.trips.getTrip(b))!.title, 'China Winter Adventure 2026');
    await expectLater(d.app.packages.importText('   '), throwsA(isA<TripPackageException>()));
  });

  test('errors name the problem instead of a generic message', () async {
    Future<TripPackageException> failWith(Map<String, dynamic> json) async {
      try {
        await d.app.packages.importText(jsonEncode(json));
      } on TripPackageException catch (e) {
        return e;
      }
      throw StateError('expected failure');
    }

    final base = {
      'format': tripPackageFormat,
      'schemaVersion': 2,
      'trip': {'title': 'X'},
    };
    final half = await failWith({
      ...base,
      'activities': [
        {'title': 'Half', 'date': '2026-01-01', 'start': '10:00'},
      ],
    });
    expect(half.detail, allOf(contains('Half'), contains('start'), contains('end')));
    final noDate = await failWith({
      ...base,
      'activities': [
        {'title': 'Nodate'},
      ],
    });
    expect(noDate.detail, contains('date'));
    final broken = await failWith({'format': tripPackageFormat});
    expect(broken.error, TripPackageError.invalid);
    try {
      await d.app.packages.importText('{ "format": "wanderplan.trip", ');
      fail('should throw');
    } on TripPackageException catch (e) {
      expect(e.detail, isNotNull, reason: 'JSON syntax errors carry the parser message');
    }
  });
}
