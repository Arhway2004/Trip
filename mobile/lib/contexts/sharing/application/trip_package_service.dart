import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/gallery/application/gallery_service.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/sharing/domain/trip_package.dart';
import 'package:wanderplan/contexts/sharing/infrastructure/zip_trip_package_codec.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

export 'package:wanderplan/contexts/sharing/domain/trip_package.dart';

/// Exports a trip to a package and imports packages as new, independent
/// trips. Importing never overwrites existing data: every record gets a new
/// ID, so a friend's copy and the original evolve separately.
class TripPackageService {
  TripPackageService({
    required TripRepository trips,
    required GalleryService gallery,
    required ChecklistService checklist,
    required ItineraryService itinerary,
    required BudgetService budget,
    required SavedPlaceService places,
    required MediaStore media,
    required UnitOfWork uow,
    required IdGenerator ids,
    required Clock clock,
    required this.tempDir,
    ZipTripPackageCodec codec = const ZipTripPackageCodec(),
  }) : _trips = trips,
       _gallery = gallery,
       _checklist = checklist,
       _itinerary = itinerary,
       _budget = budget,
       _places = places,
       _media = media,
       _uow = uow,
       _ids = ids,
       _clock = clock,
       _codec = codec;

  final TripRepository _trips;
  final GalleryService _gallery;
  final ChecklistService _checklist;
  final ItineraryService _itinerary;
  final BudgetService _budget;
  final SavedPlaceService _places;
  final MediaStore _media;
  final UnitOfWork _uow;
  final IdGenerator _ids;
  final Clock _clock;
  final ZipTripPackageCodec _codec;
  final Future<Directory> Function() tempDir;

  // --- Export -------------------------------------------------------------

  /// [includePrivate] adds booking references; they are left out by default.
  Future<File> exportTrip(String tripId, {bool includePhotos = true, bool includePrivate = false}) async {
    final trip = await _trips.findById(tripId) ?? (throw EntityNotFoundException('Trip', tripId));
    final photos = includePhotos ? (await _gallery.photosOf(tripId)).reversed.toList() : const [];
    final todos = await _checklist.itemsOf(tripId);
    final activities = await _itinerary.activitiesOf(tripId);
    final expenses = await _budget.expensesOf(tripId);
    final rates = await _budget.ratesOf(tripId);
    final places = await _places.placesOf(tripId);
    final refOf = {for (var i = 0; i < activities.length; i++) activities[i].id: 'a$i'};

    final media = <String, List<int>>{};
    final entryFor = <String, String>{}; // relPath -> entry
    String? addMedia(String? relPath) {
      if (relPath == null) return null;
      if (entryFor[relPath] case final e?) return e;
      final file = _media.resolve(relPath);
      if (!file.existsSync()) return null; // Missing files are skipped, not fatal.
      final entry = 'media/${media.length}${p.extension(relPath)}';
      media[entry] = file.readAsBytesSync();
      return entryFor[relPath] = entry;
    }

    final b = trip.banner;
    final json = <String, dynamic>{
      'format': tripPackageFormat,
      'schemaVersion': tripPackageSchemaVersion,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'trip': {
        'title': trip.title,
        'description': trip.description,
        'startDate': trip.startDate?.toIso(),
        'endDate': trip.endDate?.toIso(),
        'departureTime': trip.departureTime,
        'datesConfirmed': trip.datesConfirmed,
        'timeZone': trip.timeZone,
        'travelerCount': trip.travelerCount,
        'currency': trip.currency,
        'totalBudget': trip.totalBudget,
        'travelStyle': trip.travelStyle?.name,
        'stage': trip.stage.name,
      },
      'destinations': [
        for (final d in trip.destinations) {'country': d.country, 'city': d.city},
      ],
      'banner': {
        'kind': b.kind.name,
        'image': addMedia(b.imagePath),
        'scale': b.scale,
        'alignX': b.alignX,
        'alignY': b.alignY,
        'colorA': b.colorA,
        'colorB': b.colorB,
        'showTitle': b.showTitle,
        'titlePlacement': b.titlePlacement.name,
        'textColor': b.textColor,
        'style': b.style.name,
      },
      'photos': [
        for (final ph in photos)
          if (addMedia(ph.relPath) case final file?)
            {
              'file': file,
              'caption': ph.caption,
              'isFavorite': ph.isFavorite,
              'createdAt': ph.createdAt.toUtc().toIso8601String(),
            },
      ],
      'todos': [
        for (final t in todos)
          {
            'title': t.title,
            'notes': t.notes,
            'category': t.category.name,
            'dueDate': t.dueDate?.toIso(),
            'isDone': t.isDone,
          },
      ],
      'activities': [
        for (final a in activities)
          {
            'ref': refOf[a.id],
            'title': a.title,
            'kind': a.kind.name,
            'date': a.date.toIso(),
            if (a.hasTime) 'start': formatMinutes(a.startMinute!),
            if (a.endDate != null) 'endDate': a.endDate!.toIso(),
            if (a.hasTime) 'end': a.endMinute == 24 * 60 ? '24:00' : formatMinutes(a.endMinute!),
            'location': _placeJson(a.location),
            if (a.kind.isTransport) 'destination': _placeJson(a.destination),
            'cost': a.cost,
            'currency': a.currency,
            'bookingStatus': a.bookingStatus.name,
            'provider': a.provider,
            'serviceNumber': a.serviceNumber,
            'bookingUrl': a.bookingUrl,
            if (includePrivate) 'bookingReference': a.bookingReference,
            'isLocked': a.isLocked,
            'isOptional': a.isOptional,
            'notes': a.notes,
          },
      ],
      'expenses': [
        for (final e in expenses)
          {
            'title': e.title,
            'category': e.category.name,
            'amount': e.amount,
            'currency': e.currency,
            'kind': e.kind.name,
            'isPaid': e.isPaid,
            'date': e.date?.toIso(),
            'activityRef': refOf[e.activityId],
            'isShared': e.isShared,
            'notes': e.notes,
          },
      ],
      'exchangeRates': [
        for (final r in rates) {'currency': r.currency, 'rate': r.rate, 'source': r.source},
      ],
      'places': [
        for (final pl in places)
          {
            'name': pl.name,
            'category': pl.category.name,
            'lat': pl.point.latitude,
            'lng': pl.point.longitude,
            'address': pl.address,
            'notes': pl.notes,
          },
      ],
    };

    final dir = await tempDir();
    final out = File(p.join(dir.path, '${_safeFileName(trip.title)}.$tripPackageExtension'));
    await out.writeAsBytes(_codec.encode(TripPackageContents(json, media)));
    return out;
  }

  // --- Import -------------------------------------------------------------

  /// Imports a package (or a bare `trip.json`) and returns the new trip ID.
  Future<String> importFile(File file) async => importContents(_codec.decode(await file.readAsBytes()));

  /// Imports trip JSON pasted as text (e.g. copied from ChatGPT or Notes).
  /// Markdown code fences around the JSON are ignored.
  Future<String> importText(String text) async {
    var t = text.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n?```$').firstMatch(t);
    if (fence != null) t = fence.group(1)!.trim();
    if (t.isEmpty) throw const TripPackageException(TripPackageError.invalid, 'nothing to import');
    return importContents(_codec.decode(utf8.encode(t)));
  }

  Future<String> importContents(TripPackageContents contents) async {
    final json = contents.json;
    if (json['format'] != tripPackageFormat || json['trip'] is! Map) {
      throw const TripPackageException(TripPackageError.invalid, 'not a WanderPlan trip');
    }
    final version = json['schemaVersion'];
    if (version is! int) throw const TripPackageException(TripPackageError.invalid, 'schemaVersion');
    if (version > tripPackageSchemaVersion) throw const TripPackageException(TripPackageError.tooNew);

    final id = _ids.newId();
    final now = _clock();
    final stored = <String, String>{}; // entry -> relPath
    Future<String?> media(Object? entry) async {
      if (entry is! String) return null;
      if (stored[entry] case final rel?) return rel;
      final bytes = contents.media[entry];
      if (bytes == null) return null;
      return stored[entry] = await _media.writeBytes(id, bytes, extension: p.extension(entry));
    }

    try {
      final t = (json['trip'] as Map).cast<String, dynamic>();
      final bj = (json['banner'] as Map?)?.cast<String, dynamic>();
      final bannerImage = await media(bj?['image']);
      final photos = <(String, Map<String, dynamic>)>[];
      for (final ph in _list(json['photos'])) {
        if (await media(ph['file']) case final rel?) photos.add((rel, ph));
      }

      final defaults = BannerConfig.defaultFor(id);
      final kind = enumByName(BannerKind.values, bj?['kind'] as String?) ?? defaults.kind;
      final banner = BannerConfig(
        // A photo banner whose image did not arrive falls back to colors.
        kind: kind == BannerKind.photo && bannerImage == null ? BannerKind.gradient : kind,
        imagePath: bannerImage,
        scale: (bj?['scale'] as num?)?.toDouble() ?? 1,
        alignX: (bj?['alignX'] as num?)?.toDouble() ?? 0,
        alignY: (bj?['alignY'] as num?)?.toDouble() ?? 0,
        colorA: parsePackageColor(bj?['colorA']) ?? defaults.colorA,
        colorB: bj == null ? defaults.colorB : parsePackageColor(bj['colorB']),
        showTitle: bj?['showTitle'] as bool? ?? true,
        titlePlacement:
            enumByName(TitlePlacement.values, bj?['titlePlacement'] as String?) ?? TitlePlacement.bottomLeft,
        textColor: parsePackageColor(bj?['textColor']) ?? 0xFFFFFFFF,
        style: enumByName(BannerStyle.values, bj?['style'] as String?) ?? BannerStyle.classic,
      );

      final trip = Trip(
        id: id,
        title: t['title'] as String? ?? '',
        description: t['description'] as String?,
        startDate: _date(t['startDate']),
        endDate: _date(t['endDate']),
        departureTime: t['departureTime'] as String?,
        datesConfirmed: t['datesConfirmed'] as bool? ?? false,
        timeZone: t['timeZone'] as String? ?? 'UTC',
        travelerCount: (t['travelerCount'] as num?)?.toInt() ?? 1,
        currency: (t['currency'] as String?)?.toUpperCase(),
        totalBudget: (t['totalBudget'] as num?)?.toDouble(),
        travelStyle: enumByName(TravelStyle.values, t['travelStyle'] as String?),
        stage: enumByName(TripStage.values, t['stage'] as String?) ?? TripStage.planning,
        createdAt: now,
        updatedAt: now,
        destinations: [
          for (final d in _list(json['destinations']))
            Destination(country: d['country'] as String?, city: d['city'] as String?),
        ],
        banner: banner,
      );

      await _uow.run(() async {
        await _trips.insertFirst(trip);
        // The banner image is also a gallery photo locally.
        if (bannerImage != null && !photos.any((x) => x.$1 == bannerImage)) {
          await _gallery.addStoredPhoto(id, bannerImage);
        }
        for (final (rel, ph) in photos) {
          await _gallery.addStoredPhoto(
            id,
            rel,
            caption: ph['caption'] as String?,
            isFavorite: ph['isFavorite'] as bool? ?? false,
            createdAt: DateTime.tryParse(ph['createdAt'] as String? ?? ''),
          );
        }
        await _checklist.addItems(id, [
          for (final td in _list(json['todos']))
            TodoDraft(
              title: td['title'] as String? ?? '',
              notes: td['notes'] as String?,
              category: packageTodoCategory(td['category']),
              dueDate: _date(td['dueDate']),
              isDone: td['isDone'] as bool? ?? false,
            ),
        ]);
        final activityIds = <String, String>{};
        final list = _list(json['activities']);
        for (var i = 0; i < list.length; i++) {
          final aj = list[i];
          final label = (aj['title'] as String?) ?? '#${i + 1}';
          final date = _date(aj['date']);
          final rawStart = aj['start'], rawEnd = aj['end'];
          final start = parsePackageTime(rawStart);
          final end = parsePackageTime(rawEnd);
          if (date == null) {
            throw TripPackageException(TripPackageError.invalid, 'activity "$label": "date" (YYYY-MM-DD) is required');
          }
          // No times at all = time not decided yet (allowed; never guessed).
          final untimed = rawStart == null && rawEnd == null;
          if (!untimed && (start == null || end == null)) {
            throw TripPackageException(
              TripPackageError.invalid,
              'activity "$label": give both "start" and "end" as HH:mm, or leave both out if the time is not decided',
            );
          }
          try {
            final activityId = await _itinerary.addActivity(
              id,
              ActivityDraft(
                title: aj['title'] as String? ?? '',
                kind: packageActivityKind(aj['kind']),
                date: date,
                startMinute: untimed ? null : start,
                endDate: _date(aj['endDate']),
                endMinute: untimed ? null : end,
                location: _place(aj['location']),
                destination: _place(aj['destination']),
                cost: (aj['cost'] as num?)?.toDouble(),
                currency: aj['currency'] as String?,
                bookingStatus:
                    enumByName(BookingStatus.values, aj['bookingStatus'] as String?) ?? BookingStatus.notBooked,
                provider: aj['provider'] as String?,
                serviceNumber: aj['serviceNumber'] as String?,
                bookingUrl: aj['bookingUrl'] as String?,
                bookingReference: aj['bookingReference'] as String?,
                isLocked: aj['isLocked'] as bool? ?? false,
                isOptional: aj['isOptional'] as bool? ?? false,
                notes: aj['notes'] as String?,
              ),
            );
            if (aj['ref'] case final String ref) activityIds[ref] = activityId;
          } on DomainException catch (e) {
            throw TripPackageException(TripPackageError.invalid, 'activity "$label": ${e.message}');
          }
        }
        for (final ej in _list(json['expenses'])) {
          final label = (ej['title'] as String?) ?? '?';
          try {
            await _budget.addExpense(
              id,
              ExpenseDraft(
                title: ej['title'] as String? ?? '',
                category: packageExpenseCategory(ej['category']),
                amount: (ej['amount'] as num?)?.toDouble() ?? -1,
                currency: (ej['currency'] as String?) ?? trip.currency ?? '',
                kind: enumByName(ExpenseKind.values, ej['kind'] as String?) ?? ExpenseKind.actual,
                isPaid: ej['isPaid'] as bool? ?? true,
                date: _date(ej['date']),
                activityId: activityIds[ej['activityRef']],
                isShared: ej['isShared'] as bool? ?? true,
                notes: ej['notes'] as String?,
              ),
            );
          } on DomainException catch (e) {
            throw TripPackageException(TripPackageError.invalid, 'expense "$label": ${e.message}');
          }
        }
        for (final rj in _list(json['exchangeRates'])) {
          final cur = (rj['currency'] as String?)?.toUpperCase();
          final rate = (rj['rate'] as num?)?.toDouble();
          if (cur == null || rate == null || rate <= 0 || !RegExp(r'^[A-Z]{3}$').hasMatch(cur)) continue;
          await _budget.setManualRate(id, cur, rate);
        }
        final placeDrafts = <SavedPlaceDraft>[];
        for (final pj in _list(json['places'])) {
          final label = (pj['name'] as String?) ?? '?';
          final point = GeoPoint.tryCreate((pj['lat'] as num?)?.toDouble(), (pj['lng'] as num?)?.toDouble());
          // Coordinates are never guessed: a saved place needs real ones.
          if (point == null) {
            throw TripPackageException(
              TripPackageError.invalid,
              'place "$label": "lat" and "lng" are required (decimal degrees, WGS84)',
            );
          }
          if ((pj['name'] as String? ?? '').trim().isEmpty) {
            throw const TripPackageException(TripPackageError.invalid, 'place: "name" is required');
          }
          placeDrafts.add(
            SavedPlaceDraft(
              name: pj['name'] as String,
              point: point,
              category: packagePlaceCategory(pj['category']),
              address: pj['address'] as String?,
              source: 'import',
            )..notes = pj['notes'] as String?,
          );
        }
        await _places.savePlaces(id, placeDrafts);
      });
      return id;
    } on TripPackageException {
      await _media.deleteTripMedia(id);
      rethrow;
    } catch (e) {
      await _media.deleteTripMedia(id);
      throw TripPackageException(TripPackageError.invalid, e is DomainException ? e.message : '$e');
    }
  }
}

Map<String, dynamic>? _placeJson(PlaceRef p) => p.isEmpty
    ? null
    : {'name': p.name, if (p.point != null) 'lat': p.point!.latitude, if (p.point != null) 'lng': p.point!.longitude};

PlaceRef _place(Object? v) {
  if (v is String) return PlaceRef(name: v);
  if (v is! Map) return const PlaceRef();
  final point = GeoPoint.tryCreate((v['lat'] as num?)?.toDouble(), (v['lng'] as num?)?.toDouble());
  return PlaceRef(name: v['name'] as String?, point: point, source: point == null ? null : 'import');
}

/// Place categories, with common synonyms.
PlaceCategory packagePlaceCategory(Object? v) {
  final k = (v is String ? v : '').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  return enumByName(PlaceCategory.values, v is String ? v.trim() : null) ??
      switch (k) {
        'sight' || 'sightseeing' || 'museum' || 'landmark' || 'poi' => PlaceCategory.attraction,
        'food' || 'cafe' || 'meal' || 'dining' => PlaceCategory.restaurant,
        'accommodation' || 'lodging' || 'hostel' || 'stay' => PlaceCategory.hotel,
        'railwaystation' || 'trainstation' || 'station' || 'railway' => PlaceCategory.railwayStation,
        'busstation' || 'busterminal' || 'bus' => PlaceCategory.busStation,
        _ => PlaceCategory.other,
      };
}

/// Accepts the documented names plus common synonyms people write by hand.
ActivityKind packageActivityKind(Object? v) {
  final k = (v is String ? v : '').trim().toLowerCase();
  return enumByName(ActivityKind.values, k) ??
      switch (k) {
        'taxi' || 'metro' || 'subway' || 'car' || 'drive' || 'walk' => ActivityKind.transfer,
        'boat' || 'ship' => ActivityKind.ferry,
        'coach' => ActivityKind.bus,
        'plane' => ActivityKind.flight,
        'rail' || 'highspeedrail' || 'hsr' => ActivityKind.train,
        'accommodation' || 'lodging' || 'stay' || 'hostel' => ActivityKind.hotel,
        'meal' || 'restaurant' || 'dining' => ActivityKind.food,
        'attraction' || 'sight' || 'visit' => ActivityKind.sightseeing,
        _ => ActivityKind.other,
      };
}

ExpenseCategory packageExpenseCategory(Object? v) {
  final k = (v is String ? v : '').trim().toLowerCase();
  return enumByName(ExpenseCategory.values, k) ??
      switch (k) {
        'flight' || 'airfare' => ExpenseCategory.flights,
        'train' || 'rail' => ExpenseCategory.trains,
        'bus' || 'ferry' => ExpenseCategory.buses,
        'taxi' || 'local transport' => ExpenseCategory.taxis,
        'hotel' || 'accommodation' || 'lodging' => ExpenseCategory.hotels,
        'meals' || 'restaurant' => ExpenseCategory.food,
        'tickets' || 'ticket' || 'admission' || 'attraction' => ExpenseCategory.attractions,
        'activity' || 'tours' || 'tour' => ExpenseCategory.activities,
        'sim' || 'esim' || 'roaming' => ExpenseCategory.internet,
        _ => ExpenseCategory.misc,
      };
}

TodoCategory packageTodoCategory(Object? v) {
  final k = (v is String ? v : '').trim().toLowerCase();
  return enumByName(TodoCategory.values, k) ??
      switch (k) {
        'transport' || 'accommodation' || 'tickets' || 'flights' || 'hotels' || 'booking' => TodoCategory.bookings,
        'visa' || 'passport' || 'document' => TodoCategory.documents,
        'insurance' || 'medical' => TodoCategory.health,
        'sim' || 'internet' || 'esim' || 'phone' => TodoCategory.connectivity,
        'clothing' || 'luggage' => TodoCategory.packing,
        'payment' || 'cash' => TodoCategory.money,
        _ => TodoCategory.other,
      };
}

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ]
    : const [];

LocalDate? _date(Object? v) => v is String ? LocalDate.tryParse(v) : null;

String _safeFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return 'trip';
  return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
}
