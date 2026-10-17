import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/budget/application/rate_source.dart';
import 'package:wanderplan/contexts/budget/domain/budget_report.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/budget/presentation/budget_l10n.dart';
import 'package:wanderplan/contexts/budget/presentation/budget_providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/shared/domain/currency.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(tripProvider(tripId)).value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(summary == null ? l.tabBudget : '${l.tabBudget} · ${summary.trip.title}'),
          bottom: TabBar(
            tabs: [
              Tab(text: l.budgetOverview),
              Tab(text: l.budgetExpenses),
              Tab(text: l.budgetRates),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showExpenseEditor(context, tripId: tripId),
          icon: const Icon(Icons.add),
          label: Text(l.addExpense),
        ),
        body: TabBarView(
          children: [
            _Overview(tripId: tripId),
            _ExpensesTab(tripId: tripId),
            _RatesTab(tripId: tripId),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ overview

class _Overview extends ConsumerWidget {
  const _Overview({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final report = ref.watch(budgetReportProvider(tripId)).value;
    if (report == null) return const Center(child: CircularProgressIndicator());
    final cur = report.currency;
    String money(double v) => cur == null ? v.toStringAsFixed(0) : formatMoney(context, v, cur);

    final total = report.totalBudget;
    final remaining = report.remainingCash;
    final tiles = [
      KpiTile(
        icon: Icons.savings_outlined,
        label: l.budgetLimit,
        value: total == null ? '—' : money(total),
        sub: total == null ? l.budgetNotSet : null,
        onTap: () => context.push(Routes.editTrip(tripId)),
      ),
      KpiTile(
        icon: Icons.event_note_outlined,
        label: l.budgetPlanned,
        value: money(report.planned),
        sub: report.travelerCount > 1 ? l.budgetPerPerson(money(report.plannedPerPerson)) : null,
        tone: total != null && report.planned > total ? Tone.bad : null,
      ),
      KpiTile(
        icon: Icons.receipt_long_outlined,
        label: l.budgetSpent,
        value: money(report.actual),
        sub: report.travelerCount > 1 ? l.perPersonSpent(money(report.actualPerPerson)) : null,
      ),
      KpiTile(
        icon: Icons.account_balance_wallet_outlined,
        label: l.budgetRemaining,
        value: remaining == null ? '—' : money(remaining),
        tone: remaining == null ? null : (remaining < 0 ? Tone.bad : Tone.good),
      ),
    ];

    final cats = [
      for (final e in report.byCategory.entries)
        if (e.value.planned > 0 || e.value.actual > 0) e,
    ]..sort((a, b) => (b.value.planned + b.value.actual).compareTo(a.value.planned + a.value.actual));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 640 ? 4 : 2;
            final w = (box.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        if (total != null && total > 0) ...[
          const SizedBox(height: 16),
          _UsageBar(label: l.budgetPlanned, value: report.planned, total: total, color: c.chartPlanned, money: money),
          const SizedBox(height: 8),
          _UsageBar(label: l.budgetSpent, value: report.actual, total: total, color: c.chartActual, money: money),
        ],
        for (final w in report.warnings) ...[const SizedBox(height: 8), _warning(context, w, report, money)],
        if (report.unpaidPlanned > 0) ...[
          const SizedBox(height: 8),
          Badge2(
            icon: Icons.pending_actions_outlined,
            tone: Tone.info,
            label: l.unpaidPlanned(money(report.unpaidPlanned)),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: l.plannedVsActual,
          icon: Icons.bar_chart,
          child: cats.isEmpty
              ? Text(l.budgetEmpty, style: TextStyle(color: c.ink2))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Legend(),
                    const SizedBox(height: 12),
                    for (final e in cats)
                      _PairedBar(
                        icon: e.key.icon,
                        label: e.key.label(l),
                        planned: e.value.planned,
                        actual: e.value.actual,
                        max: cats
                            .map((x) => x.value.planned > x.value.actual ? x.value.planned : x.value.actual)
                            .reduce((a, b) => a > b ? a : b),
                        money: money,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _ByDay(report: report, money: money),
      ],
    );
  }

  Widget _warning(BuildContext context, BudgetWarning w, BudgetReport r, String Function(double) money) {
    final l = context.l10n;
    return switch (w) {
      BudgetWarning.noCurrency => Badge2(tone: Tone.warn, icon: Icons.warning_amber_rounded, label: l.warnNoCurrency),
      BudgetWarning.missingRates => Badge2(
        tone: Tone.warn,
        icon: Icons.currency_exchange,
        label: l.warnMissingRates(r.unconvertedCurrencies.join(', ')),
      ),
      BudgetWarning.overBudgetPlanned => Badge2(
        tone: Tone.bad,
        icon: Icons.error_outline,
        label: l.warnOverPlanned(money(r.planned - r.totalBudget!)),
      ),
      BudgetWarning.overBudgetActual => Badge2(
        tone: Tone.bad,
        icon: Icons.error_outline,
        label: l.warnOverActual(money(r.actual - r.totalBudget!)),
      ),
      BudgetWarning.nearLimit => Badge2(tone: Tone.warn, icon: Icons.warning_amber_rounded, label: l.warnNearLimit),
    };
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.money,
  });
  final String label;
  final double value;
  final double total;
  final Color color;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = total <= 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${money(value)} / ${money(total)} · ${(ratio * 100).round()}%',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.ink2, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 8,
            color: ratio > 1 ? c.bad : color,
            backgroundColor: c.line,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    Widget item(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: c.ink2, fontSize: 12)),
      ],
    );
    return Wrap(spacing: 16, children: [item(c.chartPlanned, l.budgetPlanned), item(c.chartActual, l.budgetSpent)]);
  }
}

/// Two thin bars per category (planned vs actual) on one shared scale,
/// each labelled with its value so identity never relies on color alone.
class _PairedBar extends StatelessWidget {
  const _PairedBar({
    required this.icon,
    required this.label,
    required this.planned,
    required this.actual,
    required this.max,
    required this.money,
  });

  final IconData icon;
  final String label;
  final double planned;
  final double actual;
  final double max;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = context.l10n;
    Widget bar(double v, Color color, String name) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: Tooltip(
                  message: '$name: ${money(v)}',
                  child: Container(
                    width: max <= 0 ? 0 : (box.maxWidth * v / max).clamp(v > 0 ? 3.0 : 0.0, box.maxWidth),
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              money(v),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: v == 0 ? c.ink3 : c.ink2),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.ink3),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          bar(planned, c.chartPlanned, l.budgetPlanned),
          bar(actual, c.chartActual, l.budgetSpent),
        ],
      ),
    );
  }
}

class _ByDay extends StatelessWidget {
  const _ByDay({required this.report, required this.money});
  final BudgetReport report;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final days = {...report.byDayPlanned.keys, ...report.byDayActual.keys}.toList()..sort();
    if (days.isEmpty) return const SizedBox();
    return SectionCard(
      title: l.byDay,
      icon: Icons.calendar_month_outlined,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 96,
                child: Text(
                  l.budgetPlanned,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: c.ink3),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  l.budgetSpent,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: c.ink3),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(DateFormat.MMMEd(context.localeTag).format(d.toDateTime()))),
                  SizedBox(width: 96, child: Text(money(report.byDayPlanned[d] ?? 0), textAlign: TextAlign.end)),
                  SizedBox(width: 96, child: Text(money(report.byDayActual[d] ?? 0), textAlign: TextAlign.end)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ expenses

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final expenses = ref.watch(tripExpensesProvider(tripId)).value ?? const <Expense>[];
    final costed = (ref.watch(tripActivitiesProvider(tripId)).value ?? const <Activity>[])
        .where((a) => a.cost != null && !a.isCancelled)
        .toList();
    final svc = ref.read(budgetServiceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      children: [
        if (expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l.noExpenses,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.ink3),
            ),
          ),
        for (final e in expenses)
          Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: AlignmentDirectional.centerEnd,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: c.badBg,
              child: Icon(Icons.delete_outline, color: c.bad),
            ),
            onDismissed: (_) async {
              final messenger = ScaffoldMessenger.of(context);
              await svc.deleteExpense(e.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l.expenseDeleted),
                  action: SnackBarAction(label: l.undo, onPressed: () => svc.restoreExpense(e)),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                backgroundColor: c.surface2,
                child: Icon(e.category.icon, color: c.ink2, size: 20),
              ),
              title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Badge2(
                    label: e.kind == ExpenseKind.planned ? l.expensePlanned : l.expenseActual,
                    tone: e.kind == ExpenseKind.planned ? Tone.info : Tone.brand,
                  ),
                  if (e.date != null) Badge2(label: formatDate(context, e.date!)),
                  if (!e.isPaid) Badge2(label: l.expenseUnpaid, tone: Tone.warn),
                ],
              ),
              trailing: Text(
                formatMoney(context, e.amount, e.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => showExpenseEditor(context, tripId: tripId, existing: e),
            ),
          ),
        if (costed.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: l.fromItinerary,
            icon: Icons.view_timeline_outlined,
            child: Column(
              children: [
                for (final a in costed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a.kind.icon, color: a.kind.color),
                    title: Text(a.title),
                    subtitle: Text('${formatDate(context, a.date)} · ${a.bookingStatus.label(l)}'),
                    trailing: Text(a.currency == null ? '${a.cost}' : formatMoney(context, a.cost!, a.currency!)),
                    onTap: () => context.push(Routes.editActivity(tripId, a.id)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------- rates

class _RatesTab extends ConsumerStatefulWidget {
  const _RatesTab({required this.tripId});
  final String tripId;

  @override
  ConsumerState<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends ConsumerState<_RatesTab> {
  bool _fetching = false;

  Future<void> _refresh(Set<String> currencies) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetching = true);
    try {
      final missing = await ref.read(budgetServiceProvider).refreshRates(widget.tripId, currencies);
      messenger.showSnackBar(
        SnackBar(content: Text(missing.isEmpty ? l.ratesUpdated : l.ratesUnsupported(missing.join(', ')))),
      );
    } on RateSourceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.ratesFailed(e.message))));
    } on DomainException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _edit(String base, String? currency, double? current) async {
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (_) => _RateDialog(base: base, currency: currency, current: current),
    );
    if (result != null) await ref.read(budgetServiceProvider).setManualRate(widget.tripId, result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final report = ref.watch(budgetReportProvider(widget.tripId)).value;
    final rates = ref.watch(tripRatesProvider(widget.tripId)).value ?? const <ExchangeRate>[];
    final base = report?.currency;
    if (base == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.warnNoCurrency, textAlign: TextAlign.center),
        ),
      );
    }
    final byCur = {for (final r in rates) r.currency: r};
    final currencies = {...report!.currenciesInUse, ...byCur.keys}..remove(base);
    final sorted = currencies.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      children: [
        Text(l.ratesHelp(base), style: TextStyle(color: c.ink2)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _fetching || sorted.isEmpty ? null : () => _refresh(sorted.toSet()),
                icon: _fetching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(l.refreshRates),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _edit(base, null, null),
              icon: const Icon(Icons.add),
              label: Text(l.addRate),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final cur in sorted)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: c.brandSoft,
                child: Text(cur, style: TextStyle(fontSize: 11, color: c.brandStrong)),
              ),
              title: Text(byCur[cur] == null ? l.rateMissing : '1 $cur = ${_fmtRate(byCur[cur]!.rate)} $base'),
              subtitle: byCur[cur] == null
                  ? null
                  : Text(
                      byCur[cur]!.isManual
                          ? l.rateManual
                          : l.rateFrom(
                              byCur[cur]!.source,
                              DateFormat.yMMMd(context.localeTag).format(byCur[cur]!.updatedAt),
                            ),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (report.unconvertedCurrencies.contains(cur)) Icon(Icons.warning_amber_rounded, color: c.warn),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(base, cur, byCur[cur]?.rate),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _fmtRate(double r) => r >= 100 ? r.toStringAsFixed(2) : r.toStringAsPrecision(5);

// ------------------------------------------------------------- expense editor

Future<void> showExpenseEditor(BuildContext context, {required String tripId, Expense? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ExpenseEditor(tripId: tripId, existing: existing),
    );

class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor({required this.tripId, this.existing});
  final String tripId;
  final Expense? existing;

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _amount = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.amount}');
  late final _currency = TextEditingController(text: widget.existing?.currency);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late ExpenseCategory _category = widget.existing?.category ?? ExpenseCategory.food;
  late ExpenseKind _kind = widget.existing?.kind ?? ExpenseKind.actual;
  late bool _paid = widget.existing?.isPaid ?? true;
  late bool _shared = widget.existing?.isShared ?? true;
  late LocalDate? _date = widget.existing?.date;
  late String? _activityId = widget.existing?.activityId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      final trip = ref.read(tripProvider(widget.tripId)).value?.trip;
      _currency.text = trip?.currency ?? '';
      _date = LocalDate.fromDateTime(DateTime.now());
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _amount, _currency, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (_title.text.trim().isEmpty) return setState(() => _error = l.titleRequired);
    if (amount == null || amount < 0) return setState(() => _error = l.amountInvalid);
    if (!isValidCurrencyCode(_currency.text)) return setState(() => _error = l.currencyInvalid);
    final d = ExpenseDraft(
      title: _title.text,
      category: _category,
      amount: amount,
      currency: _currency.text.trim().toUpperCase(),
      kind: _kind,
      isPaid: _paid,
      date: _date,
      activityId: _activityId,
      isShared: _shared,
      notes: _notes.text,
    );
    final svc = ref.read(budgetServiceProvider);
    try {
      if (widget.existing == null) {
        await svc.addExpense(widget.tripId, d);
      } else {
        await svc.updateExpense(widget.existing!.id, d);
      }
      if (mounted) Navigator.pop(context);
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final acts = ref.watch(tripActivitiesProvider(widget.tripId)).value ?? const <Activity>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? l.addExpense : l.editExpense, style: Theme.of(context).textTheme.titleLarge),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Badge2(label: _error!, tone: Tone.bad, icon: Icons.error_outline),
            ],
            const SizedBox(height: 12),
            SegmentedButton<ExpenseKind>(
              segments: [
                ButtonSegment(
                  value: ExpenseKind.actual,
                  label: Text(l.expenseActual),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
                ButtonSegment(
                  value: ExpenseKind.planned,
                  label: Text(l.expensePlanned),
                  icon: const Icon(Icons.event_note_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _paid = _kind == ExpenseKind.actual;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.expenseTitle),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.fieldAmount),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _currency,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z]'))],
                    decoration: InputDecoration(labelText: l.fieldCurrency, counterText: ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l.fieldCategory),
              items: [
                for (final cat in ExpenseCategory.values)
                  DropdownMenuItem(
                    value: cat,
                    child: Row(children: [Icon(cat.icon, size: 18), const SizedBox(width: 10), Text(cat.label(l))]),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? ExpenseCategory.misc),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.fieldDate),
              subtitle: Text(_date == null ? l.notSet : formatDate(context, _date!)),
              trailing: _date == null
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _date = null)),
              onTap: () async {
                final now = DateTime.now();
                final p = await showDatePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 5),
                  initialDate: (_date ?? LocalDate.fromDateTime(now)).toDateTime(),
                );
                if (p != null) setState(() => _date = LocalDate.fromDateTime(p));
              },
            ),
            if (acts.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: acts.any((a) => a.id == _activityId) ? _activityId : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.linkedActivity),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.noneOption)),
                  for (final a in acts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text('${formatDate(context, a.date)} · ${a.title}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _activityId = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.expensePaid),
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.expenseShared),
              value: _shared,
              onChanged: (v) => setState(() => _shared = v),
            ),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l.fieldNotes),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.actionDelete),
                    onPressed: () async {
                      await ref.read(budgetServiceProvider).deleteExpense(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(l.actionSave)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit one manual exchange rate. Owns its controllers so they are
/// disposed only after the dialog's closing animation.
class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.base, this.currency, this.current});
  final String base;
  final String? currency;
  final double? current;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final _cur = TextEditingController(text: widget.currency ?? '');
  late final _rate = TextEditingController(text: widget.current?.toString() ?? '');

  @override
  void dispose() {
    _cur.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final base = widget.base, currency = widget.currency;
    final code = _cur.text.trim().toUpperCase();
    final rate = double.tryParse(_rate.text.trim().replaceAll(',', ''));
    final valid = isValidCurrencyCode(code) && code != base && rate != null && rate > 0;
    return AlertDialog(
      title: Text(currency == null ? l.addRate : l.rateLabel(currency, base)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currency == null)
            TextField(
              controller: _cur,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z]'))],
              decoration: InputDecoration(labelText: l.fieldCurrency, counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
          TextField(
            controller: _rate,
            autofocus: currency != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.rateLabel(code.isEmpty ? '???' : code, base),
              errorText: _rate.text.isNotEmpty && (rate == null || rate <= 0) ? l.rateInvalid : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(onPressed: valid ? () => Navigator.pop(context, (code, rate)) : null, child: Text(l.actionSave)),
      ],
    );
  }
}
