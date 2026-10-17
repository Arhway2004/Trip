import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';

final tripTodosProvider = StreamProvider.family<List<ChecklistItem>, String>(
  (ref, tripId) => ref.watch(checklistServiceProvider).watchItems(tripId),
);
