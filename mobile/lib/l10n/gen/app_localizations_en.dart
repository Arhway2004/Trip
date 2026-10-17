// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WanderPlan';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMap => 'Map';

  @override
  String get tabTimeline => 'Timeline';

  @override
  String get tabBudget => 'Budget';

  @override
  String get tabMore => 'More';

  @override
  String get searchTrips => 'Search trips';

  @override
  String get searchTripsEmpty => 'No trips match your search.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get myTrips => 'My trips';

  @override
  String get createTrip => 'Create new trip';

  @override
  String get newTrip => 'New Trip';

  @override
  String get editTrip => 'Edit Trip';

  @override
  String get emptyTripsTitle => 'No trips yet';

  @override
  String get emptyTripsBody =>
      'Plan your next adventure. A trip only needs a title — you can add everything else later.';

  @override
  String get emptyFilterBody => 'No trips match this filter.';

  @override
  String get filterAll => 'All';

  @override
  String get filterUpcoming => 'Upcoming';

  @override
  String get filterTraveling => 'Traveling';

  @override
  String get filterCompleted => 'Completed';

  @override
  String get filterArchived => 'Archived';

  @override
  String get statusDreaming => 'Dreaming';

  @override
  String get statusPlanning => 'Planning';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusTraveling => 'Traveling';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusArchived => 'Archived';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionUnarchive => 'Unarchive';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEditBanner => 'Edit banner';

  @override
  String get actionReorder => 'Reorder trips';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get duplicateSuffix => ' (copy)';

  @override
  String get deleteTripTitle => 'Delete trip?';

  @override
  String deleteTripBody(String title) {
    return '“$title” and all of its photos will be permanently deleted. This cannot be undone.';
  }

  @override
  String get tripDuplicated => 'Trip duplicated';

  @override
  String get tripArchived => 'Trip archived';

  @override
  String get tripUnarchived => 'Trip restored from archive';

  @override
  String get tripDeleted => 'Trip deleted';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get restoreNotYet =>
      'Backup and restore are not implemented yet (planned for the Import / Export phase).';

  @override
  String get datesUndecided => 'Dates not decided';

  @override
  String get datesFlexible => 'Flexible dates';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String travelersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers',
      one: '1 traveler',
    );
    return '$_temp0';
  }

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String unitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String unitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to go',
      one: '1 day to go',
      zero: 'Departing today',
    );
    return '$_temp0';
  }

  @override
  String countdownRemaining(String value) {
    return '$value remaining';
  }

  @override
  String countdownDayOf(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String get countdownCompleted => 'Trip Completed';

  @override
  String get countdownNoDate => 'Set dates to start the countdown';

  @override
  String departsOn(String date) {
    return 'Departs $date';
  }

  @override
  String departsOnAt(String date, String time) {
    return 'Departs $date at $time';
  }

  @override
  String get fieldTitle => 'Trip title';

  @override
  String get fieldTitleHint => 'e.g. Autumn in Kyoto';

  @override
  String get titleRequired => 'Please enter a title';

  @override
  String get fieldDescription => 'Description';

  @override
  String get optional => 'Optional';

  @override
  String get sectionCover => 'Cover image';

  @override
  String get coverPick => 'Choose photo';

  @override
  String get coverCamera => 'Take photo';

  @override
  String get coverRemove => 'Remove';

  @override
  String get coverHint => 'You can crop and style the banner after saving.';

  @override
  String get sectionDestinations => 'Destinations';

  @override
  String get fieldCountry => 'Country';

  @override
  String get fieldCity => 'City';

  @override
  String get addDestination => 'Add destination';

  @override
  String get removeDestination => 'Remove destination';

  @override
  String get mainDestination => 'Main destination';

  @override
  String get sectionDates => 'Dates';

  @override
  String get pickDates => 'Choose dates';

  @override
  String get clearDates => 'Clear dates';

  @override
  String get datesConfirmed => 'Dates confirmed';

  @override
  String get datesConfirmedHelp =>
      'Turn off while your dates are still flexible.';

  @override
  String get departureTime => 'Departure time';

  @override
  String get notSet => 'Not set';

  @override
  String get fieldTimeZone => 'Time zone';

  @override
  String get timeZoneHelp => 'Countdown and dates use this time zone.';

  @override
  String get searchTimeZone => 'Search time zones';

  @override
  String get sectionDetails => 'Details';

  @override
  String get fieldTravelers => 'Travelers';

  @override
  String get fieldCurrency => 'Primary currency';

  @override
  String get currencyInvalid => 'Use a 3-letter ISO currency code, e.g. USD';

  @override
  String get fieldBudget => 'Total budget';

  @override
  String get budgetInvalid => 'Enter a positive number';

  @override
  String get budgetNeedsCurrency => 'Choose a currency for the budget';

  @override
  String get fieldTravelStyle => 'Travel style';

  @override
  String get fieldStage => 'Planning stage';

  @override
  String get stageHelp =>
      'Upcoming, traveling and completed are set automatically from your dates.';

  @override
  String get styleRelaxed => 'Relaxed';

  @override
  String get styleBalanced => 'Balanced';

  @override
  String get stylePacked => 'Packed';

  @override
  String get styleBudget => 'Budget';

  @override
  String get styleComfort => 'Comfort';

  @override
  String get styleLuxury => 'Luxury';

  @override
  String get styleAdventure => 'Adventure';

  @override
  String get styleFamily => 'Family';

  @override
  String get saveTripCreate => 'Create trip';

  @override
  String get saveTripChanges => 'Save changes';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String saveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get overview => 'Overview';

  @override
  String get budgetTitle => 'Budget';

  @override
  String get budgetNotSet => 'No budget set';

  @override
  String budgetPerPerson(String amount) {
    return '$amount per person';
  }

  @override
  String get photosTitle => 'Photos';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'No photos',
    );
    return '$_temp0';
  }

  @override
  String get openGallery => 'Open gallery';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get planningModules => 'Planning tools';

  @override
  String get notImplementedYet => 'Not implemented yet';

  @override
  String get moduleMap => 'Open Map';

  @override
  String get moduleAttraction => 'Add Attraction';

  @override
  String get moduleItinerary => 'Edit Itinerary';

  @override
  String get moduleFlight => 'Add Flight';

  @override
  String get moduleTrain => 'Add Train';

  @override
  String get moduleHotel => 'Add Hotel';

  @override
  String get moduleExpense => 'Add Expense';

  @override
  String get moduleBudget => 'Open Budget';

  @override
  String get moduleExport => 'Export Trip';

  @override
  String get tripNotFound => 'This trip no longer exists.';

  @override
  String get bannerEditorTitle => 'Edit banner';

  @override
  String get bannerTabImage => 'Image';

  @override
  String get bannerTabBackground => 'Background';

  @override
  String get bannerTabText => 'Title';

  @override
  String get bannerTabStyle => 'Style';

  @override
  String get bannerFromDevice => 'Upload from device';

  @override
  String get bannerFromTrip => 'Choose a trip photo';

  @override
  String get bannerNoTripPhotos => 'This trip has no photos yet.';

  @override
  String get bannerAdjustHint =>
      'Drag to reposition · pinch or use the slider to zoom';

  @override
  String get bannerZoom => 'Zoom';

  @override
  String get bannerResetCrop => 'Reset crop';

  @override
  String get bannerRemoveImage => 'Use color instead';

  @override
  String get bannerGradient => 'Gradient';

  @override
  String get bannerSolid => 'Solid color';

  @override
  String get bannerColorsBehindImage => 'Colors show when no photo is used.';

  @override
  String get bannerShowTitle => 'Show title on banner';

  @override
  String get bannerPlacement => 'Title placement';

  @override
  String get placementTopLeft => 'Top left';

  @override
  String get placementCenter => 'Center';

  @override
  String get placementBottomLeft => 'Bottom left';

  @override
  String get placementBottomCenter => 'Bottom center';

  @override
  String get bannerTextColor => 'Text color';

  @override
  String get bannerStyleClassic => 'Classic';

  @override
  String get bannerStyleMinimal => 'Minimal';

  @override
  String get bannerStyleBold => 'Bold';

  @override
  String get bannerStyleFramed => 'Framed';

  @override
  String get galleryEmpty => 'No photos yet. Add some to remember this trip.';

  @override
  String get galleryFromDevice => 'From device';

  @override
  String get photoCaption => 'Caption';

  @override
  String get photoFavorite => 'Favorite';

  @override
  String get favoritesOnly => 'Favorites only';

  @override
  String get setAsCover => 'Set as cover banner';

  @override
  String get coverUpdated => 'Cover banner updated';

  @override
  String get deletePhotoTitle => 'Delete photo?';

  @override
  String get deletePhotoBody =>
      'The photo will be removed from this trip and from the device storage used by WanderPlan.';

  @override
  String get photoAccessError =>
      'Could not access photos or camera. Check permissions in system Settings.';

  @override
  String get selectTripFirst => 'Open a trip from the Home tab first.';

  @override
  String get goToTrips => 'Go to My Trips';

  @override
  String currentTrip(String title) {
    return 'Current trip: $title';
  }

  @override
  String get mapNotYet =>
      'The real-world map, place search and route display are planned for Phase 3 and are not implemented yet.';

  @override
  String get timelineNotYet =>
      'The morning-to-night daily timeline is planned for Phase 2 and is not implemented yet.';

  @override
  String get budgetNotYet =>
      'Expense tracking and budget analysis are planned for Phase 2 and are not implemented yet.';

  @override
  String get moreFlights => 'Flights';

  @override
  String get moreTransportation => 'Transportation';

  @override
  String get moreHotels => 'Hotels';

  @override
  String get moreAttractions => 'Attractions';

  @override
  String get moreScenarios => 'Scenarios';

  @override
  String get moreGallery => 'Gallery';

  @override
  String get moreJournal => 'Journal';

  @override
  String get moreAnalysis => 'Analysis';

  @override
  String get moreImportExport => 'Import / Export';

  @override
  String get moreSettings => 'Settings';

  @override
  String get noTripSelected => 'No trip selected';

  @override
  String get todosTitle => 'Before you go';

  @override
  String get todosShort => 'To-dos';

  @override
  String todosProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get todosEmpty =>
      'Nothing on your list yet. Add tasks to finish before departure.';

  @override
  String get todosAllDone => 'All done — ready to go!';

  @override
  String get todosNextUp => 'Next up';

  @override
  String get todoAdd => 'Add task';

  @override
  String get todoEdit => 'Edit task';

  @override
  String get todoTitleField => 'Task';

  @override
  String get todoNotes => 'Notes';

  @override
  String get todoCategory => 'Category';

  @override
  String get todoDueDate => 'Due date';

  @override
  String get todoNoDueDate => 'No due date';

  @override
  String todoDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Due in $count days',
      one: 'Due tomorrow',
      zero: 'Due today',
    );
    return '$_temp0';
  }

  @override
  String todoOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get todoAfterDeparture => 'After departure';

  @override
  String get todoHideDone => 'Hide completed';

  @override
  String get todoSuggestions => 'Add suggestions';

  @override
  String get todoSuggestionsTitle => 'Common pre-trip tasks';

  @override
  String todoAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count',
      zero: 'Add',
    );
    return '$_temp0';
  }

  @override
  String get todoDeleted => 'Task deleted';

  @override
  String get undo => 'Undo';

  @override
  String get todoCatDocuments => 'Documents';

  @override
  String get todoCatBookings => 'Bookings';

  @override
  String get todoCatPacking => 'Packing';

  @override
  String get todoCatHealth => 'Health & insurance';

  @override
  String get todoCatMoney => 'Money & cards';

  @override
  String get todoCatConnectivity => 'Phone & internet';

  @override
  String get todoCatHome => 'Home';

  @override
  String get todoCatOther => 'Other';

  @override
  String get sugPassport => 'Check passport / ID expiry date';

  @override
  String get sugEntryRequirements => 'Check visa and entry requirements';

  @override
  String get sugInsurance => 'Arrange travel insurance';

  @override
  String get sugMedication => 'Pack medication and prescriptions';

  @override
  String get sugConfirmStay => 'Confirm accommodation bookings';

  @override
  String get sugCheckIn => 'Do online check-in for the flight';

  @override
  String get sugAirportTransport => 'Plan how to get to the airport or station';

  @override
  String get sugBankCards => 'Check card fees and notify your bank';

  @override
  String get sugLocalCash => 'Get some local currency';

  @override
  String get sugSimCard => 'Arrange SIM, eSIM or roaming';

  @override
  String get sugOfflineCopies => 'Save offline copies of tickets and documents';

  @override
  String get sugChargers => 'Pack chargers and a travel adapter';

  @override
  String get sugHomeArrangements => 'Arrange pets, plants and mail';

  @override
  String get shareTrip => 'Share with a friend';

  @override
  String get shareExplain =>
      'Your friend gets their own copy of this trip as a file. They open WanderPlan → My Trips → ⋮ → Import trip. Later changes are not synced between your copies.';

  @override
  String get shareIncludePhotos => 'Include gallery photos';

  @override
  String shareIncludePhotosHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos · makes the file larger',
      one: '1 photo · makes the file larger',
      zero: 'No photos to include',
    );
    return '$_temp0';
  }

  @override
  String get shareSend => 'Share file';

  @override
  String shareMessage(String title) {
    return 'My WanderPlan trip “$title”. To add it: WanderPlan → My Trips → ⋮ → Import trip.';
  }

  @override
  String shareFailed(String error) {
    return 'Could not create the share file: $error';
  }

  @override
  String get importTrip => 'Import trip';

  @override
  String importSuccess(String title) {
    return 'Imported “$title”';
  }

  @override
  String get importInvalid => 'This is not a WanderPlan trip file.';

  @override
  String get importTooNew =>
      'This file was made by a newer version of WanderPlan. Update the app to import it.';

  @override
  String homeSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips in your collection',
      one: '1 trip in your collection',
      zero: 'Where to next?',
    );
    return '$_temp0';
  }

  @override
  String get kpiDuration => 'Duration';

  @override
  String get kpiStatus => 'Status';

  @override
  String get soon => 'Soon';

  @override
  String get tripTools => 'Trip tools';

  @override
  String get viewAll => 'View all';

  @override
  String get addActivity => 'Add activity';

  @override
  String get editActivity => 'Edit activity';

  @override
  String get activityTitle => 'Title';

  @override
  String get activityKind => 'Type';

  @override
  String get kindSightseeing => 'Sightseeing';

  @override
  String get kindFood => 'Food';

  @override
  String get kindActivity => 'Activity';

  @override
  String get kindShopping => 'Shopping';

  @override
  String get kindRest => 'Rest';

  @override
  String get kindFlight => 'Flight';

  @override
  String get kindTrain => 'Train';

  @override
  String get kindBus => 'Bus';

  @override
  String get kindTransfer => 'Taxi / metro';

  @override
  String get kindFerry => 'Ferry';

  @override
  String get kindHotel => 'Hotel';

  @override
  String get kindOther => 'Other';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldStart => 'Start';

  @override
  String get fieldEnd => 'End';

  @override
  String get fieldEndDate => 'End date';

  @override
  String get fieldCheckIn => 'Check-in';

  @override
  String get fieldCheckOut => 'Check-out';

  @override
  String get sameDay => 'Same day';

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldFrom => 'From';

  @override
  String get fieldTo => 'To';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get onMap => 'On the map';

  @override
  String get notOnMap => 'Not on the map yet';

  @override
  String get fieldCost => 'Estimated cost';

  @override
  String get fieldBooking => 'Booking';

  @override
  String get bookingNotBooked => 'Not booked';

  @override
  String get bookingBooked => 'Booked';

  @override
  String get bookingConfirmed => 'Confirmed';

  @override
  String get bookingCancelled => 'Cancelled';

  @override
  String get fieldProvider => 'Airline / operator / hotel';

  @override
  String get fieldServiceNumber => 'Flight / train number';

  @override
  String get fieldBookingRef => 'Booking reference (private)';

  @override
  String get fieldBookingUrl => 'Booking link';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldLocked => 'Locked';

  @override
  String get lockedHelp =>
      'Locked items are confirmed bookings and are never moved by dragging.';

  @override
  String get fieldOptional => 'Optional';

  @override
  String get optionalHelp => 'Nice to have; can be skipped if time is short.';

  @override
  String get endBeforeStart => 'End must be after start';

  @override
  String get deleteActivityTitle => 'Delete activity?';

  @override
  String get activityDeleted => 'Activity deleted';

  @override
  String get duplicateToNextDay => 'Copy to next day';

  @override
  String get lockedCannotMove =>
      'Locked activities can\'t be moved. Unlock it first.';

  @override
  String get timelineEmptyDay => 'Nothing planned for this day yet.';

  @override
  String get timelineNoDays =>
      'Set trip dates or add an activity to start planning day by day.';

  @override
  String get viewList => 'List';

  @override
  String get viewGrid => 'Time grid';

  @override
  String get dragHint =>
      'Long-press a block and drag to move it · drag its bottom edge to change the duration';

  @override
  String freeTime(String duration) {
    return '$duration free';
  }

  @override
  String durationHm(int h, int m) {
    return '$h h $m min';
  }

  @override
  String durationH(int h) {
    return '$h h';
  }

  @override
  String durationM(int m) {
    return '$m min';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$_temp0';
  }

  @override
  String dayN(int n) {
    return 'Day $n';
  }

  @override
  String get outsideTrip => 'Outside trip';

  @override
  String get dayFeasible => 'Feasible';

  @override
  String get dayTight => 'Tight';

  @override
  String get dayUnrealistic => 'Unrealistic';

  @override
  String get dayUnknown => 'Needs info';

  @override
  String get dayEmpty => 'Free day';

  @override
  String issueOverlap(String a, String b, int minutes) {
    return '“$a” overlaps “$b” by $minutes min';
  }

  @override
  String issueNoTravelTime(String a, String b) {
    return 'No time to get from “$a” to “$b”';
  }

  @override
  String issueTightTravel(
    String a,
    String b,
    String km,
    int minutes,
    int needed,
  ) {
    return '“$a” → “$b” are $km km apart in a straight line but only $minutes min is free; allow about $needed min';
  }

  @override
  String issueDepartureBuffer(String b, int minutes, int needed) {
    return 'Only $minutes min before “$b”; allow at least $needed min to get there and check in';
  }

  @override
  String issueLongDay(String hours) {
    return 'Very full day: $hours h of activities';
  }

  @override
  String issueEarlyAndLate(String hours) {
    return 'Early start and late finish ($hours h day)';
  }

  @override
  String get issueNoMealBreak => 'No meal or rest break around lunch';

  @override
  String get issueLateFinish => 'Ends after 23:00';

  @override
  String get issueMissingAccommodation =>
      'No accommodation planned for this night';

  @override
  String issueOverlappingStays(String titles) {
    return 'Two stays on the same night: $titles';
  }

  @override
  String issueTransportNotBooked(String titles) {
    return 'Not booked yet: $titles';
  }

  @override
  String issueOutsideTripDates(String titles) {
    return 'Outside the trip dates: $titles';
  }

  @override
  String get feasibilityNote =>
      'Checks use rules of thumb (straight-line distance at about 25 km/h, 2 h before flights, 30 min before trains). They are estimates, not live routes.';

  @override
  String get bookingsTitle => 'Bookings';

  @override
  String get bookingsEmpty => 'No flights, trains or hotels yet.';

  @override
  String get bookingsTransport => 'Transport';

  @override
  String get bookingsStays => 'Stays';

  @override
  String get nextUp => 'Next up';

  @override
  String get planCheck => 'Plan check';

  @override
  String daysNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days need attention',
      one: '1 day needs attention',
    );
    return '$_temp0';
  }

  @override
  String get allDaysOk => 'All planned days look feasible';

  @override
  String get noActivitiesYet => 'No activities planned yet';

  @override
  String activitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '1 activity',
    );
    return '$_temp0';
  }

  @override
  String get mapAllDays => 'All days';

  @override
  String mapNoPins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities have no location yet',
      one: '1 activity has no location yet',
    );
    return '$_temp0';
  }

  @override
  String get mapOnlineNote =>
      'Map tiles and place search need an internet connection.';

  @override
  String get mapEmpty =>
      'Nothing on the map yet. Search for a place, explore nearby, or edit an activity and use “Pick on map”.';

  @override
  String get fitAll => 'Show all';

  @override
  String get placeAttraction => 'Attractions';

  @override
  String get placeRestaurant => 'Restaurants';

  @override
  String get placeHotel => 'Hotels';

  @override
  String get placeAirport => 'Airports';

  @override
  String get placeRailwayStation => 'Railway stations';

  @override
  String get placeBusStation => 'Bus stations';

  @override
  String get placeOther => 'Other';

  @override
  String get modeWalking => 'Walking';

  @override
  String get modeCycling => 'Cycling';

  @override
  String get modeDriving => 'Driving / taxi';

  @override
  String get mapProvider => 'Map provider';

  @override
  String get providerAuto => 'Automatic';

  @override
  String get providerAutoHelp =>
      'Amap in mainland China, OpenStreetMap elsewhere';

  @override
  String get providerOsm => 'OpenStreetMap';

  @override
  String get providerAmap => 'Amap (Gaode)';

  @override
  String get amapNoKey =>
      'Amap search and routes need an Amap key, so OpenStreetMap search and routes are used.';

  @override
  String get savedPlaces => 'Saved places';

  @override
  String get savedPlacesEmpty =>
      'No saved places yet. Search, explore nearby, or long-press the map to pin one.';

  @override
  String get savePlace => 'Save place';

  @override
  String get removePlace => 'Remove';

  @override
  String get placeSaved => 'Saved to this trip';

  @override
  String get placeRemoved => 'Place removed';

  @override
  String get addToDay => 'Add to day';

  @override
  String get chooseDay => 'Choose a day';

  @override
  String addedToDay(String date) {
    return 'Added to $date · time not set';
  }

  @override
  String plannedOn(String dates) {
    return 'In the plan: $dates';
  }

  @override
  String get notPlanned => 'Not in the plan yet';

  @override
  String sourceSearch(String provider) {
    return 'Coordinates from $provider search';
  }

  @override
  String get sourcePinned => 'Pinned on the map by you';

  @override
  String get sourceImported => 'Coordinates imported';

  @override
  String get mapPinnedPlace => 'Pinned place';

  @override
  String get mapLongPressHint => 'Long-press to pin a place';

  @override
  String get nearbyEmpty => 'Nothing found around this area';

  @override
  String get filterMarkers => 'Filter markers';

  @override
  String get layerPlan => 'Plan';

  @override
  String get layerResults => 'Search & nearby results';

  @override
  String get myLocation => 'My location';

  @override
  String get locationOff => 'Location services are turned off';

  @override
  String get locationDenied => 'Location permission was denied';

  @override
  String get locationDeniedForever =>
      'Location permission is blocked. Allow it in system settings.';

  @override
  String get locationUnavailable => 'Couldn\'t get your location';

  @override
  String get routeLoading => 'Finding routes…';

  @override
  String routeTotal(String distance, String duration) {
    return '$distance · about $duration';
  }

  @override
  String routeEstimateNote(String provider) {
    return 'Road routes: $provider. Times are typical estimates, not live traffic or timetables.';
  }

  @override
  String routeUnverified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count legs have no road route: straight lines, unverified',
      one: '1 leg has no road route: straight line, unverified',
    );
    return '$_temp0';
  }

  @override
  String get routeBooked =>
      'Flights, trains and ferries are drawn as direct dotted lines, not their actual path.';

  @override
  String get routeNoTransit =>
      'Public transport routing isn’t available here; use “Navigate with” for transit directions.';

  @override
  String routeUnordered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops have no time yet, so they aren’t in the route',
      one: '1 stop has no time yet, so it isn’t in the route',
    );
    return '$_temp0';
  }

  @override
  String get findLocations => 'Find locations';

  @override
  String get locateTitle => 'Find locations';

  @override
  String get locateIntro =>
      'These places have a name but no coordinates, so they can’t be shown on the map. Each name is searched online and matches near your trip’s destinations come first. Nothing changes until you choose a match.';

  @override
  String locateProgress(int done, int total) {
    return 'Searched $done of $total…';
  }

  @override
  String locateUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used by $count activities',
      one: 'Used by 1 activity',
    );
    return '$_temp0';
  }

  @override
  String get locatePlaceholder =>
      'General name: choose the exact place yourself';

  @override
  String locateNoMatch(String query) {
    return 'No match for “$query”. Try another name or pick it on the map.';
  }

  @override
  String locateFar(int km) {
    return '$km km from your destinations';
  }

  @override
  String get locateUse => 'Use this';

  @override
  String get locateLocated => 'Located';

  @override
  String get locateSearchAgain => 'Search again';

  @override
  String get locateSearch => 'Search';

  @override
  String get locateRefineHelp => 'Tip: add the city, e.g. “中山路步行街 厦门”';

  @override
  String locateUseAll(int count) {
    return 'Use selected matches ($count)';
  }

  @override
  String get locateAllDone => 'Every place in the plan has coordinates.';

  @override
  String get pasteLocation => 'Paste a link or coordinates';

  @override
  String get pasteLocationHint =>
      'Google Maps link, share link (maps.app.goo.gl), embed code, “27.8124, 99.7048” or a Plus Code like “RP63+XW2, Shangri-La”';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get pasteFromChineseMap =>
      'Copied from Google Maps, Amap or Apple Maps';

  @override
  String get pasteFromChineseMapHelp =>
      'In mainland China these maps are offset from GPS; WanderPlan corrects it. Turn off for GPS or OpenStreetMap coordinates.';

  @override
  String get pasteResolve => 'Use location';

  @override
  String get linkUnrecognized =>
      'Not recognised. Paste a Google Maps / Amap / Apple Maps link, coordinates like “27.81, 99.70”, or a Plus Code.';

  @override
  String get linkShortFailed =>
      'Couldn’t open the short link (are you online?). Open it in Google Maps and copy the full link or coordinates instead.';

  @override
  String get linkPlusNeedsArea =>
      'This short Plus Code needs its area, e.g. “RP63+XW2, Shangri-La”.';

  @override
  String get linkCentreOnly =>
      'This link only gives the map’s centre, so the pin may be slightly off. Check it.';

  @override
  String get linkConverted =>
      'Converted from China’s map offset (GCJ-02) to GPS coordinates.';

  @override
  String sourceLink(String provider) {
    return 'Coordinates from a $provider link';
  }

  @override
  String get sourcePlusCode => 'Coordinates from a Plus Code';

  @override
  String get sourceCoordinates => 'Coordinates entered by you';

  @override
  String get pasteLink => 'Paste link';

  @override
  String get modeTransit => 'Train / metro / bus';

  @override
  String get dayStart => 'Start';

  @override
  String get dayEnd => 'End';

  @override
  String get dayStartTitle => 'Where does this day start?';

  @override
  String get dayEndTitle => 'Where does this day end?';

  @override
  String get dayAnchorNotSet => 'not set (no hotel that night)';

  @override
  String get dayAnchorHotel => 'hotel';

  @override
  String get dayAnchorUseHotel => 'Use the hotel (default)';

  @override
  String get dayLegs => 'Getting between stops';

  @override
  String get legTitle => 'How do you get there?';

  @override
  String legDefault(String mode) {
    return 'Day default ($mode)';
  }

  @override
  String get legMinutes => 'Your travel time (optional)';

  @override
  String get legMinutesHelp => 'Leave empty to use the route’s typical time.';

  @override
  String get legTransitHelp =>
      'Train, metro and bus times aren’t calculated (no timetable data). Enter the time from the timetable or a map app.';

  @override
  String get legTransitNoTime => 'Train/metro/bus · enter your time';

  @override
  String get legUndecided => 'Transport not decided yet';

  @override
  String get legNoRoute => 'No route (unverified)';

  @override
  String get legYourEstimate => 'your estimate';

  @override
  String legTooShort(int minutes) {
    return '$minutes min short before the next start';
  }

  @override
  String get routeTransitNote =>
      'Dashed blue lines are train/metro/bus legs: straight lines with your own times.';

  @override
  String get optimizeOrder => 'Optimize order';

  @override
  String get optimizeNeedsTwo =>
      'Needs at least 2 places with a location that aren’t locked or booked.';

  @override
  String get optimizeTitle => 'Suggested order';

  @override
  String optimizeSaves(String before, String after, String saved) {
    return 'Travel $before → $after (saves $saved)';
  }

  @override
  String optimizeAlreadyBest(String travel) {
    return 'Your order is already the shortest ($travel of travel).';
  }

  @override
  String optimizeRouted(String mode) {
    return 'Based on $mode routes; typical times, not live traffic.';
  }

  @override
  String optimizeEstimated(String mode) {
    return 'No route data: estimated from straight-line distance for $mode.';
  }

  @override
  String get optimizeDayStart => 'Day starts at';

  @override
  String optimizeTravel(String time) {
    return '$time travel';
  }

  @override
  String optimizeWait(String time) {
    return 'wait $time for opening';
  }

  @override
  String get optimizeFixed => 'Fixed';

  @override
  String get optimizeAssumed => 'No time set: 1 h assumed';

  @override
  String get optimizeClosed => 'Closed that day';

  @override
  String get optimizeOutsideHours => 'Outside opening hours';

  @override
  String optimizeLate(int minutes) {
    return '$minutes min late';
  }

  @override
  String get optimizeKeepsFixed =>
      'Locked, booked and transport items keep their times. Only places you haven’t booked are moved.';

  @override
  String get optimizeApply => 'Apply';

  @override
  String optimizeApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count activities',
      one: 'Updated 1 activity',
    );
    return '$_temp0';
  }

  @override
  String get gettingHere => 'Getting here';

  @override
  String get gettingHereDefault => 'Day default';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get openingHoursKnown => 'Has opening hours';

  @override
  String get openingHoursHelp =>
      'Check the official site; WanderPlan uses them to warn and to plan the order.';

  @override
  String get opens => 'Opens';

  @override
  String get closes => 'Closes';

  @override
  String get closesNextDay => 'closes after midnight';

  @override
  String get closedOn => 'Closed on';

  @override
  String get closedThatDay => 'Closed on this day!';

  @override
  String get reservation => 'Reservation';

  @override
  String get reservationRequired => 'Needs a reservation or ticket in advance';

  @override
  String get reservationVia => 'Where / how to book';

  @override
  String get reservationViaHint =>
      'e.g. official WeChat account, Trip.com app, website';

  @override
  String get bookAheadDays => 'Book how many days before?';

  @override
  String get daysUnit => 'days';

  @override
  String bookByDate(String date) {
    return 'Book by $date';
  }

  @override
  String get remindToBook => 'Remind me on that day';

  @override
  String get remindToBookHelp =>
      'A notification at 09:00 (trip time) on the book-by date.';

  @override
  String get remindPermissionDenied =>
      'Notifications are off for WanderPlan. Allow them in system settings to get reminders.';

  @override
  String get reminderTitle => 'Time to book';

  @override
  String reminderBody(String title, String date, String via) {
    return 'Book “$title” for $date. $via';
  }

  @override
  String issueTightTravelOwn(String a, String b, int minutes, int needed) {
    return '“$a” → “$b”: only $minutes min, but you allowed $needed min to get there';
  }

  @override
  String issueClosedOnDay(String title) {
    return '“$title” is closed on this day';
  }

  @override
  String issueOutsideOpeningHours(String title) {
    return '“$title” is planned outside its opening hours';
  }

  @override
  String issueBookingNeeded(String title) {
    return '“$title” still needs a reservation';
  }

  @override
  String issueBookBy(String title, String date) {
    return 'Book “$title” by $date';
  }

  @override
  String get flightUpdates => 'Flight updates';

  @override
  String get flightUpdatesSubtitle => 'Live status from your WanderPlan server';

  @override
  String get flightPrivacyTitle => 'Privacy';

  @override
  String get actionRetry => 'Try again';

  @override
  String get flightUpdatesOff => 'Not working right now';

  @override
  String get flightServerChecking => 'Connecting…';

  @override
  String get flightServerIntro =>
      'Live flight status comes from the WanderPlan server. It checks each flight once for everyone and holds the flight-data key; this phone only reads the results. Nothing to set up.';

  @override
  String get flightServerTitle => 'Status';

  @override
  String flightServerConnectedAs(String who) {
    return 'On · signed in as $who';
  }

  @override
  String get flightServerPrivacy =>
      'No flight-data API key is stored on this phone. The app signs in to the WanderPlan server by itself and keeps that sign-in in the keychain (this device only).';

  @override
  String get flightNotConnected =>
      'Live flight updates aren’t available in this version of the app.';

  @override
  String get flightSignInRejected =>
      'The WanderPlan server didn’t accept the sign-in. Try again later.';

  @override
  String get flightServerNoKey =>
      'Live flight data isn’t switched on at the WanderPlan server yet.';

  @override
  String get flightNoDataYet =>
      'No data yet. Your server checks this flight on its schedule (live data appears around the flight day).';

  @override
  String get flightStale => 'Last check failed; showing the last known data';

  @override
  String get flightNeedsNumber =>
      'Add the flight number (e.g. MU5103) to get live updates.';

  @override
  String get flightCheckNow => 'Check now';

  @override
  String get flightNoChanges => 'No changes since the last check';

  @override
  String get flightQuotaReached =>
      'Your server’s flight-data plan is out of requests this month.';

  @override
  String get flightNetwork =>
      'Can’t reach the WanderPlan server right now. Check your internet connection and try again.';

  @override
  String get flightUnknownError =>
      'The server didn’t answer as expected. Try again later.';

  @override
  String get flightScheduled => 'Scheduled';

  @override
  String get flightInAir => 'In the air';

  @override
  String get flightLanded => 'Landed';

  @override
  String get flightCancelled => 'Cancelled';

  @override
  String get flightIncident => 'Incident';

  @override
  String get flightDiverted => 'Diverted';

  @override
  String get flightStatusUnknown => 'Status unknown';

  @override
  String flightDelayed(int minutes) {
    return 'Delayed $minutes min';
  }

  @override
  String get flightDep => 'Dep';

  @override
  String get flightArr => 'Arr';

  @override
  String flightTerminal(String t) {
    return 'T$t';
  }

  @override
  String flightGate(String g) {
    return 'Gate $g';
  }

  @override
  String flightBelt(String b) {
    return 'Belt $b';
  }

  @override
  String flightChecked(String time) {
    return 'Checked $time · times are local at each airport';
  }

  @override
  String flightNotifyTitle(String flight) {
    return '$flight: flight update';
  }

  @override
  String flightChangeStatus(String status) {
    return 'Now $status';
  }

  @override
  String flightChangeDeparture(String from, String to) {
    return 'Departure $from → $to';
  }

  @override
  String flightChangeArrival(String from, String to) {
    return 'Arrival $from → $to';
  }

  @override
  String flightChangeDepTerminal(String t) {
    return 'Departure terminal $t';
  }

  @override
  String flightChangeDepGate(String g) {
    return 'Gate $g';
  }

  @override
  String flightChangeArrTerminal(String t) {
    return 'Arrival terminal $t';
  }

  @override
  String flightChangeArrGate(String g) {
    return 'Arrival gate $g';
  }

  @override
  String flightChangeBaggage(String b) {
    return 'Baggage belt $b';
  }

  @override
  String get navigateWith => 'Navigate with';

  @override
  String get openGoogleMaps => 'Google Maps';

  @override
  String get openAppleMaps => 'Apple Maps';

  @override
  String get openAmap => 'Amap (Gaode)';

  @override
  String get openFailed => 'Could not open the maps app';

  @override
  String get chooseLocation => 'Choose location';

  @override
  String get pickHint => 'Tap the map to drop a pin, or search for a place.';

  @override
  String get useThisPlace => 'Use this place';

  @override
  String get searchPlaces => 'Search places (online)';

  @override
  String searchFailed(String error) {
    return 'Search unavailable: $error';
  }

  @override
  String get noResults => 'No places found';

  @override
  String get placeName => 'Place name';

  @override
  String get removePin => 'Remove pin';

  @override
  String get budgetPlanned => 'Planned';

  @override
  String get budgetSpent => 'Spent';

  @override
  String get budgetRemaining => 'Remaining';

  @override
  String get budgetLimit => 'Budget';

  @override
  String get budgetOverview => 'Overview';

  @override
  String get budgetExpenses => 'Expenses';

  @override
  String get budgetRates => 'Rates';

  @override
  String get byCategory => 'By category';

  @override
  String get byDay => 'By day';

  @override
  String get plannedVsActual => 'Planned vs actual';

  @override
  String get variance => 'Difference';

  @override
  String perPersonSpent(String amount) {
    return '$amount spent per person';
  }

  @override
  String unpaidPlanned(String amount) {
    return '$amount still to pay or book';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get expenseTitle => 'What for';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get expensePlanned => 'Planned';

  @override
  String get expenseActual => 'Actual';

  @override
  String get expensePaid => 'Paid';

  @override
  String get expenseUnpaid => 'Unpaid';

  @override
  String get expenseShared => 'Shared by all travelers';

  @override
  String get linkedActivity => 'Linked activity';

  @override
  String get noneOption => 'None';

  @override
  String get expenseDeleted => 'Expense deleted';

  @override
  String get noExpenses =>
      'No expenses yet. Add what you spend during the trip, or planned costs that aren’t in the itinerary.';

  @override
  String get fromItinerary => 'From itinerary';

  @override
  String get budgetEmpty =>
      'Add costs to activities or planned expenses to see your plan here.';

  @override
  String get warnNoCurrency =>
      'Set a primary currency for this trip to track the budget.';

  @override
  String warnMissingRates(String currencies) {
    return 'No exchange rate for $currencies. Those amounts are not counted yet.';
  }

  @override
  String warnOverPlanned(String amount) {
    return 'The plan is over budget by $amount.';
  }

  @override
  String warnOverActual(String amount) {
    return 'Spending is over budget by $amount.';
  }

  @override
  String get warnNearLimit => 'The plan uses more than 90% of the budget.';

  @override
  String rateLabel(String currency, String base) {
    return '1 $currency = ? $base';
  }

  @override
  String get rateManual => 'Entered manually · not verified';

  @override
  String rateFrom(String source, String date) {
    return 'From $source · $date';
  }

  @override
  String get rateMissing => 'No rate yet';

  @override
  String get refreshRates => 'Fetch live rates (online)';

  @override
  String get ratesUpdated => 'Rates updated';

  @override
  String ratesUnsupported(String currencies) {
    return 'Not available online: $currencies. Enter them manually.';
  }

  @override
  String ratesFailed(String error) {
    return 'Could not fetch rates: $error';
  }

  @override
  String get addRate => 'Add rate';

  @override
  String get rateInvalid => 'Enter a number greater than 0';

  @override
  String ratesHelp(String base) {
    return 'Amounts in other currencies are converted to $base with these rates.';
  }

  @override
  String get amountInvalid => 'Enter an amount of 0 or more';

  @override
  String get catFlights => 'Flights';

  @override
  String get catTrains => 'Trains';

  @override
  String get catBuses => 'Buses & ferries';

  @override
  String get catTaxis => 'Taxis & local transport';

  @override
  String get catHotels => 'Hotels';

  @override
  String get catFood => 'Food';

  @override
  String get catAttractions => 'Attractions';

  @override
  String get catActivities => 'Activities';

  @override
  String get catInternet => 'Internet & SIM';

  @override
  String get catInsurance => 'Insurance';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catEmergency => 'Emergency fund';

  @override
  String get catMisc => 'Miscellaneous';

  @override
  String get kindTransport => 'Transport (mode TBD)';

  @override
  String get catTransport => 'Other transport';

  @override
  String get timeTbd => 'Time TBD';

  @override
  String get timeTbdToggle => 'Time to be decided';

  @override
  String get timeTbdHelp =>
      'Use this while the schedule isn’t confirmed. No time is guessed; the day shows “Needs info” until you set one.';

  @override
  String issueTimeNotSet(String titles) {
    return 'No time set yet: $titles';
  }

  @override
  String get notScheduled => 'Not scheduled yet';

  @override
  String importInvalidDetail(String detail) {
    return 'Could not import: $detail';
  }

  @override
  String get importHow => 'How do you want to import?';

  @override
  String get importChooseFile => 'Choose a file';

  @override
  String get importChooseFileHelp =>
      'A .wanderplan file from a friend, or a .json file';

  @override
  String get importPaste => 'Paste text';

  @override
  String get importPasteHelp =>
      'Paste trip JSON copied from ChatGPT, Notes, email…';

  @override
  String get importPasteHint => 'Paste the trip JSON here';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get actionClear => 'Clear';

  @override
  String get importAction => 'Import';

  @override
  String get importFormatHelp => 'Format guide: docs/IMPORT_FORMAT.md';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get privacyTitle => 'Data & privacy';

  @override
  String get privacyBody =>
      'WanderPlan stores your trips and photos only on this device. No account is required.';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get deleteAllDataBody =>
      'All trips, photos and settings on this device will be permanently deleted.';

  @override
  String get allDataDeleted => 'All data deleted';

  @override
  String get atlasEyebrow => 'Your personal atlas';

  @override
  String get atlasSubtitle => 'Your plans, places and days away.';

  @override
  String atlasCollection(int count) {
    return '$count trips in your collection';
  }

  @override
  String get atlasJourney => 'Journey';

  @override
  String get atlasFilters => 'Filter trips';

  @override
  String get atlasBegin => 'A new chapter';

  @override
  String get atlasFooter => 'Good journeys start with a little planning.';

  @override
  String get atlasEdition => 'The travel collection';

  @override
  String get atlasSigninHeadline =>
      'Somewhere new.\nSomething to look forward to.';
}
