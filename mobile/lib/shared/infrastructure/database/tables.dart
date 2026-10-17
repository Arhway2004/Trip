import 'package:drift/drift.dart';

/// All IDs are client-generated UUIDv4 strings so records stay stable across
/// export/import and device restores.

@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// Local calendar dates in the trip's time zone, stored as `yyyy-MM-dd`.
  /// Null while dates are undecided.
  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();

  /// Optional local departure time `HH:mm` on [startDate].
  TextColumn get departureTime => text().nullable()();

  /// False while dates are only tentative ("flexible").
  BoolColumn get datesConfirmed => boolean().withDefault(const Constant(false))();

  /// IANA time-zone identifier, e.g. `Asia/Shanghai`.
  TextColumn get timeZone => text()();
  IntColumn get travelerCount => integer().withDefault(const Constant(1))();

  /// ISO 4217 code; null until the user picks one.
  TextColumn get currency => text().nullable()();
  RealColumn get totalBudget => real().nullable()();
  TextColumn get travelStyle => text().nullable()();

  /// Manual planning stage (`dreaming` | `planning`). Upcoming / traveling /
  /// completed are derived from dates; archived from [archived].
  TextColumn get stage => text().withDefault(const Constant('planning'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TripDestinationRow')
class TripDestinations extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get country => text().nullable()();
  TextColumn get city => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Non-destructive banner configuration. The original image is kept and the
/// crop is described by [scale] + [alignX]/[alignY] so it can be re-edited.
@DataClassName('TripBannerRow')
class TripBanners extends Table {
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// `photo` | `gradient` | `solid`
  TextColumn get kind => text().withDefault(const Constant('gradient'))();

  /// Path relative to the app media root.
  TextColumn get imagePath => text().nullable()();
  RealColumn get scale => real().withDefault(const Constant(1.0))();
  RealColumn get alignX => real().withDefault(const Constant(0.0))();
  RealColumn get alignY => real().withDefault(const Constant(0.0))();
  IntColumn get colorA => integer()();
  IntColumn get colorB => integer().nullable()();
  BoolColumn get showTitle => boolean().withDefault(const Constant(true))();

  /// `topLeft` | `center` | `bottomLeft` | `bottomCenter`
  TextColumn get titlePlacement => text().withDefault(const Constant('bottomLeft'))();
  IntColumn get textColor => integer().withDefault(const Constant(0xFFFFFFFF))();

  /// `classic` | `minimal` | `bold` | `framed`
  TextColumn get style => text().withDefault(const Constant('classic'))();

  @override
  Set<Column> get primaryKey => {tripId};
}

@DataClassName('TripPhotoRow')
class TripPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get relPath => text()();
  TextColumn get caption => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Pre-departure checklist items ("Before you go"). Added in schema v2.
@DataClassName('TripTodoRow')
class TripTodos extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();

  /// See `TodoCategory` in the trips domain.
  TextColumn get category => text().withDefault(const Constant('other'))();

  /// Optional local due date `yyyy-MM-dd` in the trip's time zone.
  TextColumn get dueDate => text().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Itinerary activities, including transport segments and hotel stays. Added in schema v3.
@DataClassName('ActivityRow')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// See `ActivityKind` in the itinerary domain.
  TextColumn get kind => text().withDefault(const Constant('sightseeing'))();

  /// Local date/time in the trip time zone. Minutes after midnight.
  TextColumn get date => text()();
  IntColumn get startMinute => integer()();
  TextColumn get endDate => text().nullable()();
  IntColumn get endMinute => integer()();

  /// False while the time is not decided (start/end are then stored as 0). Added in v4.
  BoolColumn get hasTime => boolean().withDefault(const Constant(true))();

  TextColumn get locationName => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get endLocationName => text().nullable()();
  RealColumn get endLatitude => real().nullable()();
  RealColumn get endLongitude => real().nullable()();

  /// Where coordinates came from: `map` (user tapped), `search:<provider>`, `import`.
  TextColumn get coordinateSource => text().nullable()();

  RealColumn get cost => real().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get bookingStatus => text().withDefault(const Constant('notBooked'))();
  TextColumn get provider => text().nullable()();
  TextColumn get serviceNumber => text().nullable()();

  /// Private booking reference; excluded from exports by default.
  TextColumn get bookingReference => text().nullable()();
  TextColumn get bookingUrl => text().nullable()();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Planned and actual expenses. Added in schema v3.
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant('misc'))();
  RealColumn get amount => real()();
  TextColumn get currency => text()();

  /// `planned` | `actual`
  TextColumn get kind => text().withDefault(const Constant('actual'))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(true))();
  TextColumn get date => text().nullable()();

  /// Optional link to the itinerary activity this expense paid for.
  TextColumn get activityId => text().nullable().references(Activities, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isShared => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-trip conversion rates into the trip's primary currency. Added in schema v3.
@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get currency => text()();

  /// 1 unit of [currency] = [rate] units of the trip currency.
  RealColumn get rate => real()();

  /// `manual` or the provider name.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tripId, currency};
}

/// Places saved to a trip from search, "explore nearby" or a map tap. Added in schema v5.
/// Coordinates are WGS84 and always real (never invented), so they are required.
@DataClassName('SavedPlaceRow')
class SavedPlaces extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// See `PlaceCategory` in the places domain.
  TextColumn get category => text().withDefault(const Constant('attraction'))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();

  /// `map`, `search:<provider>` or `import`.
  TextColumn get coordinateSource => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
