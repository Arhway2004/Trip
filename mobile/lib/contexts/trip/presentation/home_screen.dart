import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/sharing/presentation/share_trip_sheet.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_actions.dart';
import 'package:wanderplan/contexts/trip/presentation/widgets/trip_card.dart';

import 'package:wanderplan/shared/presentation/atlas.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _reordering = false;
  final _search = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _searchText = '');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = context.colors;
    final tripsAsync = ref.watch(tripsProvider),
        filter = ref.watch(tripFilterProvider),
        now = ref.watch(currentTimeProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: const AtlasBrand(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.line),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.language,
            icon: const Icon(Icons.translate_outlined, size: 20),
            onSelected: (code) =>
                ref.read(localeProvider.notifier).set(Locale(code)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'en', child: Text('English')),
              const PopupMenuItem(value: 'zh', child: Text('简体中文')),
              const PopupMenuItem(value: 'th', child: Text('ไทย')),
            ],
          ),
          PopupMenuButton<int>(
            tooltip: l.moreSettings,
            icon: const Icon(Icons.tune_outlined, size: 20),
            onSelected: (value) {
              if (value == 0) {
                context.push(Routes.settings);
              } else {
                setState(() => _reordering = !_reordering);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: Text(l.moreSettings)),
              if (filter == TripFilter.all &&
                  _searchText.trim().isEmpty &&
                  (tripsAsync.value?.length ?? 0) > 1)
                PopupMenuItem(
                  value: 1,
                  child: Text(_reordering ? l.actionDone : l.actionReorder),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final visible = all
              .where(
                (t) =>
                    matchesFilter(t.status(now), filter) &&
                    t.trip.title.toLowerCase().contains(
                      _searchText.trim().toLowerCase(),
                    ),
              )
              .toList();
          final count = all.where((t) => !t.trip.archived).length;
          return LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 700;
              final inset = wide ? 40.0 : 20.0;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(inset, 28, inset, 22),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.atlasEyebrow.toUpperCase(),
                                style: atlasEyebrow(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l.myTrips,
                                style: atlasEditorial(
                                  context,
                                  size: wide ? 68 : 48,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l.atlasSubtitle,
                                style: TextStyle(color: c.ink2, fontSize: 14),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: c.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l.atlasCollection(count),
                                      style: TextStyle(
                                        color: c.ink2,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            importTripFromFile(context, ref),
                                        icon: const Icon(
                                          Icons.file_upload_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          l.importTrip,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            context.push(Routes.newTrip),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          l.createTrip,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!_reordering && all.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(inset, 0, inset, 16),
                          sliver: SliverToBoxAdapter(
                            child: TextField(
                              controller: _search,
                              onChanged: (value) =>
                                  setState(() => _searchText = value),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: l.searchTrips,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchText.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: l.clearSearch,
                                        onPressed: _clearSearch,
                                        icon: const Icon(Icons.close, size: 20),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      if (!_reordering)
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: inset),
                          sliver: SliverToBoxAdapter(
                            child: _FilterBar(filter: filter),
                          ),
                        ),
                      if (_reordering)
                        SliverFillRemaining(child: _ReorderList(trips: visible))
                      else if (all.isEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(inset, 0, inset, 30),
                          sliver: const SliverToBoxAdapter(
                            child: _EmptyState(),
                          ),
                        )
                      else if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _searchText.trim().isEmpty
                                      ? l.emptyFilterBody
                                      : l.searchTripsEmpty,
                                  style: TextStyle(color: c.ink2),
                                  textAlign: TextAlign.center,
                                ),
                                if (_searchText.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: _clearSearch,
                                    child: Text(l.clearSearch),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(inset, 0, inset, 40),
                          sliver: SliverList.builder(
                            itemCount: wide
                                ? (visible.length / 2).ceil()
                                : visible.length,
                            itemBuilder: (context, row) {
                              Widget card(int i) => TripCard(
                                key: ValueKey(visible[i].id),
                                trip: visible[i],
                                index: i + 1,
                                onTap: () =>
                                    context.push(Routes.trip(visible[i].id)),
                                onAction: (a) =>
                                    runTripAction(context, ref, visible[i], a),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 22),
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: card(row * 2)),
                                          const SizedBox(width: 28),
                                          Expanded(
                                            child: row * 2 + 1 < visible.length
                                                ? card(row * 2 + 1)
                                                : const SizedBox(),
                                          ),
                                        ],
                                      )
                                    : card(row),
                              );
                            },
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(inset, 0, inset, 30),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(color: c.line),
                              const SizedBox(height: 14),
                              Text(
                                l.atlasFooter,
                                style: TextStyle(fontSize: 11, color: c.ink3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});
  final TripFilter filter;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final trips = ref.watch(tripsProvider).value ?? const <TripSummary>[];
    final now = ref.watch(currentTimeProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in TripFilter.values)
              Container(
                margin: const EdgeInsets.only(right: 23),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: f == filter ? c.brand : Colors.transparent,
                    ),
                  ),
                ),
                child: Semantics(
                  selected: f == filter,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: EdgeInsets.zero,
                      foregroundColor: f == filter ? c.ink : c.ink2,
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () =>
                        ref.read(tripFilterProvider.notifier).set(f),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f.label(context.l10n),
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontFamilyFallback: atlasBodyFallback,
                            fontSize: 13,
                            fontWeight: f == filter
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${trips.where((t) => matchesFilter(t.status(now), f)).length}',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontFamilyFallback: atlasBodyFallback,
                            fontSize: 11,
                            color: c.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReorderList extends ConsumerStatefulWidget {
  const _ReorderList({required this.trips});
  final List<TripSummary> trips;

  @override
  ConsumerState<_ReorderList> createState() => _ReorderListState();
}

class _ReorderListState extends ConsumerState<_ReorderList> {
  late List<TripSummary> _items = widget.trips;

  @override
  void didUpdateWidget(covariant _ReorderList old) {
    super.didUpdateWidget(old);
    _items = widget.trips;
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _items.length,
      onReorder: (from, to) {
        if (to > from) to -= 1;
        setState(() {
          _items = [..._items];
          _items.insert(to, _items.removeAt(from));
        });
        ref.read(tripServiceProvider).reorder(_items.map((t) => t.id).toList());
      },
      itemBuilder: (context, i) {
        final t = _items[i];
        return ListTile(
          key: ValueKey(t.id),
          leading: const Icon(Icons.drag_handle),
          title: Text(t.trip.title),
          subtitle: Text(
            t.primaryDestination ?? formatDateRange(context, t.start, t.end),
          ),
        );
      },
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n, c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 190,
            color: const Color(0xFF254F3E),
            child: const Stack(
              fit: StackFit.expand,
              children: [
                AtlasRouteArt(),
                Positioned(
                  left: 24,
                  top: 24,
                  child: Text(
                    'WANDERPLAN / 01',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.atlasBegin.toUpperCase(), style: atlasEyebrow(context)),
                const SizedBox(height: 12),
                Text(
                  l.emptyTripsTitle,
                  style: atlasEditorial(context, size: 38),
                ),
                const SizedBox(height: 14),
                Text(
                  l.emptyTripsBody,
                  style: TextStyle(color: c.ink2, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
