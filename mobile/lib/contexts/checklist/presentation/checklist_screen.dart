import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/checklist/presentation/checklist_providers.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/checklist/presentation/checklist_l10n.dart';

/// "Before you go" checklist for one trip.
class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  bool _hideDone = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final trip = ref.watch(tripProvider(widget.tripId)).value;
    final todos = ref.watch(tripTodosProvider(widget.tripId)).value ?? const <ChecklistItem>[];
    final now = ref.watch(currentTimeProvider);
    final today = todayIn(trip?.trip.timeZone ?? 'UTC', now);
    final done = todos.where((t) => t.isDone).length;
    final visible = _hideDone ? todos.where((t) => !t.isDone).toList() : todos;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.todosTitle),
        actions: [
          IconButton(
            tooltip: l.todoSuggestions,
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _showSuggestions(context, todos),
          ),
          IconButton(
            tooltip: l.todoHideDone,
            isSelected: _hideDone,
            icon: const Icon(Icons.visibility_outlined),
            selectedIcon: const Icon(Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hideDone = !_hideDone),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTodoEditor(context, ref, tripId: widget.tripId, departure: trip?.start),
        icon: const Icon(Icons.add_task),
        label: Text(l.todoAdd),
      ),
      body: Column(
        children: [
          if (todos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done == todos.length ? l.todosAllDone : l.todosProgress(done, todos.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: done / todos.length, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          Expanded(
            child: todos.isEmpty
                ? _Empty(onSuggestions: () => _showSuggestions(context, todos))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: visible.length,
                    itemBuilder: (context, i) => _TodoTile(
                      key: ValueKey(visible[i].id),
                      todo: visible[i],
                      today: today,
                      departure: trip?.start,
                      onEdit: () => showTodoEditor(
                        context,
                        ref,
                        tripId: widget.tripId,
                        departure: trip?.start,
                        existing: visible[i],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuggestions(BuildContext context, List<ChecklistItem> existing) async {
    final l = context.l10n;
    final existingTitles = existing.map((t) => t.title.toLowerCase()).toSet();
    final available = TodoSuggestion.values.where((s) => !existingTitles.contains(s.label(l).toLowerCase())).toList();
    final picked = await showModalBottomSheet<List<TodoSuggestion>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SuggestionSheet(available: available),
    );
    if (picked == null || picked.isEmpty) return;
    await ref.read(checklistServiceProvider).addItems(widget.tripId, [
      for (final s in picked) TodoDraft(title: s.label(l), category: s.category),
    ]);
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({super.key, required this.todo, required this.today, required this.departure, required this.onEdit});

  final ChecklistItem todo;
  final LocalDate today;
  final LocalDate? departure;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final repo = ref.read(checklistServiceProvider);
    final category = todo.category;
    final dueDate = todo.dueDate;
    final due = todoDue(due: dueDate, today: today);
    final afterDeparture = dueDate != null && departure != null && dueDate > departure!;

    final subtitle = <String>[
      category.label(l),
      if (dueDate != null && !todo.isDone) '${formatDate(context, dueDate)} · ${todoDueLabel(l, due)}',
      if (afterDeparture && !todo.isDone) l.todoAfterDeparture,
      if (todo.notes != null) todo.notes!,
    ].join('\n');
    final warn = !todo.isDone && (due is TodoOverdue || afterDeparture);

    return Dismissible(
      key: ValueKey('dismiss-${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await repo.deleteItem(todo.id);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.todoDeleted),
            action: SnackBarAction(label: l.undo, onPressed: () => repo.restoreItem(todo)),
          ),
        );
      },
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: todo.isDone,
        onChanged: (v) => repo.setDone(todo.id, v ?? false),
        title: Text(
          todo.title,
          style: todo.isDone
              ? TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.outline)
              : null,
        ),
        subtitle: Text(subtitle, style: warn ? TextStyle(color: theme.colorScheme.error) : null),
        secondary: IconButton(tooltip: l.todoEdit, icon: Icon(category.icon), onPressed: onEdit),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSuggestions});
  final VoidCallback onSuggestions;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rtl, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(l.todosEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onSuggestions,
              icon: const Icon(Icons.playlist_add),
              label: Text(l.todoSuggestions),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionSheet extends StatefulWidget {
  const _SuggestionSheet({required this.available});
  final List<TodoSuggestion> available;

  @override
  State<_SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends State<_SuggestionSheet> {
  final _selected = <TodoSuggestion>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l.todoSuggestionsTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in widget.available)
                CheckboxListTile(
                  value: _selected.contains(s),
                  onChanged: (v) => setState(() => v == true ? _selected.add(s) : _selected.remove(s)),
                  title: Text(s.label(l)),
                  subtitle: Text(s.category.label(l)),
                  secondary: Icon(s.category.icon),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, [
                        for (final s in widget.available)
                          if (_selected.contains(s)) s,
                      ]),
                child: Text(l.todoAddSelected(_selected.length)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet to add a task, or edit [existing].
Future<void> showTodoEditor(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  LocalDate? departure,
  ChecklistItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TodoEditor(tripId: tripId, departure: departure, existing: existing),
  );
}

class _TodoEditor extends ConsumerStatefulWidget {
  const _TodoEditor({required this.tripId, this.departure, this.existing});
  final String tripId;
  final LocalDate? departure;
  final ChecklistItem? existing;

  @override
  ConsumerState<_TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends ConsumerState<_TodoEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late TodoCategory _category = widget.existing?.category ?? TodoCategory.other;
  late LocalDate? _due = widget.existing?.dueDate;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final draft = TodoDraft(title: _title.text, notes: _notes.text, category: _category, dueDate: _due);
    final repo = ref.read(checklistServiceProvider);
    if (widget.existing == null) {
      await repo.addItems(widget.tripId, [draft]);
    } else {
      await repo.updateItem(widget.existing!.id, draft);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? l.todoAdd : l.todoEdit, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.todoTitleField),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TodoCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l.todoCategory),
            items: [
              for (final c in TodoCategory.values)
                DropdownMenuItem(
                  value: c,
                  child: Row(children: [Icon(c.icon, size: 20), const SizedBox(width: 12), Text(c.label(l))]),
                ),
            ],
            onChanged: (c) => setState(() => _category = c ?? TodoCategory.other),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l.todoDueDate),
            subtitle: Text(_due == null ? l.todoNoDueDate : formatDate(context, _due!)),
            trailing: _due == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _due = null)),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 30),
                initialDate: (_due ?? widget.departure?.addDays(-1) ?? LocalDate.fromDateTime(now)).toDateTime(),
              );
              if (picked != null) setState(() => _due = LocalDate.fromDateTime(picked));
            },
          ),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(labelText: l.todoNotes, helperText: l.optional),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _title.text.trim().isEmpty ? null : _save, child: Text(l.actionSave)),
        ],
      ),
    );
  }
}
