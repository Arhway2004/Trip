// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'WanderPlan';

  @override
  String get tabHome => 'หน้าแรก';

  @override
  String get tabMap => 'แผนที่';

  @override
  String get tabTimeline => 'ไทม์ไลน์';

  @override
  String get tabBudget => 'งบประมาณ';

  @override
  String get tabMore => 'เพิ่มเติม';

  @override
  String get searchTrips => 'ค้นหาทริป';

  @override
  String get searchTripsEmpty => 'ไม่พบทริปที่ตรงกับการค้นหา';

  @override
  String get clearSearch => 'ล้างการค้นหา';

  @override
  String get myTrips => 'ทริปของฉัน';

  @override
  String get createTrip => 'สร้างทริปใหม่';

  @override
  String get newTrip => 'ทริปใหม่';

  @override
  String get editTrip => 'แก้ไขทริป';

  @override
  String get emptyTripsTitle => 'ยังไม่มีทริป';

  @override
  String get emptyTripsBody =>
      'เริ่มวางแผนการเดินทางครั้งต่อไป ทริปต้องการแค่ชื่อ ส่วนที่เหลือเพิ่มทีหลังได้';

  @override
  String get emptyFilterBody => 'ไม่มีทริปที่ตรงกับตัวกรองนี้';

  @override
  String get filterAll => 'ทั้งหมด';

  @override
  String get filterUpcoming => 'กำลังจะมาถึง';

  @override
  String get filterTraveling => 'กำลังเดินทาง';

  @override
  String get filterCompleted => 'เสร็จสิ้น';

  @override
  String get filterArchived => 'เก็บถาวร';

  @override
  String get statusDreaming => 'กำลังฝัน';

  @override
  String get statusPlanning => 'กำลังวางแผน';

  @override
  String get statusUpcoming => 'กำลังจะมาถึง';

  @override
  String get statusTraveling => 'กำลังเดินทาง';

  @override
  String get statusCompleted => 'เสร็จสิ้น';

  @override
  String get statusArchived => 'เก็บถาวร';

  @override
  String get actionEdit => 'แก้ไข';

  @override
  String get actionDuplicate => 'ทำสำเนา';

  @override
  String get actionArchive => 'เก็บถาวร';

  @override
  String get actionUnarchive => 'ยกเลิกการเก็บถาวร';

  @override
  String get actionDelete => 'ลบ';

  @override
  String get actionEditBanner => 'แก้ไขแบนเนอร์';

  @override
  String get actionReorder => 'จัดลำดับทริป';

  @override
  String get actionDone => 'เสร็จ';

  @override
  String get actionSave => 'บันทึก';

  @override
  String get actionCancel => 'ยกเลิก';

  @override
  String get duplicateSuffix => ' (สำเนา)';

  @override
  String get deleteTripTitle => 'ลบทริปหรือไม่?';

  @override
  String deleteTripBody(String title) {
    return '“$title” และรูปภาพทั้งหมดจะถูกลบอย่างถาวร ไม่สามารถกู้คืนได้';
  }

  @override
  String get tripDuplicated => 'ทำสำเนาทริปแล้ว';

  @override
  String get tripArchived => 'เก็บทริปถาวรแล้ว';

  @override
  String get tripUnarchived => 'นำทริปออกจากที่เก็บถาวรแล้ว';

  @override
  String get tripDeleted => 'ลบทริปแล้ว';

  @override
  String get restoreFromBackup => 'กู้คืนจากข้อมูลสำรอง';

  @override
  String get restoreNotYet =>
      'ยังไม่รองรับการสำรองและกู้คืนข้อมูล (วางแผนไว้ในเฟสนำเข้า/ส่งออก)';

  @override
  String get datesUndecided => 'ยังไม่กำหนดวันที่';

  @override
  String get datesFlexible => 'วันที่ยืดหยุ่น';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count วัน',
    );
    return '$_temp0';
  }

  @override
  String travelersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ผู้เดินทาง $count คน',
    );
    return '$_temp0';
  }

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count วัน',
    );
    return '$_temp0';
  }

  @override
  String unitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ชั่วโมง',
    );
    return '$_temp0';
  }

  @override
  String unitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count นาที',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'อีก $count วัน',
      zero: 'ออกเดินทางวันนี้',
    );
    return '$_temp0';
  }

  @override
  String countdownRemaining(String value) {
    return 'เหลืออีก $value';
  }

  @override
  String countdownDayOf(int day, int total) {
    return 'วันที่ $day จาก $total';
  }

  @override
  String get countdownCompleted => 'ทริปเสร็จสิ้น';

  @override
  String get countdownNoDate => 'กำหนดวันที่เพื่อเริ่มนับถอยหลัง';

  @override
  String departsOn(String date) {
    return 'ออกเดินทาง $date';
  }

  @override
  String departsOnAt(String date, String time) {
    return 'ออกเดินทาง $date เวลา $time';
  }

  @override
  String get fieldTitle => 'ชื่อทริป';

  @override
  String get fieldTitleHint => 'เช่น ฤดูใบไม้ร่วงที่เกียวโต';

  @override
  String get titleRequired => 'กรุณากรอกชื่อทริป';

  @override
  String get fieldDescription => 'คำอธิบาย';

  @override
  String get optional => 'ไม่บังคับ';

  @override
  String get sectionCover => 'ภาพปก';

  @override
  String get coverPick => 'เลือกรูปภาพ';

  @override
  String get coverCamera => 'ถ่ายรูป';

  @override
  String get coverRemove => 'นำออก';

  @override
  String get coverHint => 'คุณสามารถครอปและปรับแต่งแบนเนอร์ได้หลังบันทึก';

  @override
  String get sectionDestinations => 'จุดหมายปลายทาง';

  @override
  String get fieldCountry => 'ประเทศ';

  @override
  String get fieldCity => 'เมือง';

  @override
  String get addDestination => 'เพิ่มจุดหมาย';

  @override
  String get removeDestination => 'นำจุดหมายออก';

  @override
  String get mainDestination => 'จุดหมายหลัก';

  @override
  String get sectionDates => 'วันที่';

  @override
  String get pickDates => 'เลือกวันที่';

  @override
  String get clearDates => 'ล้างวันที่';

  @override
  String get datesConfirmed => 'ยืนยันวันที่แล้ว';

  @override
  String get datesConfirmedHelp => 'ปิดไว้หากวันที่ยังไม่แน่นอน';

  @override
  String get departureTime => 'เวลาออกเดินทาง';

  @override
  String get notSet => 'ยังไม่ได้ตั้งค่า';

  @override
  String get fieldTimeZone => 'เขตเวลา';

  @override
  String get timeZoneHelp => 'การนับถอยหลังและวันที่จะใช้เขตเวลานี้';

  @override
  String get searchTimeZone => 'ค้นหาเขตเวลา';

  @override
  String get sectionDetails => 'รายละเอียด';

  @override
  String get fieldTravelers => 'จำนวนผู้เดินทาง';

  @override
  String get fieldCurrency => 'สกุลเงินหลัก';

  @override
  String get currencyInvalid => 'ใช้รหัสสกุลเงิน ISO 3 ตัวอักษร เช่น THB';

  @override
  String get fieldBudget => 'งบประมาณรวม';

  @override
  String get budgetInvalid => 'กรุณากรอกตัวเลขที่มากกว่าศูนย์';

  @override
  String get budgetNeedsCurrency => 'กรุณาเลือกสกุลเงินสำหรับงบประมาณ';

  @override
  String get fieldTravelStyle => 'สไตล์การเดินทาง';

  @override
  String get fieldStage => 'ขั้นตอนการวางแผน';

  @override
  String get stageHelp =>
      'สถานะกำลังจะมาถึง กำลังเดินทาง และเสร็จสิ้น จะตั้งค่าอัตโนมัติจากวันที่';

  @override
  String get styleRelaxed => 'ชิลล์';

  @override
  String get styleBalanced => 'สมดุล';

  @override
  String get stylePacked => 'แน่นเอี้ยด';

  @override
  String get styleBudget => 'ประหยัด';

  @override
  String get styleComfort => 'สะดวกสบาย';

  @override
  String get styleLuxury => 'หรูหรา';

  @override
  String get styleAdventure => 'ผจญภัย';

  @override
  String get styleFamily => 'ครอบครัว';

  @override
  String get saveTripCreate => 'สร้างทริป';

  @override
  String get saveTripChanges => 'บันทึกการเปลี่ยนแปลง';

  @override
  String get discardChangesTitle => 'ยกเลิกการเปลี่ยนแปลง?';

  @override
  String get discard => 'ยกเลิก';

  @override
  String get keepEditing => 'แก้ไขต่อ';

  @override
  String saveFailed(String error) {
    return 'บันทึกไม่สำเร็จ: $error';
  }

  @override
  String get overview => 'ภาพรวม';

  @override
  String get budgetTitle => 'งบประมาณ';

  @override
  String get budgetNotSet => 'ยังไม่ได้ตั้งงบประมาณ';

  @override
  String budgetPerPerson(String amount) {
    return 'คนละ $amount';
  }

  @override
  String get photosTitle => 'รูปภาพ';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count รูป',
      zero: 'ไม่มีรูปภาพ',
    );
    return '$_temp0';
  }

  @override
  String get openGallery => 'เปิดแกลเลอรี';

  @override
  String get addPhoto => 'เพิ่มรูปภาพ';

  @override
  String get quickActions => 'การดำเนินการด่วน';

  @override
  String get planningModules => 'เครื่องมือวางแผน';

  @override
  String get notImplementedYet => 'ยังไม่พร้อมใช้งาน';

  @override
  String get moduleMap => 'เปิดแผนที่';

  @override
  String get moduleAttraction => 'เพิ่มสถานที่ท่องเที่ยว';

  @override
  String get moduleItinerary => 'แก้ไขแผนการเดินทาง';

  @override
  String get moduleFlight => 'เพิ่มเที่ยวบิน';

  @override
  String get moduleTrain => 'เพิ่มรถไฟ';

  @override
  String get moduleHotel => 'เพิ่มโรงแรม';

  @override
  String get moduleExpense => 'เพิ่มค่าใช้จ่าย';

  @override
  String get moduleBudget => 'เปิดงบประมาณ';

  @override
  String get moduleExport => 'ส่งออกทริป';

  @override
  String get tripNotFound => 'ไม่พบทริปนี้แล้ว';

  @override
  String get bannerEditorTitle => 'แก้ไขแบนเนอร์';

  @override
  String get bannerTabImage => 'รูปภาพ';

  @override
  String get bannerTabBackground => 'พื้นหลัง';

  @override
  String get bannerTabText => 'ชื่อเรื่อง';

  @override
  String get bannerTabStyle => 'สไตล์';

  @override
  String get bannerFromDevice => 'อัปโหลดจากอุปกรณ์';

  @override
  String get bannerFromTrip => 'เลือกรูปจากทริป';

  @override
  String get bannerNoTripPhotos => 'ทริปนี้ยังไม่มีรูปภาพ';

  @override
  String get bannerAdjustHint =>
      'ลากเพื่อจัดตำแหน่ง · จีบนิ้วหรือใช้แถบเลื่อนเพื่อซูม';

  @override
  String get bannerZoom => 'ซูม';

  @override
  String get bannerResetCrop => 'รีเซ็ตการครอป';

  @override
  String get bannerRemoveImage => 'ใช้สีแทน';

  @override
  String get bannerGradient => 'ไล่สี';

  @override
  String get bannerSolid => 'สีพื้น';

  @override
  String get bannerColorsBehindImage => 'สีพื้นหลังจะแสดงเมื่อไม่ได้ใช้รูปภาพ';

  @override
  String get bannerShowTitle => 'แสดงชื่อบนแบนเนอร์';

  @override
  String get bannerPlacement => 'ตำแหน่งชื่อ';

  @override
  String get placementTopLeft => 'บนซ้าย';

  @override
  String get placementCenter => 'กึ่งกลาง';

  @override
  String get placementBottomLeft => 'ล่างซ้าย';

  @override
  String get placementBottomCenter => 'ล่างกลาง';

  @override
  String get bannerTextColor => 'สีตัวอักษร';

  @override
  String get bannerStyleClassic => 'คลาสสิก';

  @override
  String get bannerStyleMinimal => 'มินิมอล';

  @override
  String get bannerStyleBold => 'โดดเด่น';

  @override
  String get bannerStyleFramed => 'มีกรอบ';

  @override
  String get galleryEmpty =>
      'ยังไม่มีรูปภาพ เพิ่มรูปเพื่อเก็บความทรงจำของทริปนี้';

  @override
  String get galleryFromDevice => 'จากอุปกรณ์';

  @override
  String get photoCaption => 'คำบรรยาย';

  @override
  String get photoFavorite => 'รายการโปรด';

  @override
  String get favoritesOnly => 'เฉพาะรายการโปรด';

  @override
  String get setAsCover => 'ตั้งเป็นแบนเนอร์ปก';

  @override
  String get coverUpdated => 'อัปเดตแบนเนอร์ปกแล้ว';

  @override
  String get deletePhotoTitle => 'ลบรูปภาพหรือไม่?';

  @override
  String get deletePhotoBody =>
      'รูปภาพจะถูกลบออกจากทริปนี้และพื้นที่จัดเก็บของ WanderPlan';

  @override
  String get photoAccessError =>
      'ไม่สามารถเข้าถึงรูปภาพหรือกล้องได้ โปรดตรวจสอบสิทธิ์ในการตั้งค่าระบบ';

  @override
  String get selectTripFirst => 'โปรดเปิดทริปจากหน้าแรกก่อน';

  @override
  String get goToTrips => 'ไปที่ทริปของฉัน';

  @override
  String currentTrip(String title) {
    return 'ทริปปัจจุบัน: $title';
  }

  @override
  String get mapNotYet =>
      'แผนที่จริง การค้นหาสถานที่ และการแสดงเส้นทาง อยู่ในแผนเฟส 3 และยังไม่พร้อมใช้งาน';

  @override
  String get timelineNotYet =>
      'ไทม์ไลน์รายวันตั้งแต่เช้าถึงค่ำอยู่ในแผนเฟส 2 และยังไม่พร้อมใช้งาน';

  @override
  String get budgetNotYet =>
      'การติดตามค่าใช้จ่ายและวิเคราะห์งบประมาณอยู่ในแผนเฟส 2 และยังไม่พร้อมใช้งาน';

  @override
  String get moreFlights => 'เที่ยวบิน';

  @override
  String get moreTransportation => 'การเดินทาง';

  @override
  String get moreHotels => 'โรงแรม';

  @override
  String get moreAttractions => 'สถานที่ท่องเที่ยว';

  @override
  String get moreScenarios => 'สถานการณ์';

  @override
  String get moreGallery => 'แกลเลอรี';

  @override
  String get moreJournal => 'บันทึกการเดินทาง';

  @override
  String get moreAnalysis => 'การวิเคราะห์';

  @override
  String get moreImportExport => 'นำเข้า / ส่งออก';

  @override
  String get moreSettings => 'การตั้งค่า';

  @override
  String get noTripSelected => 'ยังไม่ได้เลือกทริป';

  @override
  String get todosTitle => 'สิ่งที่ต้องทำก่อนเดินทาง';

  @override
  String get todosShort => 'สิ่งที่ต้องทำ';

  @override
  String todosProgress(int done, int total) {
    return 'เสร็จแล้ว $done จาก $total';
  }

  @override
  String get todosEmpty =>
      'ยังไม่มีรายการ เพิ่มสิ่งที่ต้องทำให้เสร็จก่อนออกเดินทาง';

  @override
  String get todosAllDone => 'เสร็จครบแล้ว พร้อมออกเดินทาง!';

  @override
  String get todosNextUp => 'ถัดไป';

  @override
  String get todoAdd => 'เพิ่มงาน';

  @override
  String get todoEdit => 'แก้ไขงาน';

  @override
  String get todoTitleField => 'งาน';

  @override
  String get todoNotes => 'หมายเหตุ';

  @override
  String get todoCategory => 'หมวดหมู่';

  @override
  String get todoDueDate => 'วันครบกำหนด';

  @override
  String get todoNoDueDate => 'ไม่มีกำหนด';

  @override
  String todoDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ครบกำหนดในอีก $count วัน',
      one: 'ครบกำหนดพรุ่งนี้',
      zero: 'ครบกำหนดวันนี้',
    );
    return '$_temp0';
  }

  @override
  String todoOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'เลยกำหนด $count วัน',
    );
    return '$_temp0';
  }

  @override
  String get todoAfterDeparture => 'หลังวันออกเดินทาง';

  @override
  String get todoHideDone => 'ซ่อนที่เสร็จแล้ว';

  @override
  String get todoSuggestions => 'เพิ่มรายการแนะนำ';

  @override
  String get todoSuggestionsTitle => 'สิ่งที่มักต้องทำก่อนเดินทาง';

  @override
  String todoAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'เพิ่ม $count รายการ',
      zero: 'เพิ่ม',
    );
    return '$_temp0';
  }

  @override
  String get todoDeleted => 'ลบงานแล้ว';

  @override
  String get undo => 'เลิกทำ';

  @override
  String get todoCatDocuments => 'เอกสาร';

  @override
  String get todoCatBookings => 'การจอง';

  @override
  String get todoCatPacking => 'จัดกระเป๋า';

  @override
  String get todoCatHealth => 'สุขภาพและประกัน';

  @override
  String get todoCatMoney => 'เงินและบัตร';

  @override
  String get todoCatConnectivity => 'โทรศัพท์และอินเทอร์เน็ต';

  @override
  String get todoCatHome => 'เรื่องที่บ้าน';

  @override
  String get todoCatOther => 'อื่น ๆ';

  @override
  String get sugPassport => 'ตรวจสอบวันหมดอายุหนังสือเดินทาง/บัตรประชาชน';

  @override
  String get sugEntryRequirements => 'ตรวจสอบวีซ่าและข้อกำหนดการเข้าประเทศ';

  @override
  String get sugInsurance => 'ทำประกันการเดินทาง';

  @override
  String get sugMedication => 'เตรียมยาและใบสั่งยา';

  @override
  String get sugConfirmStay => 'ยืนยันการจองที่พัก';

  @override
  String get sugCheckIn => 'เช็คอินเที่ยวบินออนไลน์';

  @override
  String get sugAirportTransport => 'วางแผนการเดินทางไปสนามบินหรือสถานี';

  @override
  String get sugBankCards => 'ตรวจสอบค่าธรรมเนียมบัตรและแจ้งธนาคาร';

  @override
  String get sugLocalCash => 'เตรียมเงินสกุลท้องถิ่น';

  @override
  String get sugSimCard => 'เตรียมซิม eSIM หรือโรมมิ่ง';

  @override
  String get sugOfflineCopies => 'บันทึกสำเนาตั๋วและเอกสารแบบออฟไลน์';

  @override
  String get sugChargers => 'เตรียมที่ชาร์จและปลั๊กแปลง';

  @override
  String get sugHomeArrangements => 'จัดการเรื่องสัตว์เลี้ยง ต้นไม้ และจดหมาย';

  @override
  String get shareTrip => 'แชร์ให้เพื่อน';

  @override
  String get shareExplain =>
      'เพื่อนจะได้รับสำเนาทริปนี้เป็นไฟล์ เปิดใน WanderPlan → ทริปของฉัน → ⋮ → นำเข้าทริป การแก้ไขภายหลังจะไม่ซิงค์ระหว่างกัน';

  @override
  String get shareIncludePhotos => 'รวมรูปในแกลเลอรี';

  @override
  String shareIncludePhotosHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count รูป · ไฟล์จะใหญ่ขึ้น',
      zero: 'ไม่มีรูปที่จะรวม',
    );
    return '$_temp0';
  }

  @override
  String get shareSend => 'แชร์ไฟล์';

  @override
  String shareMessage(String title) {
    return 'ทริป WanderPlan ของฉัน “$title” วิธีเพิ่ม: WanderPlan → ทริปของฉัน → ⋮ → นำเข้าทริป';
  }

  @override
  String shareFailed(String error) {
    return 'สร้างไฟล์สำหรับแชร์ไม่สำเร็จ: $error';
  }

  @override
  String get importTrip => 'นำเข้าทริป';

  @override
  String importSuccess(String title) {
    return 'นำเข้า “$title” แล้ว';
  }

  @override
  String get importInvalid => 'ไฟล์นี้ไม่ใช่ไฟล์ทริปของ WanderPlan';

  @override
  String get importTooNew =>
      'ไฟล์นี้สร้างจาก WanderPlan เวอร์ชันใหม่กว่า โปรดอัปเดตแอปก่อนนำเข้า';

  @override
  String homeSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'มีทริปทั้งหมด $count ทริป',
      zero: 'ไปที่ไหนต่อดี?',
    );
    return '$_temp0';
  }

  @override
  String get kpiDuration => 'ระยะเวลา';

  @override
  String get kpiStatus => 'สถานะ';

  @override
  String get soon => 'เร็ว ๆ นี้';

  @override
  String get tripTools => 'เครื่องมือทริป';

  @override
  String get viewAll => 'ดูทั้งหมด';

  @override
  String get addActivity => 'เพิ่มกิจกรรม';

  @override
  String get editActivity => 'แก้ไขกิจกรรม';

  @override
  String get activityTitle => 'ชื่อ';

  @override
  String get activityKind => 'ประเภท';

  @override
  String get kindSightseeing => 'เที่ยวชม';

  @override
  String get kindFood => 'อาหาร';

  @override
  String get kindActivity => 'กิจกรรม';

  @override
  String get kindShopping => 'ช้อปปิ้ง';

  @override
  String get kindRest => 'พักผ่อน';

  @override
  String get kindFlight => 'เที่ยวบิน';

  @override
  String get kindTrain => 'รถไฟ';

  @override
  String get kindBus => 'รถบัส';

  @override
  String get kindTransfer => 'แท็กซี่ / รถไฟฟ้า';

  @override
  String get kindFerry => 'เรือข้ามฟาก';

  @override
  String get kindHotel => 'โรงแรม';

  @override
  String get kindOther => 'อื่น ๆ';

  @override
  String get fieldDate => 'วันที่';

  @override
  String get fieldStart => 'เริ่ม';

  @override
  String get fieldEnd => 'สิ้นสุด';

  @override
  String get fieldEndDate => 'วันที่สิ้นสุด';

  @override
  String get fieldCheckIn => 'เช็คอิน';

  @override
  String get fieldCheckOut => 'เช็คเอาต์';

  @override
  String get sameDay => 'วันเดียวกัน';

  @override
  String get fieldLocation => 'สถานที่';

  @override
  String get fieldFrom => 'จาก';

  @override
  String get fieldTo => 'ถึง';

  @override
  String get pickOnMap => 'เลือกบนแผนที่';

  @override
  String get onMap => 'อยู่บนแผนที่';

  @override
  String get notOnMap => 'ยังไม่ได้ปักหมุดบนแผนที่';

  @override
  String get fieldCost => 'ค่าใช้จ่ายโดยประมาณ';

  @override
  String get fieldBooking => 'การจอง';

  @override
  String get bookingNotBooked => 'ยังไม่จอง';

  @override
  String get bookingBooked => 'จองแล้ว';

  @override
  String get bookingConfirmed => 'ยืนยันแล้ว';

  @override
  String get bookingCancelled => 'ยกเลิกแล้ว';

  @override
  String get fieldProvider => 'สายการบิน / ผู้ให้บริการ / โรงแรม';

  @override
  String get fieldServiceNumber => 'เลขเที่ยวบิน / ขบวนรถ';

  @override
  String get fieldBookingRef => 'รหัสการจอง (ส่วนตัว)';

  @override
  String get fieldBookingUrl => 'ลิงก์การจอง';

  @override
  String get fieldNotes => 'หมายเหตุ';

  @override
  String get fieldLocked => 'ล็อกไว้';

  @override
  String get lockedHelp =>
      'รายการที่ล็อกคือการจองที่ยืนยันแล้ว จะไม่ถูกย้ายเมื่อลาก';

  @override
  String get fieldOptional => 'ไม่บังคับ';

  @override
  String get optionalHelp => 'ถ้ามีเวลาค่อยไป ข้ามได้ถ้าเวลาไม่พอ';

  @override
  String get endBeforeStart => 'เวลาสิ้นสุดต้องหลังเวลาเริ่ม';

  @override
  String get deleteActivityTitle => 'ลบกิจกรรมหรือไม่?';

  @override
  String get activityDeleted => 'ลบกิจกรรมแล้ว';

  @override
  String get duplicateToNextDay => 'คัดลอกไปวันถัดไป';

  @override
  String get lockedCannotMove => 'ย้ายกิจกรรมที่ล็อกไม่ได้ ปลดล็อกก่อน';

  @override
  String get timelineEmptyDay => 'ยังไม่มีแผนสำหรับวันนี้';

  @override
  String get timelineNoDays =>
      'กำหนดวันที่ทริปหรือเพิ่มกิจกรรมเพื่อเริ่มวางแผนรายวัน';

  @override
  String get viewList => 'รายการ';

  @override
  String get viewGrid => 'ตารางเวลา';

  @override
  String get dragHint =>
      'กดค้างแล้วลากเพื่อย้าย · ลากขอบล่างเพื่อเปลี่ยนระยะเวลา';

  @override
  String freeTime(String duration) {
    return 'ว่าง $duration';
  }

  @override
  String durationHm(int h, int m) {
    return '$h ชม. $m นาที';
  }

  @override
  String durationH(int h) {
    return '$h ชม.';
  }

  @override
  String durationM(int m) {
    return '$m นาที';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count คืน',
    );
    return '$_temp0';
  }

  @override
  String dayN(int n) {
    return 'วันที่ $n';
  }

  @override
  String get outsideTrip => 'นอกช่วงทริป';

  @override
  String get dayFeasible => 'ทำได้';

  @override
  String get dayTight => 'แน่น';

  @override
  String get dayUnrealistic => 'ไม่สมจริง';

  @override
  String get dayUnknown => 'ข้อมูลไม่พอ';

  @override
  String get dayEmpty => 'วันว่าง';

  @override
  String issueOverlap(String a, String b, int minutes) {
    return '“$a” ทับซ้อนกับ “$b” $minutes นาที';
  }

  @override
  String issueNoTravelTime(String a, String b) {
    return 'ไม่มีเวลาเดินทางจาก “$a” ไป “$b”';
  }

  @override
  String issueTightTravel(
    String a,
    String b,
    String km,
    int minutes,
    int needed,
  ) {
    return '“$a” → “$b” ห่างกัน $km กม. (เส้นตรง) แต่มีเวลาแค่ $minutes นาที ควรเผื่อประมาณ $needed นาที';
  }

  @override
  String issueDepartureBuffer(String b, int minutes, int needed) {
    return 'มีเวลาแค่ $minutes นาทีก่อน “$b” ควรเผื่ออย่างน้อย $needed นาทีสำหรับเดินทางและเช็คอิน';
  }

  @override
  String issueLongDay(String hours) {
    return 'วันที่แน่นมาก: กิจกรรมรวม $hours ชม.';
  }

  @override
  String issueEarlyAndLate(String hours) {
    return 'เริ่มเช้าและเลิกดึก (รวม $hours ชม.)';
  }

  @override
  String get issueNoMealBreak => 'ไม่มีเวลาพักหรือทานอาหารช่วงกลางวัน';

  @override
  String get issueLateFinish => 'เลิกหลัง 23:00';

  @override
  String get issueMissingAccommodation => 'ยังไม่มีที่พักสำหรับคืนนี้';

  @override
  String issueOverlappingStays(String titles) {
    return 'มีที่พักซ้อนกันในคืนเดียว: $titles';
  }

  @override
  String issueTransportNotBooked(String titles) {
    return 'ยังไม่ได้จอง: $titles';
  }

  @override
  String issueOutsideTripDates(String titles) {
    return 'อยู่นอกช่วงวันที่ทริป: $titles';
  }

  @override
  String get feasibilityNote =>
      'การตรวจสอบใช้หลักการโดยประมาณ (ระยะทางเส้นตรงที่ประมาณ 25 กม./ชม., ก่อนเที่ยวบิน 2 ชม., ก่อนรถไฟ 30 นาที) เป็นการประมาณ ไม่ใช่เส้นทางจริง';

  @override
  String get bookingsTitle => 'การจอง';

  @override
  String get bookingsEmpty => 'ยังไม่มีเที่ยวบิน รถไฟ หรือโรงแรม';

  @override
  String get bookingsTransport => 'การเดินทาง';

  @override
  String get bookingsStays => 'ที่พัก';

  @override
  String get nextUp => 'ถัดไป';

  @override
  String get planCheck => 'ตรวจแผน';

  @override
  String daysNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count วันต้องตรวจสอบ',
    );
    return '$_temp0';
  }

  @override
  String get allDaysOk => 'ทุกวันที่วางแผนไว้ดูทำได้';

  @override
  String get noActivitiesYet => 'ยังไม่มีกิจกรรม';

  @override
  String activitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count กิจกรรม',
    );
    return '$_temp0';
  }

  @override
  String get mapAllDays => 'ทุกวัน';

  @override
  String mapNoPins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'มี $count กิจกรรมที่ยังไม่มีตำแหน่ง',
    );
    return '$_temp0';
  }

  @override
  String get mapOnlineNote => 'แผนที่และการค้นหาสถานที่ต้องใช้อินเทอร์เน็ต';

  @override
  String get mapEmpty =>
      'ยังไม่มีอะไรบนแผนที่ ค้นหาสถานที่ สำรวจใกล้เคียง หรือแก้ไขกิจกรรมแล้วใช้ “เลือกบนแผนที่”';

  @override
  String get fitAll => 'แสดงทั้งหมด';

  @override
  String get placeAttraction => 'สถานที่ท่องเที่ยว';

  @override
  String get placeRestaurant => 'ร้านอาหาร';

  @override
  String get placeHotel => 'โรงแรม';

  @override
  String get placeAirport => 'สนามบิน';

  @override
  String get placeRailwayStation => 'สถานีรถไฟ';

  @override
  String get placeBusStation => 'สถานีขนส่ง';

  @override
  String get placeOther => 'อื่น ๆ';

  @override
  String get modeWalking => 'เดิน';

  @override
  String get modeCycling => 'ปั่นจักรยาน';

  @override
  String get modeDriving => 'ขับรถ / แท็กซี่';

  @override
  String get mapProvider => 'ผู้ให้บริการแผนที่';

  @override
  String get providerAuto => 'อัตโนมัติ';

  @override
  String get providerAutoHelp =>
      'ใช้ Amap ในจีนแผ่นดินใหญ่ และ OpenStreetMap ที่อื่น';

  @override
  String get providerOsm => 'OpenStreetMap';

  @override
  String get providerAmap => 'Amap (เกาเต๋อ)';

  @override
  String get amapNoKey =>
      'การค้นหาและเส้นทางของ Amap ต้องใช้คีย์ Amap จึงใช้ของ OpenStreetMap แทน';

  @override
  String get savedPlaces => 'สถานที่ที่บันทึกไว้';

  @override
  String get savedPlacesEmpty =>
      'ยังไม่มีสถานที่ที่บันทึกไว้ ค้นหา สำรวจใกล้เคียง หรือกดค้างบนแผนที่เพื่อปักหมุด';

  @override
  String get savePlace => 'บันทึกสถานที่';

  @override
  String get removePlace => 'นำออก';

  @override
  String get placeSaved => 'บันทึกไว้ในทริปนี้แล้ว';

  @override
  String get placeRemoved => 'นำสถานที่ออกแล้ว';

  @override
  String get addToDay => 'เพิ่มในวัน';

  @override
  String get chooseDay => 'เลือกวัน';

  @override
  String addedToDay(String date) {
    return 'เพิ่มใน $date แล้ว · ยังไม่กำหนดเวลา';
  }

  @override
  String plannedOn(String dates) {
    return 'อยู่ในแผน: $dates';
  }

  @override
  String get notPlanned => 'ยังไม่อยู่ในแผน';

  @override
  String sourceSearch(String provider) {
    return 'พิกัดจากการค้นหา $provider';
  }

  @override
  String get sourcePinned => 'คุณปักหมุดบนแผนที่เอง';

  @override
  String get sourceImported => 'พิกัดจากไฟล์นำเข้า';

  @override
  String get mapPinnedPlace => 'สถานที่ที่ปักหมุด';

  @override
  String get mapLongPressHint => 'กดค้างเพื่อปักหมุดสถานที่';

  @override
  String get nearbyEmpty => 'ไม่พบสิ่งใดในบริเวณนี้';

  @override
  String get filterMarkers => 'กรองหมุด';

  @override
  String get layerPlan => 'แผน';

  @override
  String get layerResults => 'ผลการค้นหาและใกล้เคียง';

  @override
  String get myLocation => 'ตำแหน่งของฉัน';

  @override
  String get locationOff => 'บริการตำแหน่งปิดอยู่';

  @override
  String get locationDenied => 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง';

  @override
  String get locationDeniedForever =>
      'การเข้าถึงตำแหน่งถูกบล็อก โปรดอนุญาตในการตั้งค่าระบบ';

  @override
  String get locationUnavailable => 'ไม่สามารถระบุตำแหน่งของคุณได้';

  @override
  String get routeLoading => 'กำลังหาเส้นทาง…';

  @override
  String routeTotal(String distance, String duration) {
    return '$distance · ประมาณ $duration';
  }

  @override
  String routeEstimateNote(String provider) {
    return 'เส้นทางถนน: $provider เวลาเป็นค่าประมาณทั่วไป ไม่ใช่สภาพจราจรจริงหรือตารางเดินรถ';
  }

  @override
  String routeUnverified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ช่วงไม่มีเส้นทางถนน: แสดงเป็นเส้นตรง ยังไม่ยืนยัน',
    );
    return '$_temp0';
  }

  @override
  String get routeBooked =>
      'เที่ยวบิน รถไฟ และเรือ แสดงเป็นเส้นประตรง ไม่ใช่เส้นทางจริง';

  @override
  String get routeNoTransit =>
      'ไม่มีเส้นทางขนส่งสาธารณะในแอปนี้ ใช้ “นำทางด้วย” เพื่อดูเส้นทาง';

  @override
  String routeUnordered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count จุดยังไม่มีเวลา จึงไม่อยู่ในเส้นทาง',
    );
    return '$_temp0';
  }

  @override
  String get findLocations => 'ค้นหาตำแหน่ง';

  @override
  String get locateTitle => 'ค้นหาตำแหน่ง';

  @override
  String get locateIntro =>
      'สถานที่เหล่านี้มีแต่ชื่อ ไม่มีพิกัด จึงแสดงบนแผนที่ไม่ได้ ระบบจะค้นหาแต่ละชื่อทางออนไลน์ โดยแสดงผลที่ใกล้จุดหมายของทริปก่อน จะไม่มีการเปลี่ยนแปลงจนกว่าคุณจะเลือก';

  @override
  String locateProgress(int done, int total) {
    return 'ค้นหาแล้ว $done จาก $total…';
  }

  @override
  String locateUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ใช้ใน $count กิจกรรม',
    );
    return '$_temp0';
  }

  @override
  String get locatePlaceholder =>
      'ชื่อกว้างเกินไป: โปรดเลือกสถานที่ที่แน่นอนเอง';

  @override
  String locateNoMatch(String query) {
    return 'ไม่พบ “$query” ลองชื่ออื่นหรือเลือกบนแผนที่';
  }

  @override
  String locateFar(int km) {
    return 'ห่างจากจุดหมาย $km กม.';
  }

  @override
  String get locateUse => 'ใช้ที่นี่';

  @override
  String get locateLocated => 'ระบุตำแหน่งแล้ว';

  @override
  String get locateSearchAgain => 'ค้นหาอีกครั้ง';

  @override
  String get locateSearch => 'ค้นหา';

  @override
  String get locateRefineHelp => 'เคล็ดลับ: ใส่ชื่อเมืองด้วย เช่น “中山路步行街 厦门”';

  @override
  String locateUseAll(int count) {
    return 'ใช้ผลที่เลือก ($count)';
  }

  @override
  String get locateAllDone => 'ทุกสถานที่ในแผนมีพิกัดแล้ว';

  @override
  String get pasteLocation => 'วางลิงก์หรือพิกัด';

  @override
  String get pasteLocationHint =>
      'ลิงก์ Google Maps, ลิงก์แชร์ (maps.app.goo.gl), โค้ดฝัง, “27.8124, 99.7048” หรือ Plus Code เช่น “RP63+XW2, Shangri-La”';

  @override
  String get pasteFromClipboard => 'วางจากคลิปบอร์ด';

  @override
  String get pasteFromChineseMap =>
      'คัดลอกจาก Google Maps, Amap หรือ Apple Maps';

  @override
  String get pasteFromChineseMapHelp =>
      'ในจีนแผ่นดินใหญ่ แผนที่เหล่านี้คลาดจาก GPS ซึ่ง WanderPlan จะแก้ให้ ปิดไว้หากพิกัดมาจาก GPS หรือ OpenStreetMap';

  @override
  String get pasteResolve => 'ใช้ตำแหน่งนี้';

  @override
  String get linkUnrecognized =>
      'ไม่รู้จัก วางลิงก์ Google Maps / Amap / Apple Maps, พิกัดเช่น “27.81, 99.70” หรือ Plus Code';

  @override
  String get linkShortFailed =>
      'เปิดลิงก์สั้นไม่ได้ (ออนไลน์อยู่ไหม?) เปิดใน Google Maps แล้วคัดลอกลิงก์เต็มหรือพิกัดแทน';

  @override
  String get linkPlusNeedsArea =>
      'Plus Code แบบสั้นต้องมีชื่อพื้นที่ด้วย เช่น “RP63+XW2, Shangri-La”';

  @override
  String get linkCentreOnly =>
      'ลิงก์นี้มีแค่จุดกึ่งกลางแผนที่ หมุดอาจคลาดเล็กน้อย โปรดตรวจสอบ';

  @override
  String get linkConverted =>
      'แปลงจากพิกัดเลื่อนของแผนที่จีน (GCJ-02) เป็นพิกัด GPS แล้ว';

  @override
  String sourceLink(String provider) {
    return 'พิกัดจากลิงก์ $provider';
  }

  @override
  String get sourcePlusCode => 'พิกัดจาก Plus Code';

  @override
  String get sourceCoordinates => 'คุณป้อนพิกัดเอง';

  @override
  String get pasteLink => 'วางลิงก์';

  @override
  String get modeTransit => 'รถไฟ / รถไฟฟ้า / รถบัส';

  @override
  String get dayStart => 'จุดเริ่ม';

  @override
  String get dayEnd => 'จุดสิ้นสุด';

  @override
  String get dayStartTitle => 'วันนี้เริ่มที่ไหน?';

  @override
  String get dayEndTitle => 'วันนี้จบที่ไหน?';

  @override
  String get dayAnchorNotSet => 'ยังไม่กำหนด (คืนนั้นไม่มีโรงแรม)';

  @override
  String get dayAnchorHotel => 'โรงแรม';

  @override
  String get dayAnchorUseHotel => 'ใช้โรงแรม (ค่าเริ่มต้น)';

  @override
  String get dayLegs => 'การเดินทางระหว่างจุด';

  @override
  String get legTitle => 'ไปอย่างไร?';

  @override
  String legDefault(String mode) {
    return 'ค่าเริ่มต้นของวัน ($mode)';
  }

  @override
  String get legMinutes => 'เวลาเดินทางของคุณ (ไม่บังคับ)';

  @override
  String get legMinutesHelp => 'เว้นว่างเพื่อใช้เวลาโดยทั่วไปของเส้นทาง';

  @override
  String get legTransitHelp =>
      'ไม่คำนวณเวลารถไฟ รถไฟฟ้า และรถบัส (ไม่มีข้อมูลตารางเวลา) ใส่เวลาจากตารางหรือแอปแผนที่';

  @override
  String get legTransitNoTime => 'รถไฟ/รถไฟฟ้า/รถบัส · ใส่เวลาของคุณ';

  @override
  String get legUndecided => 'ยังไม่ได้เลือกการเดินทาง';

  @override
  String get legNoRoute => 'ไม่มีเส้นทาง (ยังไม่ยืนยัน)';

  @override
  String get legYourEstimate => 'ค่าประมาณของคุณ';

  @override
  String legTooShort(int minutes) {
    return 'ขาดอีก $minutes นาทีก่อนกิจกรรมถัดไป';
  }

  @override
  String get routeTransitNote =>
      'เส้นประสีน้ำเงินคือช่วงรถไฟ/รถไฟฟ้า/รถบัส: เส้นตรง ใช้เวลาที่คุณใส่';

  @override
  String get optimizeOrder => 'จัดลำดับให้ดีที่สุด';

  @override
  String get optimizeNeedsTwo =>
      'ต้องมีอย่างน้อย 2 สถานที่ที่มีตำแหน่ง ไม่ล็อก และยังไม่จอง';

  @override
  String get optimizeTitle => 'ลำดับที่แนะนำ';

  @override
  String optimizeSaves(String before, String after, String saved) {
    return 'เดินทาง $before → $after (ประหยัด $saved)';
  }

  @override
  String optimizeAlreadyBest(String travel) {
    return 'ลำดับของคุณสั้นที่สุดแล้ว (เดินทาง $travel)';
  }

  @override
  String optimizeRouted(String mode) {
    return 'อิงเส้นทาง$mode เวลาโดยทั่วไป ไม่ใช่สภาพจราจรจริง';
  }

  @override
  String optimizeEstimated(String mode) {
    return 'ไม่มีข้อมูลเส้นทาง: ประมาณจากระยะทางเส้นตรง ($mode)';
  }

  @override
  String get optimizeDayStart => 'วันเริ่มเวลา';

  @override
  String optimizeTravel(String time) {
    return 'เดินทาง $time';
  }

  @override
  String optimizeWait(String time) {
    return 'รอเปิด $time';
  }

  @override
  String get optimizeFixed => 'คงที่';

  @override
  String get optimizeAssumed => 'ไม่มีเวลา: ถือว่า 1 ชม.';

  @override
  String get optimizeClosed => 'ปิดวันนั้น';

  @override
  String get optimizeOutsideHours => 'นอกเวลาทำการ';

  @override
  String optimizeLate(int minutes) {
    return 'สาย $minutes นาที';
  }

  @override
  String get optimizeKeepsFixed =>
      'รายการที่ล็อก จองแล้ว และการเดินทางคงเวลาเดิม จะย้ายเฉพาะสถานที่ที่ยังไม่จอง';

  @override
  String get optimizeApply => 'ใช้';

  @override
  String optimizeApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'อัปเดต $count กิจกรรมแล้ว',
    );
    return '$_temp0';
  }

  @override
  String get gettingHere => 'การเดินทางมาที่นี่';

  @override
  String get gettingHereDefault => 'ค่าเริ่มต้นของวัน';

  @override
  String get openingHours => 'เวลาทำการ';

  @override
  String get openingHoursKnown => 'มีเวลาทำการ';

  @override
  String get openingHoursHelp =>
      'ตรวจสอบจากเว็บไซต์ทางการ WanderPlan ใช้เพื่อเตือนและจัดลำดับ';

  @override
  String get opens => 'เปิด';

  @override
  String get closes => 'ปิด';

  @override
  String get closesNextDay => 'ปิดหลังเที่ยงคืน';

  @override
  String get closedOn => 'ปิดทุกวัน';

  @override
  String get closedThatDay => 'วันนี้ปิด!';

  @override
  String get reservation => 'การจอง';

  @override
  String get reservationRequired => 'ต้องจองหรือซื้อตั๋วล่วงหน้า';

  @override
  String get reservationVia => 'จองที่ไหน / อย่างไร';

  @override
  String get reservationViaHint =>
      'เช่น บัญชี WeChat ทางการ, แอป Trip.com, เว็บไซต์';

  @override
  String get bookAheadDays => 'จองล่วงหน้ากี่วัน?';

  @override
  String get daysUnit => 'วัน';

  @override
  String bookByDate(String date) {
    return 'จองภายใน $date';
  }

  @override
  String get remindToBook => 'เตือนฉันในวันนั้น';

  @override
  String get remindToBookHelp =>
      'แจ้งเตือนเวลา 09:00 (เวลาทริป) ในวันที่ต้องจอง';

  @override
  String get remindPermissionDenied =>
      'การแจ้งเตือนของ WanderPlan ปิดอยู่ อนุญาตในการตั้งค่าระบบเพื่อรับการเตือน';

  @override
  String get reminderTitle => 'ถึงเวลาจองแล้ว';

  @override
  String reminderBody(String title, String date, String via) {
    return 'จอง “$title” สำหรับ $date $via';
  }

  @override
  String issueTightTravelOwn(String a, String b, int minutes, int needed) {
    return '“$a” → “$b”: มีแค่ $minutes นาที แต่คุณเผื่อไว้ $needed นาที';
  }

  @override
  String issueClosedOnDay(String title) {
    return '“$title” ปิดในวันนี้';
  }

  @override
  String issueOutsideOpeningHours(String title) {
    return '“$title” อยู่นอกเวลาทำการ';
  }

  @override
  String issueBookingNeeded(String title) {
    return '“$title” ยังต้องจอง';
  }

  @override
  String issueBookBy(String title, String date) {
    return 'จอง “$title” ภายใน $date';
  }

  @override
  String get flightUpdates => 'อัปเดตเที่ยวบิน';

  @override
  String get flightUpdatesSubtitle => 'สถานะสดจากเซิร์ฟเวอร์ WanderPlan ของคุณ';

  @override
  String get flightPrivacyTitle => 'ความเป็นส่วนตัว';

  @override
  String get actionRetry => 'ลองอีกครั้ง';

  @override
  String get flightUpdatesOff => 'ใช้งานไม่ได้ในตอนนี้';

  @override
  String get flightServerChecking => 'กำลังเชื่อมต่อ…';

  @override
  String get flightServerIntro =>
      'สถานะเที่ยวบินสดมาจากเซิร์ฟเวอร์ WanderPlan ซึ่งตรวจแต่ละเที่ยวบินครั้งเดียวสำหรับทุกคนและเก็บคีย์ข้อมูลไว้ โทรศัพท์แค่อ่านผล ไม่ต้องตั้งค่าอะไร';

  @override
  String get flightServerTitle => 'สถานะ';

  @override
  String flightServerConnectedAs(String who) {
    return 'เปิดอยู่ · ลงชื่อเข้าใช้เป็น $who';
  }

  @override
  String get flightServerPrivacy =>
      'ไม่มีคีย์ API ข้อมูลเที่ยวบินเก็บในโทรศัพท์ แอปลงชื่อเข้าใช้เซิร์ฟเวอร์ WanderPlan เองและเก็บการเข้าสู่ระบบไว้ในพวงกุญแจ (เฉพาะเครื่องนี้)';

  @override
  String get flightNotConnected => 'แอปเวอร์ชันนี้ยังไม่มีอัปเดตเที่ยวบินสด';

  @override
  String get flightSignInRejected =>
      'เซิร์ฟเวอร์ WanderPlan ไม่ยอมรับการลงชื่อเข้าใช้ ลองใหม่ภายหลัง';

  @override
  String get flightServerNoKey =>
      'เซิร์ฟเวอร์ WanderPlan ยังไม่ได้เปิดข้อมูลเที่ยวบินสด';

  @override
  String get flightNoDataYet =>
      'ยังไม่มีข้อมูล เซิร์ฟเวอร์จะตรวจเที่ยวบินนี้ตามกำหนด (ข้อมูลสดมีช่วงวันบิน)';

  @override
  String get flightStale => 'ตรวจครั้งล่าสุดไม่สำเร็จ แสดงข้อมูลล่าสุดที่มี';

  @override
  String get flightNeedsNumber =>
      'ใส่หมายเลขเที่ยวบิน (เช่น MU5103) เพื่อรับการอัปเดตสด';

  @override
  String get flightCheckNow => 'ตรวจเลย';

  @override
  String get flightNoChanges => 'ไม่มีการเปลี่ยนแปลงตั้งแต่ครั้งก่อน';

  @override
  String get flightQuotaReached =>
      'แผนข้อมูลเที่ยวบินของเซิร์ฟเวอร์ใช้คำขอเดือนนี้หมดแล้ว';

  @override
  String get flightNetwork =>
      'ตอนนี้เชื่อมต่อเซิร์ฟเวอร์ WanderPlan ไม่ได้ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';

  @override
  String get flightUnknownError => 'เซิร์ฟเวอร์ตอบกลับผิดปกติ ลองใหม่ภายหลัง';

  @override
  String get flightScheduled => 'ตามกำหนด';

  @override
  String get flightInAir => 'กำลังบิน';

  @override
  String get flightLanded => 'ลงจอดแล้ว';

  @override
  String get flightCancelled => 'ยกเลิก';

  @override
  String get flightIncident => 'เหตุขัดข้อง';

  @override
  String get flightDiverted => 'เปลี่ยนเส้นทาง';

  @override
  String get flightStatusUnknown => 'ไม่ทราบสถานะ';

  @override
  String flightDelayed(int minutes) {
    return 'ล่าช้า $minutes นาที';
  }

  @override
  String get flightDep => 'ออก';

  @override
  String get flightArr => 'ถึง';

  @override
  String flightTerminal(String t) {
    return 'อาคาร $t';
  }

  @override
  String flightGate(String g) {
    return 'ประตู $g';
  }

  @override
  String flightBelt(String b) {
    return 'สายพาน $b';
  }

  @override
  String flightChecked(String time) {
    return 'ตรวจเมื่อ $time · เวลาท้องถิ่นของแต่ละสนามบิน';
  }

  @override
  String flightNotifyTitle(String flight) {
    return '$flight: อัปเดตเที่ยวบิน';
  }

  @override
  String flightChangeStatus(String status) {
    return 'ตอนนี้: $status';
  }

  @override
  String flightChangeDeparture(String from, String to) {
    return 'ออก $from → $to';
  }

  @override
  String flightChangeArrival(String from, String to) {
    return 'ถึง $from → $to';
  }

  @override
  String flightChangeDepTerminal(String t) {
    return 'อาคารขาออก $t';
  }

  @override
  String flightChangeDepGate(String g) {
    return 'ประตู $g';
  }

  @override
  String flightChangeArrTerminal(String t) {
    return 'อาคารขาเข้า $t';
  }

  @override
  String flightChangeArrGate(String g) {
    return 'ประตูขาเข้า $g';
  }

  @override
  String flightChangeBaggage(String b) {
    return 'สายพานกระเป๋า $b';
  }

  @override
  String get navigateWith => 'นำทางด้วย';

  @override
  String get openGoogleMaps => 'Google Maps';

  @override
  String get openAppleMaps => 'Apple Maps';

  @override
  String get openAmap => 'Amap (Gaode)';

  @override
  String get openFailed => 'เปิดแอปแผนที่ไม่ได้';

  @override
  String get chooseLocation => 'เลือกตำแหน่ง';

  @override
  String get pickHint => 'แตะแผนที่เพื่อปักหมุด หรือค้นหาสถานที่';

  @override
  String get useThisPlace => 'ใช้ตำแหน่งนี้';

  @override
  String get searchPlaces => 'ค้นหาสถานที่ (ออนไลน์)';

  @override
  String searchFailed(String error) {
    return 'ค้นหาไม่ได้: $error';
  }

  @override
  String get noResults => 'ไม่พบสถานที่';

  @override
  String get placeName => 'ชื่อสถานที่';

  @override
  String get removePin => 'ลบหมุด';

  @override
  String get budgetPlanned => 'ตามแผน';

  @override
  String get budgetSpent => 'ใช้ไปแล้ว';

  @override
  String get budgetRemaining => 'คงเหลือ';

  @override
  String get budgetLimit => 'งบประมาณ';

  @override
  String get budgetOverview => 'ภาพรวม';

  @override
  String get budgetExpenses => 'ค่าใช้จ่าย';

  @override
  String get budgetRates => 'อัตราแลกเปลี่ยน';

  @override
  String get byCategory => 'ตามหมวดหมู่';

  @override
  String get byDay => 'ตามวัน';

  @override
  String get plannedVsActual => 'แผนเทียบกับจริง';

  @override
  String get variance => 'ส่วนต่าง';

  @override
  String perPersonSpent(String amount) {
    return 'ใช้ไปคนละ $amount';
  }

  @override
  String unpaidPlanned(String amount) {
    return 'ยังต้องจ่ายหรือจองอีก $amount';
  }

  @override
  String get addExpense => 'เพิ่มค่าใช้จ่าย';

  @override
  String get editExpense => 'แก้ไขค่าใช้จ่าย';

  @override
  String get expenseTitle => 'ค่าอะไร';

  @override
  String get fieldAmount => 'จำนวนเงิน';

  @override
  String get fieldCategory => 'หมวดหมู่';

  @override
  String get expensePlanned => 'ตามแผน';

  @override
  String get expenseActual => 'จ่ายจริง';

  @override
  String get expensePaid => 'จ่ายแล้ว';

  @override
  String get expenseUnpaid => 'ยังไม่จ่าย';

  @override
  String get expenseShared => 'หารกันทุกคน';

  @override
  String get linkedActivity => 'กิจกรรมที่เกี่ยวข้อง';

  @override
  String get noneOption => 'ไม่มี';

  @override
  String get expenseDeleted => 'ลบค่าใช้จ่ายแล้ว';

  @override
  String get noExpenses =>
      'ยังไม่มีค่าใช้จ่าย บันทึกสิ่งที่ใช้จ่ายระหว่างทริป หรือค่าใช้จ่ายที่วางแผนไว้นอกกำหนดการ';

  @override
  String get fromItinerary => 'จากกำหนดการ';

  @override
  String get budgetEmpty =>
      'เพิ่มค่าใช้จ่ายให้กิจกรรมหรือค่าใช้จ่ายที่วางแผนไว้ เพื่อดูแผนที่นี่';

  @override
  String get warnNoCurrency => 'กำหนดสกุลเงินหลักของทริปเพื่อติดตามงบประมาณ';

  @override
  String warnMissingRates(String currencies) {
    return 'ไม่มีอัตราแลกเปลี่ยนของ $currencies จำนวนเงินเหล่านั้นยังไม่ถูกนับ';
  }

  @override
  String warnOverPlanned(String amount) {
    return 'แผนเกินงบประมาณ $amount';
  }

  @override
  String warnOverActual(String amount) {
    return 'ใช้จ่ายเกินงบประมาณ $amount';
  }

  @override
  String get warnNearLimit => 'แผนใช้งบประมาณเกิน 90% แล้ว';

  @override
  String rateLabel(String currency, String base) {
    return '1 $currency = ? $base';
  }

  @override
  String get rateManual => 'กรอกเอง · ยังไม่ยืนยัน';

  @override
  String rateFrom(String source, String date) {
    return 'จาก $source · $date';
  }

  @override
  String get rateMissing => 'ยังไม่มีอัตรา';

  @override
  String get refreshRates => 'ดึงอัตราล่าสุด (ออนไลน์)';

  @override
  String get ratesUpdated => 'อัปเดตอัตราแล้ว';

  @override
  String ratesUnsupported(String currencies) {
    return 'ไม่มีข้อมูลออนไลน์: $currencies โปรดกรอกเอง';
  }

  @override
  String ratesFailed(String error) {
    return 'ดึงอัตราไม่ได้: $error';
  }

  @override
  String get addRate => 'เพิ่มอัตรา';

  @override
  String get rateInvalid => 'กรอกตัวเลขที่มากกว่า 0';

  @override
  String ratesHelp(String base) {
    return 'จำนวนเงินสกุลอื่นจะถูกแปลงเป็น $base ด้วยอัตราเหล่านี้';
  }

  @override
  String get amountInvalid => 'กรอกจำนวนเงินตั้งแต่ 0 ขึ้นไป';

  @override
  String get catFlights => 'ตั๋วเครื่องบิน';

  @override
  String get catTrains => 'รถไฟ';

  @override
  String get catBuses => 'รถบัสและเรือ';

  @override
  String get catTaxis => 'แท็กซี่และการเดินทางในเมือง';

  @override
  String get catHotels => 'ที่พัก';

  @override
  String get catFood => 'อาหาร';

  @override
  String get catAttractions => 'สถานที่ท่องเที่ยว';

  @override
  String get catActivities => 'กิจกรรม';

  @override
  String get catInternet => 'อินเทอร์เน็ตและซิม';

  @override
  String get catInsurance => 'ประกัน';

  @override
  String get catShopping => 'ช้อปปิ้ง';

  @override
  String get catEmergency => 'เงินสำรองฉุกเฉิน';

  @override
  String get catMisc => 'เบ็ดเตล็ด';

  @override
  String get kindTransport => 'การเดินทาง (ยังไม่เลือกวิธี)';

  @override
  String get catTransport => 'การเดินทางอื่น ๆ';

  @override
  String get timeTbd => 'ยังไม่กำหนดเวลา';

  @override
  String get timeTbdToggle => 'ยังไม่กำหนดเวลา';

  @override
  String get timeTbdHelp =>
      'ใช้เมื่อยังไม่ยืนยันเวลา แอปจะไม่เดาเวลาให้ และวันนั้นจะแสดง “ข้อมูลไม่พอ” จนกว่าจะกำหนดเวลา';

  @override
  String issueTimeNotSet(String titles) {
    return 'ยังไม่ได้กำหนดเวลา: $titles';
  }

  @override
  String get notScheduled => 'ยังไม่ได้จัดเวลา';

  @override
  String importInvalidDetail(String detail) {
    return 'นำเข้าไม่ได้: $detail';
  }

  @override
  String get importHow => 'ต้องการนำเข้าแบบไหน?';

  @override
  String get importChooseFile => 'เลือกไฟล์';

  @override
  String get importChooseFileHelp =>
      'ไฟล์ .wanderplan จากเพื่อน หรือไฟล์ .json';

  @override
  String get importPaste => 'วางข้อความ';

  @override
  String get importPasteHelp =>
      'วาง JSON ของทริปที่คัดลอกจาก ChatGPT, โน้ต, อีเมล…';

  @override
  String get importPasteHint => 'วาง JSON ของทริปที่นี่';

  @override
  String get clipboardEmpty => 'คลิปบอร์ดว่างเปล่า';

  @override
  String get actionClear => 'ล้าง';

  @override
  String get importAction => 'นำเข้า';

  @override
  String get importFormatHelp => 'คู่มือรูปแบบ: docs/IMPORT_FORMAT.md';

  @override
  String get language => 'ภาษา';

  @override
  String get languageSystem => 'ตามระบบ';

  @override
  String get privacyTitle => 'ข้อมูลและความเป็นส่วนตัว';

  @override
  String get privacyBody =>
      'WanderPlan เก็บทริปและรูปภาพไว้ในอุปกรณ์นี้เท่านั้น ไม่ต้องสร้างบัญชี';

  @override
  String get deleteAllData => 'ลบข้อมูลทั้งหมด';

  @override
  String get deleteAllDataBody =>
      'ทริป รูปภาพ และการตั้งค่าทั้งหมดในอุปกรณ์นี้จะถูกลบอย่างถาวร';

  @override
  String get allDataDeleted => 'ลบข้อมูลทั้งหมดแล้ว';

  @override
  String get atlasEyebrow => 'สมุดการเดินทางของคุณ';

  @override
  String get atlasSubtitle => 'แผน สถานที่ และวันเดินทางของคุณ';

  @override
  String atlasCollection(int count) {
    return 'ทริปในคอลเลกชันของคุณ $count ทริป';
  }

  @override
  String get atlasJourney => 'การเดินทาง';

  @override
  String get atlasFilters => 'กรองทริป';

  @override
  String get atlasBegin => 'เริ่มบทใหม่';

  @override
  String get atlasFooter => 'การเดินทางที่ดีเริ่มจากการวางแผนเล็กน้อย';

  @override
  String get atlasEdition => 'บันทึกการเดินทาง';

  @override
  String get atlasSigninHeadline => 'ที่ใหม่ ๆ\nที่รอให้คุณออกเดินทาง';
}
