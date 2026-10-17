import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

import '../helpers.dart';

void main() {
  late TestDevice d;
  setUpAll(initTestEnvironment);
  setUp(() async => d = await TestDevice.create());
  tearDown(() => d.dispose());

  Future<String> trip(String t) => d.app.trips.createTrip(TripDraft(title: t, timeZone: 'UTC'));

  test('lists are per trip, ordered open-first by due date, and counted on the trip', () async {
    final a = await trip('A');
    final b = await trip('B');
    await d.app.checklist.addItems(a, [
      TodoDraft(title: 'No date'),
      TodoDraft(title: 'Later', dueDate: const LocalDate(2026, 11, 20)),
      TodoDraft(title: 'Soon', dueDate: const LocalDate(2026, 11, 1), category: TodoCategory.documents),
      TodoDraft(title: '   '),
    ]);
    await d.app.checklist.addItems(b, [TodoDraft(title: 'Other trip')]);

    var list = await d.app.checklist.itemsOf(a);
    expect(list.map((t) => t.title), ['Soon', 'Later', 'No date']);
    expect(list.first.category, TodoCategory.documents);

    await d.app.checklist.setDone(list.first.id, true);
    list = await d.app.checklist.itemsOf(a);
    expect(list.map((t) => t.title), ['Later', 'No date', 'Soon']);
    expect(list.last.doneAt, isNotNull);

    final s = (await d.app.tripQueries.watchSummary(a).first)!;
    expect((s.todosDone, s.todosTotal), (1, 3));
    expect((await d.app.tripQueries.watchSummary(b).first)!.todosTotal, 1);
  });

  test('edit, delete and undo', () async {
    final a = await trip('A');
    final id = (await d.app.checklist.addItems(a, [TodoDraft(title: 'Visa')])).single;
    await d.app.checklist.updateItem(
      id,
      TodoDraft(title: 'Visa check', notes: ' bring photos ', category: TodoCategory.documents),
    );
    final item = (await d.app.checklist.itemsOf(a)).single;
    expect((item.title, item.notes, item.category), ('Visa check', 'bring photos', TodoCategory.documents));

    await d.app.checklist.deleteItem(id);
    expect(await d.app.checklist.itemsOf(a), isEmpty);
    await d.app.checklist.restoreItem(item);
    expect((await d.app.checklist.itemsOf(a)).single.title, 'Visa check');
  });

  test('migrating a v1 database keeps trips and adds the checklist table', () async {
    final dir = await Directory.systemTemp.createTemp('wanderplan_mig_');
    final file = File('${dir.path}/app.sqlite');

    var v = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    final id = await v.app.trips.createTrip(TripDraft(title: 'Old', timeZone: 'UTC'));
    await v.db.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE trip_todos');
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    v = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    expect((await v.app.trips.getTrip(id))!.title, 'Old');
    await v.app.checklist.addItems(id, [TodoDraft(title: 'Works after upgrade')]);
    expect(await v.app.checklist.itemsOf(id), hasLength(1));
    await v.dispose();
    await dir.delete(recursive: true);
  });
}
