import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WanderPlan'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get tabTimeline;

  /// No description provided for @tabBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get tabBudget;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @searchTrips.
  ///
  /// In en, this message translates to:
  /// **'Search trips'**
  String get searchTrips;

  /// No description provided for @searchTripsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trips match your search.'**
  String get searchTripsEmpty;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get myTrips;

  /// No description provided for @createTrip.
  ///
  /// In en, this message translates to:
  /// **'Create new trip'**
  String get createTrip;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New Trip'**
  String get newTrip;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get editTrip;

  /// No description provided for @emptyTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get emptyTripsTitle;

  /// No description provided for @emptyTripsBody.
  ///
  /// In en, this message translates to:
  /// **'Plan your next adventure. A trip only needs a title — you can add everything else later.'**
  String get emptyTripsBody;

  /// No description provided for @emptyFilterBody.
  ///
  /// In en, this message translates to:
  /// **'No trips match this filter.'**
  String get emptyFilterBody;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get filterUpcoming;

  /// No description provided for @filterTraveling.
  ///
  /// In en, this message translates to:
  /// **'Traveling'**
  String get filterTraveling;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// No description provided for @statusDreaming.
  ///
  /// In en, this message translates to:
  /// **'Dreaming'**
  String get statusDreaming;

  /// No description provided for @statusPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get statusPlanning;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusTraveling.
  ///
  /// In en, this message translates to:
  /// **'Traveling'**
  String get statusTraveling;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get actionDuplicate;

  /// No description provided for @actionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get actionArchive;

  /// No description provided for @actionUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get actionUnarchive;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEditBanner.
  ///
  /// In en, this message translates to:
  /// **'Edit banner'**
  String get actionEditBanner;

  /// No description provided for @actionReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder trips'**
  String get actionReorder;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @duplicateSuffix.
  ///
  /// In en, this message translates to:
  /// **' (copy)'**
  String get duplicateSuffix;

  /// No description provided for @deleteTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete trip?'**
  String get deleteTripTitle;

  /// No description provided for @deleteTripBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and all of its photos will be permanently deleted. This cannot be undone.'**
  String deleteTripBody(String title);

  /// No description provided for @tripDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Trip duplicated'**
  String get tripDuplicated;

  /// No description provided for @tripArchived.
  ///
  /// In en, this message translates to:
  /// **'Trip archived'**
  String get tripArchived;

  /// No description provided for @tripUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Trip restored from archive'**
  String get tripUnarchived;

  /// No description provided for @tripDeleted.
  ///
  /// In en, this message translates to:
  /// **'Trip deleted'**
  String get tripDeleted;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @restoreNotYet.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore are not implemented yet (planned for the Import / Export phase).'**
  String get restoreNotYet;

  /// No description provided for @datesUndecided.
  ///
  /// In en, this message translates to:
  /// **'Dates not decided'**
  String get datesUndecided;

  /// No description provided for @datesFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible dates'**
  String get datesFlexible;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @travelersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveler} other{{count} travelers}}'**
  String travelersCount(int count);

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String unitDays(int count);

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String unitHours(int count);

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String unitMinutes(int count);

  /// No description provided for @countdownDaysToGo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Departing today} =1{1 day to go} other{{count} days to go}}'**
  String countdownDaysToGo(int count);

  /// No description provided for @countdownRemaining.
  ///
  /// In en, this message translates to:
  /// **'{value} remaining'**
  String countdownRemaining(String value);

  /// No description provided for @countdownDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String countdownDayOf(int day, int total);

  /// No description provided for @countdownCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip Completed'**
  String get countdownCompleted;

  /// No description provided for @countdownNoDate.
  ///
  /// In en, this message translates to:
  /// **'Set dates to start the countdown'**
  String get countdownNoDate;

  /// No description provided for @departsOn.
  ///
  /// In en, this message translates to:
  /// **'Departs {date}'**
  String departsOn(String date);

  /// No description provided for @departsOnAt.
  ///
  /// In en, this message translates to:
  /// **'Departs {date} at {time}'**
  String departsOnAt(String date, String time);

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip title'**
  String get fieldTitle;

  /// No description provided for @fieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Autumn in Kyoto'**
  String get fieldTitleHint;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get titleRequired;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @sectionCover.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get sectionCover;

  /// No description provided for @coverPick.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get coverPick;

  /// No description provided for @coverCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get coverCamera;

  /// No description provided for @coverRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get coverRemove;

  /// No description provided for @coverHint.
  ///
  /// In en, this message translates to:
  /// **'You can crop and style the banner after saving.'**
  String get coverHint;

  /// No description provided for @sectionDestinations.
  ///
  /// In en, this message translates to:
  /// **'Destinations'**
  String get sectionDestinations;

  /// No description provided for @fieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get fieldCountry;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// No description provided for @addDestination.
  ///
  /// In en, this message translates to:
  /// **'Add destination'**
  String get addDestination;

  /// No description provided for @removeDestination.
  ///
  /// In en, this message translates to:
  /// **'Remove destination'**
  String get removeDestination;

  /// No description provided for @mainDestination.
  ///
  /// In en, this message translates to:
  /// **'Main destination'**
  String get mainDestination;

  /// No description provided for @sectionDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get sectionDates;

  /// No description provided for @pickDates.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get pickDates;

  /// No description provided for @clearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get clearDates;

  /// No description provided for @datesConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Dates confirmed'**
  String get datesConfirmed;

  /// No description provided for @datesConfirmedHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off while your dates are still flexible.'**
  String get datesConfirmedHelp;

  /// No description provided for @departureTime.
  ///
  /// In en, this message translates to:
  /// **'Departure time'**
  String get departureTime;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @fieldTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get fieldTimeZone;

  /// No description provided for @timeZoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Countdown and dates use this time zone.'**
  String get timeZoneHelp;

  /// No description provided for @searchTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Search time zones'**
  String get searchTimeZone;

  /// No description provided for @sectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get sectionDetails;

  /// No description provided for @fieldTravelers.
  ///
  /// In en, this message translates to:
  /// **'Travelers'**
  String get fieldTravelers;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Primary currency'**
  String get fieldCurrency;

  /// No description provided for @currencyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a 3-letter ISO currency code, e.g. USD'**
  String get currencyInvalid;

  /// No description provided for @fieldBudget.
  ///
  /// In en, this message translates to:
  /// **'Total budget'**
  String get fieldBudget;

  /// No description provided for @budgetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get budgetInvalid;

  /// No description provided for @budgetNeedsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose a currency for the budget'**
  String get budgetNeedsCurrency;

  /// No description provided for @fieldTravelStyle.
  ///
  /// In en, this message translates to:
  /// **'Travel style'**
  String get fieldTravelStyle;

  /// No description provided for @fieldStage.
  ///
  /// In en, this message translates to:
  /// **'Planning stage'**
  String get fieldStage;

  /// No description provided for @stageHelp.
  ///
  /// In en, this message translates to:
  /// **'Upcoming, traveling and completed are set automatically from your dates.'**
  String get stageHelp;

  /// No description provided for @styleRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get styleRelaxed;

  /// No description provided for @styleBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get styleBalanced;

  /// No description provided for @stylePacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get stylePacked;

  /// No description provided for @styleBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get styleBudget;

  /// No description provided for @styleComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get styleComfort;

  /// No description provided for @styleLuxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury'**
  String get styleLuxury;

  /// No description provided for @styleAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get styleAdventure;

  /// No description provided for @styleFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get styleFamily;

  /// No description provided for @saveTripCreate.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get saveTripCreate;

  /// No description provided for @saveTripChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveTripChanges;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String saveFailed(String error);

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @budgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetTitle;

  /// No description provided for @budgetNotSet.
  ///
  /// In en, this message translates to:
  /// **'No budget set'**
  String get budgetNotSet;

  /// No description provided for @budgetPerPerson.
  ///
  /// In en, this message translates to:
  /// **'{amount} per person'**
  String budgetPerPerson(String amount);

  /// No description provided for @photosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosTitle;

  /// No description provided for @photoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos} =1{1 photo} other{{count} photos}}'**
  String photoCount(int count);

  /// No description provided for @openGallery.
  ///
  /// In en, this message translates to:
  /// **'Open gallery'**
  String get openGallery;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @planningModules.
  ///
  /// In en, this message translates to:
  /// **'Planning tools'**
  String get planningModules;

  /// No description provided for @notImplementedYet.
  ///
  /// In en, this message translates to:
  /// **'Not implemented yet'**
  String get notImplementedYet;

  /// No description provided for @moduleMap.
  ///
  /// In en, this message translates to:
  /// **'Open Map'**
  String get moduleMap;

  /// No description provided for @moduleAttraction.
  ///
  /// In en, this message translates to:
  /// **'Add Attraction'**
  String get moduleAttraction;

  /// No description provided for @moduleItinerary.
  ///
  /// In en, this message translates to:
  /// **'Edit Itinerary'**
  String get moduleItinerary;

  /// No description provided for @moduleFlight.
  ///
  /// In en, this message translates to:
  /// **'Add Flight'**
  String get moduleFlight;

  /// No description provided for @moduleTrain.
  ///
  /// In en, this message translates to:
  /// **'Add Train'**
  String get moduleTrain;

  /// No description provided for @moduleHotel.
  ///
  /// In en, this message translates to:
  /// **'Add Hotel'**
  String get moduleHotel;

  /// No description provided for @moduleExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get moduleExpense;

  /// No description provided for @moduleBudget.
  ///
  /// In en, this message translates to:
  /// **'Open Budget'**
  String get moduleBudget;

  /// No description provided for @moduleExport.
  ///
  /// In en, this message translates to:
  /// **'Export Trip'**
  String get moduleExport;

  /// No description provided for @tripNotFound.
  ///
  /// In en, this message translates to:
  /// **'This trip no longer exists.'**
  String get tripNotFound;

  /// No description provided for @bannerEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit banner'**
  String get bannerEditorTitle;

  /// No description provided for @bannerTabImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get bannerTabImage;

  /// No description provided for @bannerTabBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get bannerTabBackground;

  /// No description provided for @bannerTabText.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get bannerTabText;

  /// No description provided for @bannerTabStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get bannerTabStyle;

  /// No description provided for @bannerFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Upload from device'**
  String get bannerFromDevice;

  /// No description provided for @bannerFromTrip.
  ///
  /// In en, this message translates to:
  /// **'Choose a trip photo'**
  String get bannerFromTrip;

  /// No description provided for @bannerNoTripPhotos.
  ///
  /// In en, this message translates to:
  /// **'This trip has no photos yet.'**
  String get bannerNoTripPhotos;

  /// No description provided for @bannerAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reposition · pinch or use the slider to zoom'**
  String get bannerAdjustHint;

  /// No description provided for @bannerZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get bannerZoom;

  /// No description provided for @bannerResetCrop.
  ///
  /// In en, this message translates to:
  /// **'Reset crop'**
  String get bannerResetCrop;

  /// No description provided for @bannerRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Use color instead'**
  String get bannerRemoveImage;

  /// No description provided for @bannerGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get bannerGradient;

  /// No description provided for @bannerSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid color'**
  String get bannerSolid;

  /// No description provided for @bannerColorsBehindImage.
  ///
  /// In en, this message translates to:
  /// **'Colors show when no photo is used.'**
  String get bannerColorsBehindImage;

  /// No description provided for @bannerShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show title on banner'**
  String get bannerShowTitle;

  /// No description provided for @bannerPlacement.
  ///
  /// In en, this message translates to:
  /// **'Title placement'**
  String get bannerPlacement;

  /// No description provided for @placementTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get placementTopLeft;

  /// No description provided for @placementCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get placementCenter;

  /// No description provided for @placementBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get placementBottomLeft;

  /// No description provided for @placementBottomCenter.
  ///
  /// In en, this message translates to:
  /// **'Bottom center'**
  String get placementBottomCenter;

  /// No description provided for @bannerTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get bannerTextColor;

  /// No description provided for @bannerStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get bannerStyleClassic;

  /// No description provided for @bannerStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get bannerStyleMinimal;

  /// No description provided for @bannerStyleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bannerStyleBold;

  /// No description provided for @bannerStyleFramed.
  ///
  /// In en, this message translates to:
  /// **'Framed'**
  String get bannerStyleFramed;

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Add some to remember this trip.'**
  String get galleryEmpty;

  /// No description provided for @galleryFromDevice.
  ///
  /// In en, this message translates to:
  /// **'From device'**
  String get galleryFromDevice;

  /// No description provided for @photoCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get photoCaption;

  /// No description provided for @photoFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get photoFavorite;

  /// No description provided for @favoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get favoritesOnly;

  /// No description provided for @setAsCover.
  ///
  /// In en, this message translates to:
  /// **'Set as cover banner'**
  String get setAsCover;

  /// No description provided for @coverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cover banner updated'**
  String get coverUpdated;

  /// No description provided for @deletePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete photo?'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'The photo will be removed from this trip and from the device storage used by WanderPlan.'**
  String get deletePhotoBody;

  /// No description provided for @photoAccessError.
  ///
  /// In en, this message translates to:
  /// **'Could not access photos or camera. Check permissions in system Settings.'**
  String get photoAccessError;

  /// No description provided for @selectTripFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a trip from the Home tab first.'**
  String get selectTripFirst;

  /// No description provided for @goToTrips.
  ///
  /// In en, this message translates to:
  /// **'Go to My Trips'**
  String get goToTrips;

  /// No description provided for @currentTrip.
  ///
  /// In en, this message translates to:
  /// **'Current trip: {title}'**
  String currentTrip(String title);

  /// No description provided for @mapNotYet.
  ///
  /// In en, this message translates to:
  /// **'The real-world map, place search and route display are planned for Phase 3 and are not implemented yet.'**
  String get mapNotYet;

  /// No description provided for @timelineNotYet.
  ///
  /// In en, this message translates to:
  /// **'The morning-to-night daily timeline is planned for Phase 2 and is not implemented yet.'**
  String get timelineNotYet;

  /// No description provided for @budgetNotYet.
  ///
  /// In en, this message translates to:
  /// **'Expense tracking and budget analysis are planned for Phase 2 and are not implemented yet.'**
  String get budgetNotYet;

  /// No description provided for @moreFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get moreFlights;

  /// No description provided for @moreTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get moreTransportation;

  /// No description provided for @moreHotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get moreHotels;

  /// No description provided for @moreAttractions.
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get moreAttractions;

  /// No description provided for @moreScenarios.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get moreScenarios;

  /// No description provided for @moreGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get moreGallery;

  /// No description provided for @moreJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get moreJournal;

  /// No description provided for @moreAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get moreAnalysis;

  /// No description provided for @moreImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get moreImportExport;

  /// No description provided for @moreSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSettings;

  /// No description provided for @noTripSelected.
  ///
  /// In en, this message translates to:
  /// **'No trip selected'**
  String get noTripSelected;

  /// No description provided for @todosTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you go'**
  String get todosTitle;

  /// No description provided for @todosShort.
  ///
  /// In en, this message translates to:
  /// **'To-dos'**
  String get todosShort;

  /// No description provided for @todosProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String todosProgress(int done, int total);

  /// No description provided for @todosEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on your list yet. Add tasks to finish before departure.'**
  String get todosEmpty;

  /// No description provided for @todosAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done — ready to go!'**
  String get todosAllDone;

  /// No description provided for @todosNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get todosNextUp;

  /// No description provided for @todoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get todoAdd;

  /// No description provided for @todoEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get todoEdit;

  /// No description provided for @todoTitleField.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get todoTitleField;

  /// No description provided for @todoNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get todoNotes;

  /// No description provided for @todoCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get todoCategory;

  /// No description provided for @todoDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get todoDueDate;

  /// No description provided for @todoNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get todoNoDueDate;

  /// No description provided for @todoDueIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Due today} =1{Due tomorrow} other{Due in {count} days}}'**
  String todoDueIn(int count);

  /// No description provided for @todoOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day overdue} other{{count} days overdue}}'**
  String todoOverdue(int count);

  /// No description provided for @todoAfterDeparture.
  ///
  /// In en, this message translates to:
  /// **'After departure'**
  String get todoAfterDeparture;

  /// No description provided for @todoHideDone.
  ///
  /// In en, this message translates to:
  /// **'Hide completed'**
  String get todoHideDone;

  /// No description provided for @todoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Add suggestions'**
  String get todoSuggestions;

  /// No description provided for @todoSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Common pre-trip tasks'**
  String get todoSuggestionsTitle;

  /// No description provided for @todoAddSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Add} other{Add {count}}}'**
  String todoAddSelected(int count);

  /// No description provided for @todoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get todoDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @todoCatDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get todoCatDocuments;

  /// No description provided for @todoCatBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get todoCatBookings;

  /// No description provided for @todoCatPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get todoCatPacking;

  /// No description provided for @todoCatHealth.
  ///
  /// In en, this message translates to:
  /// **'Health & insurance'**
  String get todoCatHealth;

  /// No description provided for @todoCatMoney.
  ///
  /// In en, this message translates to:
  /// **'Money & cards'**
  String get todoCatMoney;

  /// No description provided for @todoCatConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Phone & internet'**
  String get todoCatConnectivity;

  /// No description provided for @todoCatHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get todoCatHome;

  /// No description provided for @todoCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get todoCatOther;

  /// No description provided for @sugPassport.
  ///
  /// In en, this message translates to:
  /// **'Check passport / ID expiry date'**
  String get sugPassport;

  /// No description provided for @sugEntryRequirements.
  ///
  /// In en, this message translates to:
  /// **'Check visa and entry requirements'**
  String get sugEntryRequirements;

  /// No description provided for @sugInsurance.
  ///
  /// In en, this message translates to:
  /// **'Arrange travel insurance'**
  String get sugInsurance;

  /// No description provided for @sugMedication.
  ///
  /// In en, this message translates to:
  /// **'Pack medication and prescriptions'**
  String get sugMedication;

  /// No description provided for @sugConfirmStay.
  ///
  /// In en, this message translates to:
  /// **'Confirm accommodation bookings'**
  String get sugConfirmStay;

  /// No description provided for @sugCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Do online check-in for the flight'**
  String get sugCheckIn;

  /// No description provided for @sugAirportTransport.
  ///
  /// In en, this message translates to:
  /// **'Plan how to get to the airport or station'**
  String get sugAirportTransport;

  /// No description provided for @sugBankCards.
  ///
  /// In en, this message translates to:
  /// **'Check card fees and notify your bank'**
  String get sugBankCards;

  /// No description provided for @sugLocalCash.
  ///
  /// In en, this message translates to:
  /// **'Get some local currency'**
  String get sugLocalCash;

  /// No description provided for @sugSimCard.
  ///
  /// In en, this message translates to:
  /// **'Arrange SIM, eSIM or roaming'**
  String get sugSimCard;

  /// No description provided for @sugOfflineCopies.
  ///
  /// In en, this message translates to:
  /// **'Save offline copies of tickets and documents'**
  String get sugOfflineCopies;

  /// No description provided for @sugChargers.
  ///
  /// In en, this message translates to:
  /// **'Pack chargers and a travel adapter'**
  String get sugChargers;

  /// No description provided for @sugHomeArrangements.
  ///
  /// In en, this message translates to:
  /// **'Arrange pets, plants and mail'**
  String get sugHomeArrangements;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share with a friend'**
  String get shareTrip;

  /// No description provided for @shareExplain.
  ///
  /// In en, this message translates to:
  /// **'Your friend gets their own copy of this trip as a file. They open WanderPlan → My Trips → ⋮ → Import trip. Later changes are not synced between your copies.'**
  String get shareExplain;

  /// No description provided for @shareIncludePhotos.
  ///
  /// In en, this message translates to:
  /// **'Include gallery photos'**
  String get shareIncludePhotos;

  /// No description provided for @shareIncludePhotosHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos to include} =1{1 photo · makes the file larger} other{{count} photos · makes the file larger}}'**
  String shareIncludePhotosHelp(int count);

  /// No description provided for @shareSend.
  ///
  /// In en, this message translates to:
  /// **'Share file'**
  String get shareSend;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'My WanderPlan trip “{title}”. To add it: WanderPlan → My Trips → ⋮ → Import trip.'**
  String shareMessage(String title);

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the share file: {error}'**
  String shareFailed(String error);

  /// No description provided for @importTrip.
  ///
  /// In en, this message translates to:
  /// **'Import trip'**
  String get importTrip;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported “{title}”'**
  String importSuccess(String title);

  /// No description provided for @importInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a WanderPlan trip file.'**
  String get importInvalid;

  /// No description provided for @importTooNew.
  ///
  /// In en, this message translates to:
  /// **'This file was made by a newer version of WanderPlan. Update the app to import it.'**
  String get importTooNew;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Where to next?} =1{1 trip in your collection} other{{count} trips in your collection}}'**
  String homeSubtitle(int count);

  /// No description provided for @kpiDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get kpiDuration;

  /// No description provided for @kpiStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get kpiStatus;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @tripTools.
  ///
  /// In en, this message translates to:
  /// **'Trip tools'**
  String get tripTools;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @addActivity.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get addActivity;

  /// No description provided for @editActivity.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivity;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get activityTitle;

  /// No description provided for @activityKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get activityKind;

  /// No description provided for @kindSightseeing.
  ///
  /// In en, this message translates to:
  /// **'Sightseeing'**
  String get kindSightseeing;

  /// No description provided for @kindFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get kindFood;

  /// No description provided for @kindActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get kindActivity;

  /// No description provided for @kindShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get kindShopping;

  /// No description provided for @kindRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get kindRest;

  /// No description provided for @kindFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get kindFlight;

  /// No description provided for @kindTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get kindTrain;

  /// No description provided for @kindBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get kindBus;

  /// No description provided for @kindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Taxi / metro'**
  String get kindTransfer;

  /// No description provided for @kindFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get kindFerry;

  /// No description provided for @kindHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get kindHotel;

  /// No description provided for @kindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kindOther;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get fieldStart;

  /// No description provided for @fieldEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get fieldEnd;

  /// No description provided for @fieldEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get fieldEndDate;

  /// No description provided for @fieldCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get fieldCheckIn;

  /// No description provided for @fieldCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get fieldCheckOut;

  /// No description provided for @sameDay.
  ///
  /// In en, this message translates to:
  /// **'Same day'**
  String get sameDay;

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLocation;

  /// No description provided for @fieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get fieldTo;

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// No description provided for @onMap.
  ///
  /// In en, this message translates to:
  /// **'On the map'**
  String get onMap;

  /// No description provided for @notOnMap.
  ///
  /// In en, this message translates to:
  /// **'Not on the map yet'**
  String get notOnMap;

  /// No description provided for @fieldCost.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost'**
  String get fieldCost;

  /// No description provided for @fieldBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get fieldBooking;

  /// No description provided for @bookingNotBooked.
  ///
  /// In en, this message translates to:
  /// **'Not booked'**
  String get bookingNotBooked;

  /// No description provided for @bookingBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get bookingBooked;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bookingConfirmed;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingCancelled;

  /// No description provided for @fieldProvider.
  ///
  /// In en, this message translates to:
  /// **'Airline / operator / hotel'**
  String get fieldProvider;

  /// No description provided for @fieldServiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight / train number'**
  String get fieldServiceNumber;

  /// No description provided for @fieldBookingRef.
  ///
  /// In en, this message translates to:
  /// **'Booking reference (private)'**
  String get fieldBookingRef;

  /// No description provided for @fieldBookingUrl.
  ///
  /// In en, this message translates to:
  /// **'Booking link'**
  String get fieldBookingUrl;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @fieldLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get fieldLocked;

  /// No description provided for @lockedHelp.
  ///
  /// In en, this message translates to:
  /// **'Locked items are confirmed bookings and are never moved by dragging.'**
  String get lockedHelp;

  /// No description provided for @fieldOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fieldOptional;

  /// No description provided for @optionalHelp.
  ///
  /// In en, this message translates to:
  /// **'Nice to have; can be skipped if time is short.'**
  String get optionalHelp;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get endBeforeStart;

  /// No description provided for @deleteActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete activity?'**
  String get deleteActivityTitle;

  /// No description provided for @activityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity deleted'**
  String get activityDeleted;

  /// No description provided for @duplicateToNextDay.
  ///
  /// In en, this message translates to:
  /// **'Copy to next day'**
  String get duplicateToNextDay;

  /// No description provided for @lockedCannotMove.
  ///
  /// In en, this message translates to:
  /// **'Locked activities can\'t be moved. Unlock it first.'**
  String get lockedCannotMove;

  /// No description provided for @timelineEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for this day yet.'**
  String get timelineEmptyDay;

  /// No description provided for @timelineNoDays.
  ///
  /// In en, this message translates to:
  /// **'Set trip dates or add an activity to start planning day by day.'**
  String get timelineNoDays;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Time grid'**
  String get viewGrid;

  /// No description provided for @dragHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a block and drag to move it · drag its bottom edge to change the duration'**
  String get dragHint;

  /// No description provided for @freeTime.
  ///
  /// In en, this message translates to:
  /// **'{duration} free'**
  String freeTime(String duration);

  /// No description provided for @durationHm.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String durationHm(int h, int m);

  /// No description provided for @durationH.
  ///
  /// In en, this message translates to:
  /// **'{h} h'**
  String durationH(int h);

  /// No description provided for @durationM.
  ///
  /// In en, this message translates to:
  /// **'{m} min'**
  String durationM(int m);

  /// No description provided for @nightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night} other{{count} nights}}'**
  String nightsCount(int count);

  /// No description provided for @dayN.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String dayN(int n);

  /// No description provided for @outsideTrip.
  ///
  /// In en, this message translates to:
  /// **'Outside trip'**
  String get outsideTrip;

  /// No description provided for @dayFeasible.
  ///
  /// In en, this message translates to:
  /// **'Feasible'**
  String get dayFeasible;

  /// No description provided for @dayTight.
  ///
  /// In en, this message translates to:
  /// **'Tight'**
  String get dayTight;

  /// No description provided for @dayUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'Unrealistic'**
  String get dayUnrealistic;

  /// No description provided for @dayUnknown.
  ///
  /// In en, this message translates to:
  /// **'Needs info'**
  String get dayUnknown;

  /// No description provided for @dayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Free day'**
  String get dayEmpty;

  /// No description provided for @issueOverlap.
  ///
  /// In en, this message translates to:
  /// **'“{a}” overlaps “{b}” by {minutes} min'**
  String issueOverlap(String a, String b, int minutes);

  /// No description provided for @issueNoTravelTime.
  ///
  /// In en, this message translates to:
  /// **'No time to get from “{a}” to “{b}”'**
  String issueNoTravelTime(String a, String b);

  /// No description provided for @issueTightTravel.
  ///
  /// In en, this message translates to:
  /// **'“{a}” → “{b}” are {km} km apart in a straight line but only {minutes} min is free; allow about {needed} min'**
  String issueTightTravel(
    String a,
    String b,
    String km,
    int minutes,
    int needed,
  );

  /// No description provided for @issueDepartureBuffer.
  ///
  /// In en, this message translates to:
  /// **'Only {minutes} min before “{b}”; allow at least {needed} min to get there and check in'**
  String issueDepartureBuffer(String b, int minutes, int needed);

  /// No description provided for @issueLongDay.
  ///
  /// In en, this message translates to:
  /// **'Very full day: {hours} h of activities'**
  String issueLongDay(String hours);

  /// No description provided for @issueEarlyAndLate.
  ///
  /// In en, this message translates to:
  /// **'Early start and late finish ({hours} h day)'**
  String issueEarlyAndLate(String hours);

  /// No description provided for @issueNoMealBreak.
  ///
  /// In en, this message translates to:
  /// **'No meal or rest break around lunch'**
  String get issueNoMealBreak;

  /// No description provided for @issueLateFinish.
  ///
  /// In en, this message translates to:
  /// **'Ends after 23:00'**
  String get issueLateFinish;

  /// No description provided for @issueMissingAccommodation.
  ///
  /// In en, this message translates to:
  /// **'No accommodation planned for this night'**
  String get issueMissingAccommodation;

  /// No description provided for @issueOverlappingStays.
  ///
  /// In en, this message translates to:
  /// **'Two stays on the same night: {titles}'**
  String issueOverlappingStays(String titles);

  /// No description provided for @issueTransportNotBooked.
  ///
  /// In en, this message translates to:
  /// **'Not booked yet: {titles}'**
  String issueTransportNotBooked(String titles);

  /// No description provided for @issueOutsideTripDates.
  ///
  /// In en, this message translates to:
  /// **'Outside the trip dates: {titles}'**
  String issueOutsideTripDates(String titles);

  /// No description provided for @feasibilityNote.
  ///
  /// In en, this message translates to:
  /// **'Checks use rules of thumb (straight-line distance at about 25 km/h, 2 h before flights, 30 min before trains). They are estimates, not live routes.'**
  String get feasibilityNote;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookingsTitle;

  /// No description provided for @bookingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No flights, trains or hotels yet.'**
  String get bookingsEmpty;

  /// No description provided for @bookingsTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get bookingsTransport;

  /// No description provided for @bookingsStays.
  ///
  /// In en, this message translates to:
  /// **'Stays'**
  String get bookingsStays;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @planCheck.
  ///
  /// In en, this message translates to:
  /// **'Plan check'**
  String get planCheck;

  /// No description provided for @daysNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day needs attention} other{{count} days need attention}}'**
  String daysNeedAttention(int count);

  /// No description provided for @allDaysOk.
  ///
  /// In en, this message translates to:
  /// **'All planned days look feasible'**
  String get allDaysOk;

  /// No description provided for @noActivitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No activities planned yet'**
  String get noActivitiesYet;

  /// No description provided for @activitiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 activity} other{{count} activities}}'**
  String activitiesCount(int count);

  /// No description provided for @mapAllDays.
  ///
  /// In en, this message translates to:
  /// **'All days'**
  String get mapAllDays;

  /// No description provided for @mapNoPins.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 activity has no location yet} other{{count} activities have no location yet}}'**
  String mapNoPins(int count);

  /// No description provided for @mapOnlineNote.
  ///
  /// In en, this message translates to:
  /// **'Map tiles and place search need an internet connection.'**
  String get mapOnlineNote;

  /// No description provided for @mapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the map yet. Search for a place, explore nearby, or edit an activity and use “Pick on map”.'**
  String get mapEmpty;

  /// No description provided for @fitAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get fitAll;

  /// No description provided for @placeAttraction.
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get placeAttraction;

  /// No description provided for @placeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get placeRestaurant;

  /// No description provided for @placeHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get placeHotel;

  /// No description provided for @placeAirport.
  ///
  /// In en, this message translates to:
  /// **'Airports'**
  String get placeAirport;

  /// No description provided for @placeRailwayStation.
  ///
  /// In en, this message translates to:
  /// **'Railway stations'**
  String get placeRailwayStation;

  /// No description provided for @placeBusStation.
  ///
  /// In en, this message translates to:
  /// **'Bus stations'**
  String get placeBusStation;

  /// No description provided for @placeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get placeOther;

  /// No description provided for @modeWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get modeWalking;

  /// No description provided for @modeCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get modeCycling;

  /// No description provided for @modeDriving.
  ///
  /// In en, this message translates to:
  /// **'Driving / taxi'**
  String get modeDriving;

  /// No description provided for @mapProvider.
  ///
  /// In en, this message translates to:
  /// **'Map provider'**
  String get mapProvider;

  /// No description provided for @providerAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get providerAuto;

  /// No description provided for @providerAutoHelp.
  ///
  /// In en, this message translates to:
  /// **'Amap in mainland China, OpenStreetMap elsewhere'**
  String get providerAutoHelp;

  /// No description provided for @providerOsm.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get providerOsm;

  /// No description provided for @providerAmap.
  ///
  /// In en, this message translates to:
  /// **'Amap (Gaode)'**
  String get providerAmap;

  /// No description provided for @amapNoKey.
  ///
  /// In en, this message translates to:
  /// **'Amap search and routes need an Amap key, so OpenStreetMap search and routes are used.'**
  String get amapNoKey;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get savedPlaces;

  /// No description provided for @savedPlacesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Search, explore nearby, or long-press the map to pin one.'**
  String get savedPlacesEmpty;

  /// No description provided for @savePlace.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get savePlace;

  /// No description provided for @removePlace.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePlace;

  /// No description provided for @placeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to this trip'**
  String get placeSaved;

  /// No description provided for @placeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Place removed'**
  String get placeRemoved;

  /// No description provided for @addToDay.
  ///
  /// In en, this message translates to:
  /// **'Add to day'**
  String get addToDay;

  /// No description provided for @chooseDay.
  ///
  /// In en, this message translates to:
  /// **'Choose a day'**
  String get chooseDay;

  /// No description provided for @addedToDay.
  ///
  /// In en, this message translates to:
  /// **'Added to {date} · time not set'**
  String addedToDay(String date);

  /// No description provided for @plannedOn.
  ///
  /// In en, this message translates to:
  /// **'In the plan: {dates}'**
  String plannedOn(String dates);

  /// No description provided for @notPlanned.
  ///
  /// In en, this message translates to:
  /// **'Not in the plan yet'**
  String get notPlanned;

  /// No description provided for @sourceSearch.
  ///
  /// In en, this message translates to:
  /// **'Coordinates from {provider} search'**
  String sourceSearch(String provider);

  /// No description provided for @sourcePinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned on the map by you'**
  String get sourcePinned;

  /// No description provided for @sourceImported.
  ///
  /// In en, this message translates to:
  /// **'Coordinates imported'**
  String get sourceImported;

  /// No description provided for @mapPinnedPlace.
  ///
  /// In en, this message translates to:
  /// **'Pinned place'**
  String get mapPinnedPlace;

  /// No description provided for @mapLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press to pin a place'**
  String get mapLongPressHint;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found around this area'**
  String get nearbyEmpty;

  /// No description provided for @filterMarkers.
  ///
  /// In en, this message translates to:
  /// **'Filter markers'**
  String get filterMarkers;

  /// No description provided for @layerPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get layerPlan;

  /// No description provided for @layerResults.
  ///
  /// In en, this message translates to:
  /// **'Search & nearby results'**
  String get layerResults;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off'**
  String get locationOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Allow it in system settings.'**
  String get locationDeniedForever;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location'**
  String get locationUnavailable;

  /// No description provided for @routeLoading.
  ///
  /// In en, this message translates to:
  /// **'Finding routes…'**
  String get routeLoading;

  /// No description provided for @routeTotal.
  ///
  /// In en, this message translates to:
  /// **'{distance} · about {duration}'**
  String routeTotal(String distance, String duration);

  /// No description provided for @routeEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Road routes: {provider}. Times are typical estimates, not live traffic or timetables.'**
  String routeEstimateNote(String provider);

  /// No description provided for @routeUnverified.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 leg has no road route: straight line, unverified} other{{count} legs have no road route: straight lines, unverified}}'**
  String routeUnverified(int count);

  /// No description provided for @routeBooked.
  ///
  /// In en, this message translates to:
  /// **'Flights, trains and ferries are drawn as direct dotted lines, not their actual path.'**
  String get routeBooked;

  /// No description provided for @routeNoTransit.
  ///
  /// In en, this message translates to:
  /// **'Public transport routing isn’t available here; use “Navigate with” for transit directions.'**
  String get routeNoTransit;

  /// No description provided for @routeUnordered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop has no time yet, so it isn’t in the route} other{{count} stops have no time yet, so they aren’t in the route}}'**
  String routeUnordered(int count);

  /// No description provided for @findLocations.
  ///
  /// In en, this message translates to:
  /// **'Find locations'**
  String get findLocations;

  /// No description provided for @locateTitle.
  ///
  /// In en, this message translates to:
  /// **'Find locations'**
  String get locateTitle;

  /// No description provided for @locateIntro.
  ///
  /// In en, this message translates to:
  /// **'These places have a name but no coordinates, so they can’t be shown on the map. Each name is searched online and matches near your trip’s destinations come first. Nothing changes until you choose a match.'**
  String get locateIntro;

  /// No description provided for @locateProgress.
  ///
  /// In en, this message translates to:
  /// **'Searched {done} of {total}…'**
  String locateProgress(int done, int total);

  /// No description provided for @locateUsedBy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Used by 1 activity} other{Used by {count} activities}}'**
  String locateUsedBy(int count);

  /// No description provided for @locatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'General name: choose the exact place yourself'**
  String get locatePlaceholder;

  /// No description provided for @locateNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No match for “{query}”. Try another name or pick it on the map.'**
  String locateNoMatch(String query);

  /// No description provided for @locateFar.
  ///
  /// In en, this message translates to:
  /// **'{km} km from your destinations'**
  String locateFar(int km);

  /// No description provided for @locateUse.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get locateUse;

  /// No description provided for @locateLocated.
  ///
  /// In en, this message translates to:
  /// **'Located'**
  String get locateLocated;

  /// No description provided for @locateSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get locateSearchAgain;

  /// No description provided for @locateSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get locateSearch;

  /// No description provided for @locateRefineHelp.
  ///
  /// In en, this message translates to:
  /// **'Tip: add the city, e.g. “中山路步行街 厦门”'**
  String get locateRefineHelp;

  /// No description provided for @locateUseAll.
  ///
  /// In en, this message translates to:
  /// **'Use selected matches ({count})'**
  String locateUseAll(int count);

  /// No description provided for @locateAllDone.
  ///
  /// In en, this message translates to:
  /// **'Every place in the plan has coordinates.'**
  String get locateAllDone;

  /// No description provided for @pasteLocation.
  ///
  /// In en, this message translates to:
  /// **'Paste a link or coordinates'**
  String get pasteLocation;

  /// No description provided for @pasteLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link, share link (maps.app.goo.gl), embed code, “27.8124, 99.7048” or a Plus Code like “RP63+XW2, Shangri-La”'**
  String get pasteLocationHint;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @pasteFromChineseMap.
  ///
  /// In en, this message translates to:
  /// **'Copied from Google Maps, Amap or Apple Maps'**
  String get pasteFromChineseMap;

  /// No description provided for @pasteFromChineseMapHelp.
  ///
  /// In en, this message translates to:
  /// **'In mainland China these maps are offset from GPS; WanderPlan corrects it. Turn off for GPS or OpenStreetMap coordinates.'**
  String get pasteFromChineseMapHelp;

  /// No description provided for @pasteResolve.
  ///
  /// In en, this message translates to:
  /// **'Use location'**
  String get pasteResolve;

  /// No description provided for @linkUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'Not recognised. Paste a Google Maps / Amap / Apple Maps link, coordinates like “27.81, 99.70”, or a Plus Code.'**
  String get linkUnrecognized;

  /// No description provided for @linkShortFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the short link (are you online?). Open it in Google Maps and copy the full link or coordinates instead.'**
  String get linkShortFailed;

  /// No description provided for @linkPlusNeedsArea.
  ///
  /// In en, this message translates to:
  /// **'This short Plus Code needs its area, e.g. “RP63+XW2, Shangri-La”.'**
  String get linkPlusNeedsArea;

  /// No description provided for @linkCentreOnly.
  ///
  /// In en, this message translates to:
  /// **'This link only gives the map’s centre, so the pin may be slightly off. Check it.'**
  String get linkCentreOnly;

  /// No description provided for @linkConverted.
  ///
  /// In en, this message translates to:
  /// **'Converted from China’s map offset (GCJ-02) to GPS coordinates.'**
  String get linkConverted;

  /// No description provided for @sourceLink.
  ///
  /// In en, this message translates to:
  /// **'Coordinates from a {provider} link'**
  String sourceLink(String provider);

  /// No description provided for @sourcePlusCode.
  ///
  /// In en, this message translates to:
  /// **'Coordinates from a Plus Code'**
  String get sourcePlusCode;

  /// No description provided for @sourceCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates entered by you'**
  String get sourceCoordinates;

  /// No description provided for @pasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste link'**
  String get pasteLink;

  /// No description provided for @modeTransit.
  ///
  /// In en, this message translates to:
  /// **'Train / metro / bus'**
  String get modeTransit;

  /// No description provided for @dayStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dayStart;

  /// No description provided for @dayEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get dayEnd;

  /// No description provided for @dayStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Where does this day start?'**
  String get dayStartTitle;

  /// No description provided for @dayEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Where does this day end?'**
  String get dayEndTitle;

  /// No description provided for @dayAnchorNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set (no hotel that night)'**
  String get dayAnchorNotSet;

  /// No description provided for @dayAnchorHotel.
  ///
  /// In en, this message translates to:
  /// **'hotel'**
  String get dayAnchorHotel;

  /// No description provided for @dayAnchorUseHotel.
  ///
  /// In en, this message translates to:
  /// **'Use the hotel (default)'**
  String get dayAnchorUseHotel;

  /// No description provided for @dayLegs.
  ///
  /// In en, this message translates to:
  /// **'Getting between stops'**
  String get dayLegs;

  /// No description provided for @legTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you get there?'**
  String get legTitle;

  /// No description provided for @legDefault.
  ///
  /// In en, this message translates to:
  /// **'Day default ({mode})'**
  String legDefault(String mode);

  /// No description provided for @legMinutes.
  ///
  /// In en, this message translates to:
  /// **'Your travel time (optional)'**
  String get legMinutes;

  /// No description provided for @legMinutesHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the route’s typical time.'**
  String get legMinutesHelp;

  /// No description provided for @legTransitHelp.
  ///
  /// In en, this message translates to:
  /// **'Train, metro and bus times aren’t calculated (no timetable data). Enter the time from the timetable or a map app.'**
  String get legTransitHelp;

  /// No description provided for @legTransitNoTime.
  ///
  /// In en, this message translates to:
  /// **'Train/metro/bus · enter your time'**
  String get legTransitNoTime;

  /// No description provided for @legUndecided.
  ///
  /// In en, this message translates to:
  /// **'Transport not decided yet'**
  String get legUndecided;

  /// No description provided for @legNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No route (unverified)'**
  String get legNoRoute;

  /// No description provided for @legYourEstimate.
  ///
  /// In en, this message translates to:
  /// **'your estimate'**
  String get legYourEstimate;

  /// No description provided for @legTooShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min short before the next start'**
  String legTooShort(int minutes);

  /// No description provided for @routeTransitNote.
  ///
  /// In en, this message translates to:
  /// **'Dashed blue lines are train/metro/bus legs: straight lines with your own times.'**
  String get routeTransitNote;

  /// No description provided for @optimizeOrder.
  ///
  /// In en, this message translates to:
  /// **'Optimize order'**
  String get optimizeOrder;

  /// No description provided for @optimizeNeedsTwo.
  ///
  /// In en, this message translates to:
  /// **'Needs at least 2 places with a location that aren’t locked or booked.'**
  String get optimizeNeedsTwo;

  /// No description provided for @optimizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested order'**
  String get optimizeTitle;

  /// No description provided for @optimizeSaves.
  ///
  /// In en, this message translates to:
  /// **'Travel {before} → {after} (saves {saved})'**
  String optimizeSaves(String before, String after, String saved);

  /// No description provided for @optimizeAlreadyBest.
  ///
  /// In en, this message translates to:
  /// **'Your order is already the shortest ({travel} of travel).'**
  String optimizeAlreadyBest(String travel);

  /// No description provided for @optimizeRouted.
  ///
  /// In en, this message translates to:
  /// **'Based on {mode} routes; typical times, not live traffic.'**
  String optimizeRouted(String mode);

  /// No description provided for @optimizeEstimated.
  ///
  /// In en, this message translates to:
  /// **'No route data: estimated from straight-line distance for {mode}.'**
  String optimizeEstimated(String mode);

  /// No description provided for @optimizeDayStart.
  ///
  /// In en, this message translates to:
  /// **'Day starts at'**
  String get optimizeDayStart;

  /// No description provided for @optimizeTravel.
  ///
  /// In en, this message translates to:
  /// **'{time} travel'**
  String optimizeTravel(String time);

  /// No description provided for @optimizeWait.
  ///
  /// In en, this message translates to:
  /// **'wait {time} for opening'**
  String optimizeWait(String time);

  /// No description provided for @optimizeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get optimizeFixed;

  /// No description provided for @optimizeAssumed.
  ///
  /// In en, this message translates to:
  /// **'No time set: 1 h assumed'**
  String get optimizeAssumed;

  /// No description provided for @optimizeClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed that day'**
  String get optimizeClosed;

  /// No description provided for @optimizeOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'Outside opening hours'**
  String get optimizeOutsideHours;

  /// No description provided for @optimizeLate.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min late'**
  String optimizeLate(int minutes);

  /// No description provided for @optimizeKeepsFixed.
  ///
  /// In en, this message translates to:
  /// **'Locked, booked and transport items keep their times. Only places you haven’t booked are moved.'**
  String get optimizeKeepsFixed;

  /// No description provided for @optimizeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get optimizeApply;

  /// No description provided for @optimizeApplied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 activity} other{Updated {count} activities}}'**
  String optimizeApplied(int count);

  /// No description provided for @gettingHere.
  ///
  /// In en, this message translates to:
  /// **'Getting here'**
  String get gettingHere;

  /// No description provided for @gettingHereDefault.
  ///
  /// In en, this message translates to:
  /// **'Day default'**
  String get gettingHereDefault;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @openingHoursKnown.
  ///
  /// In en, this message translates to:
  /// **'Has opening hours'**
  String get openingHoursKnown;

  /// No description provided for @openingHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'Check the official site; WanderPlan uses them to warn and to plan the order.'**
  String get openingHoursHelp;

  /// No description provided for @opens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get opens;

  /// No description provided for @closes.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get closes;

  /// No description provided for @closesNextDay.
  ///
  /// In en, this message translates to:
  /// **'closes after midnight'**
  String get closesNextDay;

  /// No description provided for @closedOn.
  ///
  /// In en, this message translates to:
  /// **'Closed on'**
  String get closedOn;

  /// No description provided for @closedThatDay.
  ///
  /// In en, this message translates to:
  /// **'Closed on this day!'**
  String get closedThatDay;

  /// No description provided for @reservation.
  ///
  /// In en, this message translates to:
  /// **'Reservation'**
  String get reservation;

  /// No description provided for @reservationRequired.
  ///
  /// In en, this message translates to:
  /// **'Needs a reservation or ticket in advance'**
  String get reservationRequired;

  /// No description provided for @reservationVia.
  ///
  /// In en, this message translates to:
  /// **'Where / how to book'**
  String get reservationVia;

  /// No description provided for @reservationViaHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. official WeChat account, Trip.com app, website'**
  String get reservationViaHint;

  /// No description provided for @bookAheadDays.
  ///
  /// In en, this message translates to:
  /// **'Book how many days before?'**
  String get bookAheadDays;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysUnit;

  /// No description provided for @bookByDate.
  ///
  /// In en, this message translates to:
  /// **'Book by {date}'**
  String bookByDate(String date);

  /// No description provided for @remindToBook.
  ///
  /// In en, this message translates to:
  /// **'Remind me on that day'**
  String get remindToBook;

  /// No description provided for @remindToBookHelp.
  ///
  /// In en, this message translates to:
  /// **'A notification at 09:00 (trip time) on the book-by date.'**
  String get remindToBookHelp;

  /// No description provided for @remindPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for WanderPlan. Allow them in system settings to get reminders.'**
  String get remindPermissionDenied;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to book'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Book “{title}” for {date}. {via}'**
  String reminderBody(String title, String date, String via);

  /// No description provided for @issueTightTravelOwn.
  ///
  /// In en, this message translates to:
  /// **'“{a}” → “{b}”: only {minutes} min, but you allowed {needed} min to get there'**
  String issueTightTravelOwn(String a, String b, int minutes, int needed);

  /// No description provided for @issueClosedOnDay.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is closed on this day'**
  String issueClosedOnDay(String title);

  /// No description provided for @issueOutsideOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is planned outside its opening hours'**
  String issueOutsideOpeningHours(String title);

  /// No description provided for @issueBookingNeeded.
  ///
  /// In en, this message translates to:
  /// **'“{title}” still needs a reservation'**
  String issueBookingNeeded(String title);

  /// No description provided for @issueBookBy.
  ///
  /// In en, this message translates to:
  /// **'Book “{title}” by {date}'**
  String issueBookBy(String title, String date);

  /// No description provided for @flightUpdates.
  ///
  /// In en, this message translates to:
  /// **'Flight updates'**
  String get flightUpdates;

  /// No description provided for @flightUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live status from your WanderPlan server'**
  String get flightUpdatesSubtitle;

  /// No description provided for @flightPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get flightPrivacyTitle;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @flightUpdatesOff.
  ///
  /// In en, this message translates to:
  /// **'Not working right now'**
  String get flightUpdatesOff;

  /// No description provided for @flightServerChecking.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get flightServerChecking;

  /// No description provided for @flightServerIntro.
  ///
  /// In en, this message translates to:
  /// **'Live flight status comes from the WanderPlan server. It checks each flight once for everyone and holds the flight-data key; this phone only reads the results. Nothing to set up.'**
  String get flightServerIntro;

  /// No description provided for @flightServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get flightServerTitle;

  /// No description provided for @flightServerConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'On · signed in as {who}'**
  String flightServerConnectedAs(String who);

  /// No description provided for @flightServerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'No flight-data API key is stored on this phone. The app signs in to the WanderPlan server by itself and keeps that sign-in in the keychain (this device only).'**
  String get flightServerPrivacy;

  /// No description provided for @flightNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Live flight updates aren’t available in this version of the app.'**
  String get flightNotConnected;

  /// No description provided for @flightSignInRejected.
  ///
  /// In en, this message translates to:
  /// **'The WanderPlan server didn’t accept the sign-in. Try again later.'**
  String get flightSignInRejected;

  /// No description provided for @flightServerNoKey.
  ///
  /// In en, this message translates to:
  /// **'Live flight data isn’t switched on at the WanderPlan server yet.'**
  String get flightServerNoKey;

  /// No description provided for @flightNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet. Your server checks this flight on its schedule (live data appears around the flight day).'**
  String get flightNoDataYet;

  /// No description provided for @flightStale.
  ///
  /// In en, this message translates to:
  /// **'Last check failed; showing the last known data'**
  String get flightStale;

  /// No description provided for @flightNeedsNumber.
  ///
  /// In en, this message translates to:
  /// **'Add the flight number (e.g. MU5103) to get live updates.'**
  String get flightNeedsNumber;

  /// No description provided for @flightCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get flightCheckNow;

  /// No description provided for @flightNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes since the last check'**
  String get flightNoChanges;

  /// No description provided for @flightQuotaReached.
  ///
  /// In en, this message translates to:
  /// **'Your server’s flight-data plan is out of requests this month.'**
  String get flightQuotaReached;

  /// No description provided for @flightNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can’t reach the WanderPlan server right now. Check your internet connection and try again.'**
  String get flightNetwork;

  /// No description provided for @flightUnknownError.
  ///
  /// In en, this message translates to:
  /// **'The server didn’t answer as expected. Try again later.'**
  String get flightUnknownError;

  /// No description provided for @flightScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get flightScheduled;

  /// No description provided for @flightInAir.
  ///
  /// In en, this message translates to:
  /// **'In the air'**
  String get flightInAir;

  /// No description provided for @flightLanded.
  ///
  /// In en, this message translates to:
  /// **'Landed'**
  String get flightLanded;

  /// No description provided for @flightCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get flightCancelled;

  /// No description provided for @flightIncident.
  ///
  /// In en, this message translates to:
  /// **'Incident'**
  String get flightIncident;

  /// No description provided for @flightDiverted.
  ///
  /// In en, this message translates to:
  /// **'Diverted'**
  String get flightDiverted;

  /// No description provided for @flightStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get flightStatusUnknown;

  /// No description provided for @flightDelayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed {minutes} min'**
  String flightDelayed(int minutes);

  /// No description provided for @flightDep.
  ///
  /// In en, this message translates to:
  /// **'Dep'**
  String get flightDep;

  /// No description provided for @flightArr.
  ///
  /// In en, this message translates to:
  /// **'Arr'**
  String get flightArr;

  /// No description provided for @flightTerminal.
  ///
  /// In en, this message translates to:
  /// **'T{t}'**
  String flightTerminal(String t);

  /// No description provided for @flightGate.
  ///
  /// In en, this message translates to:
  /// **'Gate {g}'**
  String flightGate(String g);

  /// No description provided for @flightBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt {b}'**
  String flightBelt(String b);

  /// No description provided for @flightChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked {time} · times are local at each airport'**
  String flightChecked(String time);

  /// No description provided for @flightNotifyTitle.
  ///
  /// In en, this message translates to:
  /// **'{flight}: flight update'**
  String flightNotifyTitle(String flight);

  /// No description provided for @flightChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Now {status}'**
  String flightChangeStatus(String status);

  /// No description provided for @flightChangeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure {from} → {to}'**
  String flightChangeDeparture(String from, String to);

  /// No description provided for @flightChangeArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival {from} → {to}'**
  String flightChangeArrival(String from, String to);

  /// No description provided for @flightChangeDepTerminal.
  ///
  /// In en, this message translates to:
  /// **'Departure terminal {t}'**
  String flightChangeDepTerminal(String t);

  /// No description provided for @flightChangeDepGate.
  ///
  /// In en, this message translates to:
  /// **'Gate {g}'**
  String flightChangeDepGate(String g);

  /// No description provided for @flightChangeArrTerminal.
  ///
  /// In en, this message translates to:
  /// **'Arrival terminal {t}'**
  String flightChangeArrTerminal(String t);

  /// No description provided for @flightChangeArrGate.
  ///
  /// In en, this message translates to:
  /// **'Arrival gate {g}'**
  String flightChangeArrGate(String g);

  /// No description provided for @flightChangeBaggage.
  ///
  /// In en, this message translates to:
  /// **'Baggage belt {b}'**
  String flightChangeBaggage(String b);

  /// No description provided for @navigateWith.
  ///
  /// In en, this message translates to:
  /// **'Navigate with'**
  String get navigateWith;

  /// No description provided for @openGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get openGoogleMaps;

  /// No description provided for @openAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Apple Maps'**
  String get openAppleMaps;

  /// No description provided for @openAmap.
  ///
  /// In en, this message translates to:
  /// **'Amap (Gaode)'**
  String get openAmap;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the maps app'**
  String get openFailed;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get chooseLocation;

  /// No description provided for @pickHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to drop a pin, or search for a place.'**
  String get pickHint;

  /// No description provided for @useThisPlace.
  ///
  /// In en, this message translates to:
  /// **'Use this place'**
  String get useThisPlace;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search places (online)'**
  String get searchPlaces;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search unavailable: {error}'**
  String searchFailed(String error);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get noResults;

  /// No description provided for @placeName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get placeName;

  /// No description provided for @removePin.
  ///
  /// In en, this message translates to:
  /// **'Remove pin'**
  String get removePin;

  /// No description provided for @budgetPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get budgetPlanned;

  /// No description provided for @budgetSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budgetSpent;

  /// No description provided for @budgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get budgetRemaining;

  /// No description provided for @budgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLimit;

  /// No description provided for @budgetOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get budgetOverview;

  /// No description provided for @budgetExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get budgetExpenses;

  /// No description provided for @budgetRates.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get budgetRates;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get byCategory;

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get byDay;

  /// No description provided for @plannedVsActual.
  ///
  /// In en, this message translates to:
  /// **'Planned vs actual'**
  String get plannedVsActual;

  /// No description provided for @variance.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get variance;

  /// No description provided for @perPersonSpent.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent per person'**
  String perPersonSpent(String amount);

  /// No description provided for @unpaidPlanned.
  ///
  /// In en, this message translates to:
  /// **'{amount} still to pay or book'**
  String unpaidPlanned(String amount);

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @expenseTitle.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get expenseTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @expensePlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get expensePlanned;

  /// No description provided for @expenseActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get expenseActual;

  /// No description provided for @expensePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get expensePaid;

  /// No description provided for @expenseUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get expenseUnpaid;

  /// No description provided for @expenseShared.
  ///
  /// In en, this message translates to:
  /// **'Shared by all travelers'**
  String get expenseShared;

  /// No description provided for @linkedActivity.
  ///
  /// In en, this message translates to:
  /// **'Linked activity'**
  String get linkedActivity;

  /// No description provided for @noneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOption;

  /// No description provided for @expenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted'**
  String get expenseDeleted;

  /// No description provided for @noExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet. Add what you spend during the trip, or planned costs that aren’t in the itinerary.'**
  String get noExpenses;

  /// No description provided for @fromItinerary.
  ///
  /// In en, this message translates to:
  /// **'From itinerary'**
  String get fromItinerary;

  /// No description provided for @budgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add costs to activities or planned expenses to see your plan here.'**
  String get budgetEmpty;

  /// No description provided for @warnNoCurrency.
  ///
  /// In en, this message translates to:
  /// **'Set a primary currency for this trip to track the budget.'**
  String get warnNoCurrency;

  /// No description provided for @warnMissingRates.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate for {currencies}. Those amounts are not counted yet.'**
  String warnMissingRates(String currencies);

  /// No description provided for @warnOverPlanned.
  ///
  /// In en, this message translates to:
  /// **'The plan is over budget by {amount}.'**
  String warnOverPlanned(String amount);

  /// No description provided for @warnOverActual.
  ///
  /// In en, this message translates to:
  /// **'Spending is over budget by {amount}.'**
  String warnOverActual(String amount);

  /// No description provided for @warnNearLimit.
  ///
  /// In en, this message translates to:
  /// **'The plan uses more than 90% of the budget.'**
  String get warnNearLimit;

  /// No description provided for @rateLabel.
  ///
  /// In en, this message translates to:
  /// **'1 {currency} = ? {base}'**
  String rateLabel(String currency, String base);

  /// No description provided for @rateManual.
  ///
  /// In en, this message translates to:
  /// **'Entered manually · not verified'**
  String get rateManual;

  /// No description provided for @rateFrom.
  ///
  /// In en, this message translates to:
  /// **'From {source} · {date}'**
  String rateFrom(String source, String date);

  /// No description provided for @rateMissing.
  ///
  /// In en, this message translates to:
  /// **'No rate yet'**
  String get rateMissing;

  /// No description provided for @refreshRates.
  ///
  /// In en, this message translates to:
  /// **'Fetch live rates (online)'**
  String get refreshRates;

  /// No description provided for @ratesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Rates updated'**
  String get ratesUpdated;

  /// No description provided for @ratesUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available online: {currencies}. Enter them manually.'**
  String ratesUnsupported(String currencies);

  /// No description provided for @ratesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch rates: {error}'**
  String ratesFailed(String error);

  /// No description provided for @addRate.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get addRate;

  /// No description provided for @rateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than 0'**
  String get rateInvalid;

  /// No description provided for @ratesHelp.
  ///
  /// In en, this message translates to:
  /// **'Amounts in other currencies are converted to {base} with these rates.'**
  String ratesHelp(String base);

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount of 0 or more'**
  String get amountInvalid;

  /// No description provided for @catFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get catFlights;

  /// No description provided for @catTrains.
  ///
  /// In en, this message translates to:
  /// **'Trains'**
  String get catTrains;

  /// No description provided for @catBuses.
  ///
  /// In en, this message translates to:
  /// **'Buses & ferries'**
  String get catBuses;

  /// No description provided for @catTaxis.
  ///
  /// In en, this message translates to:
  /// **'Taxis & local transport'**
  String get catTaxis;

  /// No description provided for @catHotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get catHotels;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catAttractions.
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get catAttractions;

  /// No description provided for @catActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get catActivities;

  /// No description provided for @catInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet & SIM'**
  String get catInternet;

  /// No description provided for @catInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get catInsurance;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get catEmergency;

  /// No description provided for @catMisc.
  ///
  /// In en, this message translates to:
  /// **'Miscellaneous'**
  String get catMisc;

  /// No description provided for @kindTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport (mode TBD)'**
  String get kindTransport;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Other transport'**
  String get catTransport;

  /// No description provided for @timeTbd.
  ///
  /// In en, this message translates to:
  /// **'Time TBD'**
  String get timeTbd;

  /// No description provided for @timeTbdToggle.
  ///
  /// In en, this message translates to:
  /// **'Time to be decided'**
  String get timeTbdToggle;

  /// No description provided for @timeTbdHelp.
  ///
  /// In en, this message translates to:
  /// **'Use this while the schedule isn’t confirmed. No time is guessed; the day shows “Needs info” until you set one.'**
  String get timeTbdHelp;

  /// No description provided for @issueTimeNotSet.
  ///
  /// In en, this message translates to:
  /// **'No time set yet: {titles}'**
  String issueTimeNotSet(String titles);

  /// No description provided for @notScheduled.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled yet'**
  String get notScheduled;

  /// No description provided for @importInvalidDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not import: {detail}'**
  String importInvalidDetail(String detail);

  /// No description provided for @importHow.
  ///
  /// In en, this message translates to:
  /// **'How do you want to import?'**
  String get importHow;

  /// No description provided for @importChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get importChooseFile;

  /// No description provided for @importChooseFileHelp.
  ///
  /// In en, this message translates to:
  /// **'A .wanderplan file from a friend, or a .json file'**
  String get importChooseFileHelp;

  /// No description provided for @importPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get importPaste;

  /// No description provided for @importPasteHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste trip JSON copied from ChatGPT, Notes, email…'**
  String get importPasteHelp;

  /// No description provided for @importPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the trip JSON here'**
  String get importPasteHint;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @importFormatHelp.
  ///
  /// In en, this message translates to:
  /// **'Format guide: docs/IMPORT_FORMAT.md'**
  String get importFormatHelp;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & privacy'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'WanderPlan stores your trips and photos only on this device. No account is required.'**
  String get privacyBody;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataBody.
  ///
  /// In en, this message translates to:
  /// **'All trips, photos and settings on this device will be permanently deleted.'**
  String get deleteAllDataBody;

  /// No description provided for @allDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'All data deleted'**
  String get allDataDeleted;

  /// No description provided for @atlasEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your personal atlas'**
  String get atlasEyebrow;

  /// No description provided for @atlasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your plans, places and days away.'**
  String get atlasSubtitle;

  /// No description provided for @atlasCollection.
  ///
  /// In en, this message translates to:
  /// **'{count} trips in your collection'**
  String atlasCollection(int count);

  /// No description provided for @atlasJourney.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get atlasJourney;

  /// No description provided for @atlasFilters.
  ///
  /// In en, this message translates to:
  /// **'Filter trips'**
  String get atlasFilters;

  /// No description provided for @atlasBegin.
  ///
  /// In en, this message translates to:
  /// **'A new chapter'**
  String get atlasBegin;

  /// No description provided for @atlasFooter.
  ///
  /// In en, this message translates to:
  /// **'Good journeys start with a little planning.'**
  String get atlasFooter;

  /// No description provided for @atlasEdition.
  ///
  /// In en, this message translates to:
  /// **'The travel collection'**
  String get atlasEdition;

  /// No description provided for @atlasSigninHeadline.
  ///
  /// In en, this message translates to:
  /// **'Somewhere new.\nSomething to look forward to.'**
  String get atlasSigninHeadline;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
