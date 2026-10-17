// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'WanderPlan 旅行计划';

  @override
  String get tabHome => '首页';

  @override
  String get tabMap => '地图';

  @override
  String get tabTimeline => '行程';

  @override
  String get tabBudget => '预算';

  @override
  String get tabMore => '更多';

  @override
  String get searchTrips => '搜索旅行';

  @override
  String get searchTripsEmpty => '没有找到匹配的旅行。';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get myTrips => '我的旅行';

  @override
  String get createTrip => '创建新旅行';

  @override
  String get newTrip => '新旅行';

  @override
  String get editTrip => '编辑旅行';

  @override
  String get emptyTripsTitle => '还没有旅行';

  @override
  String get emptyTripsBody => '开始规划你的下一次旅程。只需一个标题即可创建，其他信息可以稍后补充。';

  @override
  String get emptyFilterBody => '没有符合此筛选条件的旅行。';

  @override
  String get filterAll => '全部';

  @override
  String get filterUpcoming => '即将出发';

  @override
  String get filterTraveling => '旅行中';

  @override
  String get filterCompleted => '已完成';

  @override
  String get filterArchived => '已归档';

  @override
  String get statusDreaming => '构想中';

  @override
  String get statusPlanning => '规划中';

  @override
  String get statusUpcoming => '即将出发';

  @override
  String get statusTraveling => '旅行中';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusArchived => '已归档';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionDuplicate => '复制';

  @override
  String get actionArchive => '归档';

  @override
  String get actionUnarchive => '取消归档';

  @override
  String get actionDelete => '删除';

  @override
  String get actionEditBanner => '编辑封面';

  @override
  String get actionReorder => '调整顺序';

  @override
  String get actionDone => '完成';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => '取消';

  @override
  String get duplicateSuffix => '（副本）';

  @override
  String get deleteTripTitle => '删除旅行？';

  @override
  String deleteTripBody(String title) {
    return '“$title”及其所有照片将被永久删除，且无法恢复。';
  }

  @override
  String get tripDuplicated => '已复制旅行';

  @override
  String get tripArchived => '已归档旅行';

  @override
  String get tripUnarchived => '已取消归档';

  @override
  String get tripDeleted => '已删除旅行';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get restoreNotYet => '备份与恢复功能尚未实现（计划在导入/导出阶段提供）。';

  @override
  String get datesUndecided => '日期未定';

  @override
  String get datesFlexible => '日期待定';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String travelersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位旅客',
    );
    return '$_temp0';
  }

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String unitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时',
    );
    return '$_temp0';
  }

  @override
  String unitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 天',
      zero: '今天出发',
    );
    return '$_temp0';
  }

  @override
  String countdownRemaining(String value) {
    return '还剩 $value';
  }

  @override
  String countdownDayOf(int day, int total) {
    return '第 $day 天 / 共 $total 天';
  }

  @override
  String get countdownCompleted => '旅行已完成';

  @override
  String get countdownNoDate => '设置日期后开始倒计时';

  @override
  String departsOn(String date) {
    return '$date 出发';
  }

  @override
  String departsOnAt(String date, String time) {
    return '$date $time 出发';
  }

  @override
  String get fieldTitle => '旅行标题';

  @override
  String get fieldTitleHint => '例如：京都之秋';

  @override
  String get titleRequired => '请输入标题';

  @override
  String get fieldDescription => '描述';

  @override
  String get optional => '可选';

  @override
  String get sectionCover => '封面图片';

  @override
  String get coverPick => '选择照片';

  @override
  String get coverCamera => '拍照';

  @override
  String get coverRemove => '移除';

  @override
  String get coverHint => '保存后可以裁剪并设置封面样式。';

  @override
  String get sectionDestinations => '目的地';

  @override
  String get fieldCountry => '国家';

  @override
  String get fieldCity => '城市';

  @override
  String get addDestination => '添加目的地';

  @override
  String get removeDestination => '移除目的地';

  @override
  String get mainDestination => '主要目的地';

  @override
  String get sectionDates => '日期';

  @override
  String get pickDates => '选择日期';

  @override
  String get clearDates => '清除日期';

  @override
  String get datesConfirmed => '日期已确定';

  @override
  String get datesConfirmedHelp => '日期仍可调整时请关闭。';

  @override
  String get departureTime => '出发时间';

  @override
  String get notSet => '未设置';

  @override
  String get fieldTimeZone => '时区';

  @override
  String get timeZoneHelp => '倒计时与日期按此时区计算。';

  @override
  String get searchTimeZone => '搜索时区';

  @override
  String get sectionDetails => '详情';

  @override
  String get fieldTravelers => '旅客人数';

  @override
  String get fieldCurrency => '主要货币';

  @override
  String get currencyInvalid => '请输入 3 位 ISO 货币代码，例如 CNY';

  @override
  String get fieldBudget => '总预算';

  @override
  String get budgetInvalid => '请输入正数';

  @override
  String get budgetNeedsCurrency => '请为预算选择货币';

  @override
  String get fieldTravelStyle => '旅行风格';

  @override
  String get fieldStage => '规划阶段';

  @override
  String get stageHelp => '“即将出发”“旅行中”“已完成”会根据日期自动设置。';

  @override
  String get styleRelaxed => '悠闲';

  @override
  String get styleBalanced => '均衡';

  @override
  String get stylePacked => '紧凑';

  @override
  String get styleBudget => '经济';

  @override
  String get styleComfort => '舒适';

  @override
  String get styleLuxury => '奢华';

  @override
  String get styleAdventure => '探险';

  @override
  String get styleFamily => '亲子';

  @override
  String get saveTripCreate => '创建旅行';

  @override
  String get saveTripChanges => '保存更改';

  @override
  String get discardChangesTitle => '放弃更改？';

  @override
  String get discard => '放弃';

  @override
  String get keepEditing => '继续编辑';

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get overview => '概览';

  @override
  String get budgetTitle => '预算';

  @override
  String get budgetNotSet => '未设置预算';

  @override
  String budgetPerPerson(String amount) {
    return '每人 $amount';
  }

  @override
  String get photosTitle => '照片';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片',
      zero: '暂无照片',
    );
    return '$_temp0';
  }

  @override
  String get openGallery => '打开相册';

  @override
  String get addPhoto => '添加照片';

  @override
  String get quickActions => '快捷操作';

  @override
  String get planningModules => '规划工具';

  @override
  String get notImplementedYet => '尚未实现';

  @override
  String get moduleMap => '打开地图';

  @override
  String get moduleAttraction => '添加景点';

  @override
  String get moduleItinerary => '编辑行程';

  @override
  String get moduleFlight => '添加航班';

  @override
  String get moduleTrain => '添加火车';

  @override
  String get moduleHotel => '添加酒店';

  @override
  String get moduleExpense => '添加支出';

  @override
  String get moduleBudget => '打开预算';

  @override
  String get moduleExport => '导出旅行';

  @override
  String get tripNotFound => '该旅行已不存在。';

  @override
  String get bannerEditorTitle => '编辑封面';

  @override
  String get bannerTabImage => '图片';

  @override
  String get bannerTabBackground => '背景';

  @override
  String get bannerTabText => '标题';

  @override
  String get bannerTabStyle => '样式';

  @override
  String get bannerFromDevice => '从设备上传';

  @override
  String get bannerFromTrip => '选择旅行照片';

  @override
  String get bannerNoTripPhotos => '该旅行还没有照片。';

  @override
  String get bannerAdjustHint => '拖动调整位置 · 双指或滑块缩放';

  @override
  String get bannerZoom => '缩放';

  @override
  String get bannerResetCrop => '重置裁剪';

  @override
  String get bannerRemoveImage => '改用纯色/渐变';

  @override
  String get bannerGradient => '渐变';

  @override
  String get bannerSolid => '纯色';

  @override
  String get bannerColorsBehindImage => '未使用照片时显示颜色背景。';

  @override
  String get bannerShowTitle => '在封面显示标题';

  @override
  String get bannerPlacement => '标题位置';

  @override
  String get placementTopLeft => '左上';

  @override
  String get placementCenter => '居中';

  @override
  String get placementBottomLeft => '左下';

  @override
  String get placementBottomCenter => '底部居中';

  @override
  String get bannerTextColor => '文字颜色';

  @override
  String get bannerStyleClassic => '经典';

  @override
  String get bannerStyleMinimal => '简约';

  @override
  String get bannerStyleBold => '醒目';

  @override
  String get bannerStyleFramed => '边框';

  @override
  String get galleryEmpty => '还没有照片，添加一些留住旅途回忆吧。';

  @override
  String get galleryFromDevice => '从设备';

  @override
  String get photoCaption => '说明';

  @override
  String get photoFavorite => '收藏';

  @override
  String get favoritesOnly => '仅显示收藏';

  @override
  String get setAsCover => '设为封面';

  @override
  String get coverUpdated => '封面已更新';

  @override
  String get deletePhotoTitle => '删除照片？';

  @override
  String get deletePhotoBody => '该照片将从此旅行及 WanderPlan 的存储中删除。';

  @override
  String get photoAccessError => '无法访问照片或相机，请在系统设置中检查权限。';

  @override
  String get selectTripFirst => '请先在首页打开一个旅行。';

  @override
  String get goToTrips => '前往我的旅行';

  @override
  String currentTrip(String title) {
    return '当前旅行：$title';
  }

  @override
  String get mapNotYet => '真实地图、地点搜索和路线显示计划在第 3 阶段实现，目前尚不可用。';

  @override
  String get timelineNotYet => '从早到晚的每日行程计划在第 2 阶段实现，目前尚不可用。';

  @override
  String get budgetNotYet => '支出记录与预算分析计划在第 2 阶段实现，目前尚不可用。';

  @override
  String get moreFlights => '航班';

  @override
  String get moreTransportation => '交通';

  @override
  String get moreHotels => '酒店';

  @override
  String get moreAttractions => '景点';

  @override
  String get moreScenarios => '行程方案';

  @override
  String get moreGallery => '相册';

  @override
  String get moreJournal => '旅行日记';

  @override
  String get moreAnalysis => '分析';

  @override
  String get moreImportExport => '导入 / 导出';

  @override
  String get moreSettings => '设置';

  @override
  String get noTripSelected => '未选择旅行';

  @override
  String get todosTitle => '出发前待办';

  @override
  String get todosShort => '待办';

  @override
  String todosProgress(int done, int total) {
    return '已完成 $done/$total';
  }

  @override
  String get todosEmpty => '清单还是空的。添加出发前需要完成的事项吧。';

  @override
  String get todosAllDone => '全部完成，准备出发！';

  @override
  String get todosNextUp => '接下来';

  @override
  String get todoAdd => '添加待办';

  @override
  String get todoEdit => '编辑待办';

  @override
  String get todoTitleField => '事项';

  @override
  String get todoNotes => '备注';

  @override
  String get todoCategory => '类别';

  @override
  String get todoDueDate => '截止日期';

  @override
  String get todoNoDueDate => '无截止日期';

  @override
  String todoDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后到期',
      one: '明天到期',
      zero: '今天到期',
    );
    return '$_temp0';
  }

  @override
  String todoOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已逾期 $count 天',
    );
    return '$_temp0';
  }

  @override
  String get todoAfterDeparture => '晚于出发日期';

  @override
  String get todoHideDone => '隐藏已完成';

  @override
  String get todoSuggestions => '添加常用事项';

  @override
  String get todoSuggestionsTitle => '常见出发前事项';

  @override
  String todoAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加 $count 项',
      zero: '添加',
    );
    return '$_temp0';
  }

  @override
  String get todoDeleted => '已删除待办';

  @override
  String get undo => '撤销';

  @override
  String get todoCatDocuments => '证件';

  @override
  String get todoCatBookings => '预订';

  @override
  String get todoCatPacking => '行李';

  @override
  String get todoCatHealth => '健康与保险';

  @override
  String get todoCatMoney => '钱与银行卡';

  @override
  String get todoCatConnectivity => '电话与网络';

  @override
  String get todoCatHome => '家中事务';

  @override
  String get todoCatOther => '其他';

  @override
  String get sugPassport => '检查护照/身份证有效期';

  @override
  String get sugEntryRequirements => '查询签证及入境要求';

  @override
  String get sugInsurance => '购买旅行保险';

  @override
  String get sugMedication => '准备药品和处方';

  @override
  String get sugConfirmStay => '确认住宿预订';

  @override
  String get sugCheckIn => '办理航班网上值机';

  @override
  String get sugAirportTransport => '规划前往机场或车站的交通';

  @override
  String get sugBankCards => '确认银行卡境外费用并通知银行';

  @override
  String get sugLocalCash => '准备少量当地货币';

  @override
  String get sugSimCard => '准备 SIM 卡、eSIM 或开通漫游';

  @override
  String get sugOfflineCopies => '离线保存车票和证件副本';

  @override
  String get sugChargers => '带上充电器和转换插头';

  @override
  String get sugHomeArrangements => '安排宠物、植物和信件';

  @override
  String get shareTrip => '分享给朋友';

  @override
  String get shareExplain =>
      '朋友会收到这份旅行的副本文件，在 WanderPlan →“我的旅行”→ ⋮ →“导入旅行”中打开即可。之后双方的修改不会同步。';

  @override
  String get shareIncludePhotos => '包含相册照片';

  @override
  String shareIncludePhotosHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片 · 文件会更大',
      zero: '没有可包含的照片',
    );
    return '$_temp0';
  }

  @override
  String get shareSend => '分享文件';

  @override
  String shareMessage(String title) {
    return '我的 WanderPlan 旅行“$title”。导入方法：WanderPlan →“我的旅行”→ ⋮ →“导入旅行”。';
  }

  @override
  String shareFailed(String error) {
    return '无法生成分享文件：$error';
  }

  @override
  String get importTrip => '导入旅行';

  @override
  String importSuccess(String title) {
    return '已导入“$title”';
  }

  @override
  String get importInvalid => '这不是 WanderPlan 旅行文件。';

  @override
  String get importTooNew => '该文件由更新版本的 WanderPlan 创建，请更新应用后再导入。';

  @override
  String homeSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共 $count 个旅行',
      zero: '下一站去哪儿？',
    );
    return '$_temp0';
  }

  @override
  String get kpiDuration => '天数';

  @override
  String get kpiStatus => '状态';

  @override
  String get soon => '即将推出';

  @override
  String get tripTools => '旅行工具';

  @override
  String get viewAll => '查看全部';

  @override
  String get addActivity => '添加活动';

  @override
  String get editActivity => '编辑活动';

  @override
  String get activityTitle => '标题';

  @override
  String get activityKind => '类型';

  @override
  String get kindSightseeing => '景点';

  @override
  String get kindFood => '餐饮';

  @override
  String get kindActivity => '活动';

  @override
  String get kindShopping => '购物';

  @override
  String get kindRest => '休息';

  @override
  String get kindFlight => '航班';

  @override
  String get kindTrain => '火车';

  @override
  String get kindBus => '巴士';

  @override
  String get kindTransfer => '出租车 / 地铁';

  @override
  String get kindFerry => '轮渡';

  @override
  String get kindHotel => '酒店';

  @override
  String get kindOther => '其他';

  @override
  String get fieldDate => '日期';

  @override
  String get fieldStart => '开始';

  @override
  String get fieldEnd => '结束';

  @override
  String get fieldEndDate => '结束日期';

  @override
  String get fieldCheckIn => '入住';

  @override
  String get fieldCheckOut => '退房';

  @override
  String get sameDay => '当天';

  @override
  String get fieldLocation => '地点';

  @override
  String get fieldFrom => '出发地';

  @override
  String get fieldTo => '目的地';

  @override
  String get pickOnMap => '在地图上选择';

  @override
  String get onMap => '已在地图上';

  @override
  String get notOnMap => '尚未标注在地图上';

  @override
  String get fieldCost => '预计费用';

  @override
  String get fieldBooking => '预订';

  @override
  String get bookingNotBooked => '未预订';

  @override
  String get bookingBooked => '已预订';

  @override
  String get bookingConfirmed => '已确认';

  @override
  String get bookingCancelled => '已取消';

  @override
  String get fieldProvider => '航空公司 / 运营商 / 酒店';

  @override
  String get fieldServiceNumber => '航班 / 车次';

  @override
  String get fieldBookingRef => '预订编号（私密）';

  @override
  String get fieldBookingUrl => '预订链接';

  @override
  String get fieldNotes => '备注';

  @override
  String get fieldLocked => '已锁定';

  @override
  String get lockedHelp => '锁定的项目为已确认预订，拖动时不会被移动。';

  @override
  String get fieldOptional => '可选';

  @override
  String get optionalHelp => '有时间再去，时间紧可跳过。';

  @override
  String get endBeforeStart => '结束时间必须晚于开始时间';

  @override
  String get deleteActivityTitle => '删除活动？';

  @override
  String get activityDeleted => '已删除活动';

  @override
  String get duplicateToNextDay => '复制到第二天';

  @override
  String get lockedCannotMove => '锁定的活动无法移动，请先解锁。';

  @override
  String get timelineEmptyDay => '这一天还没有安排。';

  @override
  String get timelineNoDays => '设置旅行日期或添加活动，开始按天规划。';

  @override
  String get viewList => '列表';

  @override
  String get viewGrid => '时间轴';

  @override
  String get dragHint => '长按色块拖动可调整时间 · 拖动底边可修改时长';

  @override
  String freeTime(String duration) {
    return '空闲 $duration';
  }

  @override
  String durationHm(int h, int m) {
    return '$h 小时 $m 分';
  }

  @override
  String durationH(int h) {
    return '$h 小时';
  }

  @override
  String durationM(int m) {
    return '$m 分钟';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 晚',
    );
    return '$_temp0';
  }

  @override
  String dayN(int n) {
    return '第 $n 天';
  }

  @override
  String get outsideTrip => '行程外';

  @override
  String get dayFeasible => '可行';

  @override
  String get dayTight => '紧凑';

  @override
  String get dayUnrealistic => '不现实';

  @override
  String get dayUnknown => '信息不足';

  @override
  String get dayEmpty => '空闲日';

  @override
  String issueOverlap(String a, String b, int minutes) {
    return '“$a”与“$b”重叠 $minutes 分钟';
  }

  @override
  String issueNoTravelTime(String a, String b) {
    return '从“$a”到“$b”没有预留交通时间';
  }

  @override
  String issueTightTravel(
    String a,
    String b,
    String km,
    int minutes,
    int needed,
  ) {
    return '“$a”→“$b” 直线距离 $km 公里，仅有 $minutes 分钟，建议预留约 $needed 分钟';
  }

  @override
  String issueDepartureBuffer(String b, int minutes, int needed) {
    return '“$b”前仅有 $minutes 分钟，建议至少预留 $needed 分钟赶到并办理手续';
  }

  @override
  String issueLongDay(String hours) {
    return '行程很满：活动共 $hours 小时';
  }

  @override
  String issueEarlyAndLate(String hours) {
    return '早出晚归（共 $hours 小时）';
  }

  @override
  String get issueNoMealBreak => '午餐时段没有安排用餐或休息';

  @override
  String get issueLateFinish => '结束时间晚于 23:00';

  @override
  String get issueMissingAccommodation => '当晚尚未安排住宿';

  @override
  String issueOverlappingStays(String titles) {
    return '同一晚有两处住宿：$titles';
  }

  @override
  String issueTransportNotBooked(String titles) {
    return '尚未预订：$titles';
  }

  @override
  String issueOutsideTripDates(String titles) {
    return '超出旅行日期：$titles';
  }

  @override
  String get feasibilityNote =>
      '检查基于经验规则（直线距离按约 25 公里/小时估算，航班前 2 小时，火车前 30 分钟），仅为估算，并非实时路线。';

  @override
  String get bookingsTitle => '预订';

  @override
  String get bookingsEmpty => '还没有航班、火车或酒店。';

  @override
  String get bookingsTransport => '交通';

  @override
  String get bookingsStays => '住宿';

  @override
  String get nextUp => '接下来';

  @override
  String get planCheck => '行程检查';

  @override
  String daysNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天需要注意',
    );
    return '$_temp0';
  }

  @override
  String get allDaysOk => '所有已安排的日子看起来都可行';

  @override
  String get noActivitiesYet => '尚未安排活动';

  @override
  String activitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项活动',
    );
    return '$_temp0';
  }

  @override
  String get mapAllDays => '全部日期';

  @override
  String mapNoPins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项活动尚未标注位置',
    );
    return '$_temp0';
  }

  @override
  String get mapOnlineNote => '地图与地点搜索需要联网。';

  @override
  String get mapEmpty => '地图上还没有内容。可以搜索地点、探索附近，或编辑活动并使用“在地图上选择”。';

  @override
  String get fitAll => '显示全部';

  @override
  String get placeAttraction => '景点';

  @override
  String get placeRestaurant => '餐厅';

  @override
  String get placeHotel => '酒店';

  @override
  String get placeAirport => '机场';

  @override
  String get placeRailwayStation => '火车站';

  @override
  String get placeBusStation => '汽车站';

  @override
  String get placeOther => '其他';

  @override
  String get modeWalking => '步行';

  @override
  String get modeCycling => '骑行';

  @override
  String get modeDriving => '驾车 / 打车';

  @override
  String get mapProvider => '地图服务';

  @override
  String get providerAuto => '自动';

  @override
  String get providerAutoHelp => '中国大陆使用高德地图，其他地区使用 OpenStreetMap';

  @override
  String get providerOsm => 'OpenStreetMap';

  @override
  String get providerAmap => '高德地图';

  @override
  String get amapNoKey => '高德搜索与路线需要高德 Key，当前使用 OpenStreetMap 的搜索与路线。';

  @override
  String get savedPlaces => '收藏的地点';

  @override
  String get savedPlacesEmpty => '还没有收藏的地点。可以搜索、探索附近，或长按地图添加。';

  @override
  String get savePlace => '收藏地点';

  @override
  String get removePlace => '移除';

  @override
  String get placeSaved => '已收藏到此旅行';

  @override
  String get placeRemoved => '已移除地点';

  @override
  String get addToDay => '加入某天行程';

  @override
  String get chooseDay => '选择日期';

  @override
  String addedToDay(String date) {
    return '已加入 $date · 未设定时间';
  }

  @override
  String plannedOn(String dates) {
    return '已在行程中：$dates';
  }

  @override
  String get notPlanned => '尚未加入行程';

  @override
  String sourceSearch(String provider) {
    return '坐标来自 $provider 搜索';
  }

  @override
  String get sourcePinned => '由你在地图上标注';

  @override
  String get sourceImported => '坐标来自导入文件';

  @override
  String get mapPinnedPlace => '标注的地点';

  @override
  String get mapLongPressHint => '长按地图可标注地点';

  @override
  String get nearbyEmpty => '此区域附近未找到结果';

  @override
  String get filterMarkers => '筛选标记';

  @override
  String get layerPlan => '行程';

  @override
  String get layerResults => '搜索与附近结果';

  @override
  String get myLocation => '我的位置';

  @override
  String get locationOff => '定位服务已关闭';

  @override
  String get locationDenied => '未获得定位权限';

  @override
  String get locationDeniedForever => '定位权限已被禁止，请在系统设置中允许。';

  @override
  String get locationUnavailable => '无法获取你的位置';

  @override
  String get routeLoading => '正在规划路线…';

  @override
  String routeTotal(String distance, String duration) {
    return '$distance · 约 $duration';
  }

  @override
  String routeEstimateNote(String provider) {
    return '道路路线：$provider。时间为一般估算，不含实时路况或班次。';
  }

  @override
  String routeUnverified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 段没有道路路线：显示为直线，未经验证',
    );
    return '$_temp0';
  }

  @override
  String get routeBooked => '航班、火车和轮渡以点线直连表示，并非实际路径。';

  @override
  String get routeNoTransit => '此处不提供公共交通路线；请使用“导航”打开地图应用查看。';

  @override
  String routeUnordered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个地点尚未设定时间，未纳入路线',
    );
    return '$_temp0';
  }

  @override
  String get findLocations => '查找位置';

  @override
  String get locateTitle => '查找位置';

  @override
  String get locateIntro =>
      '这些地点只有名称、没有坐标，因此无法显示在地图上。系统会在线搜索每个名称，并优先显示靠近旅行目的地的结果。在你选择之前不会做任何更改。';

  @override
  String locateProgress(int done, int total) {
    return '已搜索 $done/$total…';
  }

  @override
  String locateUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项活动使用',
    );
    return '$_temp0';
  }

  @override
  String get locatePlaceholder => '名称较笼统：请自行选择确切地点';

  @override
  String locateNoMatch(String query) {
    return '未找到“$query”。可换个名称搜索，或在地图上选择。';
  }

  @override
  String locateFar(int km) {
    return '距离旅行目的地 $km 公里';
  }

  @override
  String get locateUse => '使用此地点';

  @override
  String get locateLocated => '已定位';

  @override
  String get locateSearchAgain => '重新搜索';

  @override
  String get locateSearch => '搜索';

  @override
  String get locateRefineHelp => '提示：加上城市名，例如“中山路步行街 厦门”';

  @override
  String locateUseAll(int count) {
    return '使用已选结果（$count）';
  }

  @override
  String get locateAllDone => '行程中的所有地点都已有坐标。';

  @override
  String get pasteLocation => '粘贴链接或坐标';

  @override
  String get pasteLocationHint =>
      'Google 地图链接、分享链接（maps.app.goo.gl）、嵌入代码、“27.8124, 99.7048”或 Plus Code（如“RP63+XW2, 香格里拉”）';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get pasteFromChineseMap => '复制自 Google 地图、高德或苹果地图';

  @override
  String get pasteFromChineseMapHelp =>
      '这些地图在中国大陆与 GPS 存在偏移，WanderPlan 会自动校正。若坐标来自 GPS 或 OpenStreetMap 请关闭。';

  @override
  String get pasteResolve => '使用此位置';

  @override
  String get linkUnrecognized =>
      '无法识别。请粘贴 Google 地图 / 高德 / 苹果地图链接、类似“27.81, 99.70”的坐标或 Plus Code。';

  @override
  String get linkShortFailed => '无法打开短链接（是否已联网？）。请在 Google 地图中打开并复制完整链接或坐标。';

  @override
  String get linkPlusNeedsArea => '此短 Plus Code 需要附带地区，例如“RP63+XW2, 香格里拉”。';

  @override
  String get linkCentreOnly => '此链接只包含地图中心点，图钉可能略有偏差，请核对。';

  @override
  String get linkConverted => '已将中国地图偏移坐标（GCJ-02）转换为 GPS 坐标。';

  @override
  String sourceLink(String provider) {
    return '坐标来自 $provider 链接';
  }

  @override
  String get sourcePlusCode => '坐标来自 Plus Code';

  @override
  String get sourceCoordinates => '坐标由你输入';

  @override
  String get pasteLink => '粘贴链接';

  @override
  String get modeTransit => '火车 / 地铁 / 公交';

  @override
  String get dayStart => '起点';

  @override
  String get dayEnd => '终点';

  @override
  String get dayStartTitle => '这一天从哪里出发？';

  @override
  String get dayEndTitle => '这一天在哪里结束？';

  @override
  String get dayAnchorNotSet => '未设置（当晚没有酒店）';

  @override
  String get dayAnchorHotel => '酒店';

  @override
  String get dayAnchorUseHotel => '使用酒店（默认）';

  @override
  String get dayLegs => '各站之间的交通';

  @override
  String get legTitle => '怎么过去？';

  @override
  String legDefault(String mode) {
    return '当天默认（$mode）';
  }

  @override
  String get legMinutes => '你的预计交通时间（可选）';

  @override
  String get legMinutesHelp => '留空则使用路线的一般用时。';

  @override
  String get legTransitHelp => '火车、地铁和公交的时间不会自动计算（没有时刻表数据）。请填写时刻表或地图应用中的时间。';

  @override
  String get legTransitNoTime => '火车/地铁/公交 · 请填写时间';

  @override
  String get legUndecided => '交通方式未定';

  @override
  String get legNoRoute => '无路线（未验证）';

  @override
  String get legYourEstimate => '你的估计';

  @override
  String legTooShort(int minutes) {
    return '距下一项开始还差 $minutes 分钟';
  }

  @override
  String get routeTransitNote => '蓝色虚线为火车/地铁/公交段：直线示意，时间为你填写的。';

  @override
  String get optimizeOrder => '优化顺序';

  @override
  String get optimizeNeedsTwo => '需要至少 2 个有位置、未锁定且未预订的地点。';

  @override
  String get optimizeTitle => '建议顺序';

  @override
  String optimizeSaves(String before, String after, String saved) {
    return '交通 $before → $after（节省 $saved）';
  }

  @override
  String optimizeAlreadyBest(String travel) {
    return '你的顺序已经是最短的（交通共 $travel）。';
  }

  @override
  String optimizeRouted(String mode) {
    return '基于$mode路线；为一般用时，不含实时路况。';
  }

  @override
  String optimizeEstimated(String mode) {
    return '无路线数据：按直线距离估算（$mode）。';
  }

  @override
  String get optimizeDayStart => '当天开始时间';

  @override
  String optimizeTravel(String time) {
    return '交通 $time';
  }

  @override
  String optimizeWait(String time) {
    return '等待开门 $time';
  }

  @override
  String get optimizeFixed => '固定';

  @override
  String get optimizeAssumed => '未设时间：按 1 小时计';

  @override
  String get optimizeClosed => '当天不开放';

  @override
  String get optimizeOutsideHours => '不在开放时间内';

  @override
  String optimizeLate(int minutes) {
    return '晚到 $minutes 分钟';
  }

  @override
  String get optimizeKeepsFixed => '已锁定、已预订和交通项目保持原时间，只移动未预订的地点。';

  @override
  String get optimizeApply => '应用';

  @override
  String optimizeApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已更新 $count 项活动',
    );
    return '$_temp0';
  }

  @override
  String get gettingHere => '如何到达';

  @override
  String get gettingHereDefault => '当天默认';

  @override
  String get openingHours => '开放时间';

  @override
  String get openingHoursKnown => '有开放时间';

  @override
  String get openingHoursHelp => '请以官方信息为准；WanderPlan 会据此提醒并安排顺序。';

  @override
  String get opens => '开门';

  @override
  String get closes => '关门';

  @override
  String get closesNextDay => '次日关门';

  @override
  String get closedOn => '休息日';

  @override
  String get closedThatDay => '这一天不开放！';

  @override
  String get reservation => '预约';

  @override
  String get reservationRequired => '需要提前预约或购票';

  @override
  String get reservationVia => '在哪里 / 如何预约';

  @override
  String get reservationViaHint => '如：官方微信公众号、携程 App、官网';

  @override
  String get bookAheadDays => '提前几天预约？';

  @override
  String get daysUnit => '天';

  @override
  String bookByDate(String date) {
    return '请在 $date 前预约';
  }

  @override
  String get remindToBook => '当天提醒我';

  @override
  String get remindToBookHelp => '在预约截止日（旅行当地时间）09:00 发送通知。';

  @override
  String get remindPermissionDenied => 'WanderPlan 的通知已关闭。请在系统设置中允许以接收提醒。';

  @override
  String get reminderTitle => '该预约了';

  @override
  String reminderBody(String title, String date, String via) {
    return '请预约“$title”（$date）。$via';
  }

  @override
  String issueTightTravelOwn(String a, String b, int minutes, int needed) {
    return '“$a”→“$b”：只有 $minutes 分钟，但你预计需要 $needed 分钟';
  }

  @override
  String issueClosedOnDay(String title) {
    return '“$title”这一天不开放';
  }

  @override
  String issueOutsideOpeningHours(String title) {
    return '“$title”的安排不在开放时间内';
  }

  @override
  String issueBookingNeeded(String title) {
    return '“$title”仍需预约';
  }

  @override
  String issueBookBy(String title, String date) {
    return '请在 $date 前预约“$title”';
  }

  @override
  String get flightUpdates => '航班动态';

  @override
  String get flightUpdatesSubtitle => '来自你的 WanderPlan 服务器的实时动态';

  @override
  String get flightPrivacyTitle => '隐私';

  @override
  String get actionRetry => '重试';

  @override
  String get flightUpdatesOff => '暂时无法使用';

  @override
  String get flightServerChecking => '正在连接…';

  @override
  String get flightServerIntro =>
      '航班实时动态来自 WanderPlan 服务器。服务器为所有人统一检查每个航班并保管数据 Key；手机只读取结果，无需任何设置。';

  @override
  String get flightServerTitle => '状态';

  @override
  String flightServerConnectedAs(String who) {
    return '已开启 · 登录为 $who';
  }

  @override
  String get flightServerPrivacy =>
      '手机上不保存任何航班数据 API Key。应用会自动登录 WanderPlan 服务器，登录信息保存在钥匙串中（仅限本机）。';

  @override
  String get flightNotConnected => '此版本的应用暂不提供航班实时动态。';

  @override
  String get flightSignInRejected => 'WanderPlan 服务器未接受登录，请稍后再试。';

  @override
  String get flightServerNoKey => 'WanderPlan 服务器尚未开启航班实时数据。';

  @override
  String get flightNoDataYet => '暂无数据。服务器会按计划检查此航班（实时数据通常在航班当天前后出现）。';

  @override
  String get flightStale => '上次检查失败，显示最后一次的数据';

  @override
  String get flightNeedsNumber => '填写航班号（如 MU5103）即可获取实时动态。';

  @override
  String get flightCheckNow => '立即检查';

  @override
  String get flightNoChanges => '与上次检查相比没有变化';

  @override
  String get flightQuotaReached => '服务器的航班数据方案本月请求已用完。';

  @override
  String get flightNetwork => '暂时无法连接 WanderPlan 服务器，请检查网络后重试。';

  @override
  String get flightUnknownError => '服务器返回异常，请稍后再试。';

  @override
  String get flightScheduled => '计划中';

  @override
  String get flightInAir => '飞行中';

  @override
  String get flightLanded => '已到达';

  @override
  String get flightCancelled => '已取消';

  @override
  String get flightIncident => '异常';

  @override
  String get flightDiverted => '备降';

  @override
  String get flightStatusUnknown => '状态未知';

  @override
  String flightDelayed(int minutes) {
    return '延误 $minutes 分钟';
  }

  @override
  String get flightDep => '起飞';

  @override
  String get flightArr => '到达';

  @override
  String flightTerminal(String t) {
    return 'T$t';
  }

  @override
  String flightGate(String g) {
    return '登机口 $g';
  }

  @override
  String flightBelt(String b) {
    return '转盘 $b';
  }

  @override
  String flightChecked(String time) {
    return '检查于 $time · 时间为各机场当地时间';
  }

  @override
  String flightNotifyTitle(String flight) {
    return '$flight：航班动态';
  }

  @override
  String flightChangeStatus(String status) {
    return '现在：$status';
  }

  @override
  String flightChangeDeparture(String from, String to) {
    return '起飞 $from → $to';
  }

  @override
  String flightChangeArrival(String from, String to) {
    return '到达 $from → $to';
  }

  @override
  String flightChangeDepTerminal(String t) {
    return '出发航站楼 $t';
  }

  @override
  String flightChangeDepGate(String g) {
    return '登机口 $g';
  }

  @override
  String flightChangeArrTerminal(String t) {
    return '到达航站楼 $t';
  }

  @override
  String flightChangeArrGate(String g) {
    return '到达登机口 $g';
  }

  @override
  String flightChangeBaggage(String b) {
    return '行李转盘 $b';
  }

  @override
  String get navigateWith => '使用以下应用导航';

  @override
  String get openGoogleMaps => 'Google 地图';

  @override
  String get openAppleMaps => 'Apple 地图';

  @override
  String get openAmap => '高德地图';

  @override
  String get openFailed => '无法打开地图应用';

  @override
  String get chooseLocation => '选择位置';

  @override
  String get pickHint => '点击地图放置标记，或搜索地点。';

  @override
  String get useThisPlace => '使用此位置';

  @override
  String get searchPlaces => '搜索地点（需联网）';

  @override
  String searchFailed(String error) {
    return '搜索不可用：$error';
  }

  @override
  String get noResults => '未找到地点';

  @override
  String get placeName => '地点名称';

  @override
  String get removePin => '移除标记';

  @override
  String get budgetPlanned => '计划';

  @override
  String get budgetSpent => '已花费';

  @override
  String get budgetRemaining => '剩余';

  @override
  String get budgetLimit => '预算';

  @override
  String get budgetOverview => '概览';

  @override
  String get budgetExpenses => '支出';

  @override
  String get budgetRates => '汇率';

  @override
  String get byCategory => '按类别';

  @override
  String get byDay => '按日期';

  @override
  String get plannedVsActual => '计划与实际';

  @override
  String get variance => '差额';

  @override
  String perPersonSpent(String amount) {
    return '人均已花 $amount';
  }

  @override
  String unpaidPlanned(String amount) {
    return '还有 $amount 待支付或预订';
  }

  @override
  String get addExpense => '添加支出';

  @override
  String get editExpense => '编辑支出';

  @override
  String get expenseTitle => '用途';

  @override
  String get fieldAmount => '金额';

  @override
  String get fieldCategory => '类别';

  @override
  String get expensePlanned => '计划';

  @override
  String get expenseActual => '实际';

  @override
  String get expensePaid => '已支付';

  @override
  String get expenseUnpaid => '未支付';

  @override
  String get expenseShared => '所有旅客分摊';

  @override
  String get linkedActivity => '关联活动';

  @override
  String get noneOption => '无';

  @override
  String get expenseDeleted => '已删除支出';

  @override
  String get noExpenses => '还没有支出。记录旅途花费，或添加行程外的计划费用。';

  @override
  String get fromItinerary => '来自行程';

  @override
  String get budgetEmpty => '为活动添加费用或添加计划支出后，这里会显示预算。';

  @override
  String get warnNoCurrency => '请为此旅行设置主要货币以跟踪预算。';

  @override
  String warnMissingRates(String currencies) {
    return '缺少 $currencies 的汇率，相关金额暂未计入。';
  }

  @override
  String warnOverPlanned(String amount) {
    return '计划超出预算 $amount。';
  }

  @override
  String warnOverActual(String amount) {
    return '实际花费超出预算 $amount。';
  }

  @override
  String get warnNearLimit => '计划已用掉超过 90% 的预算。';

  @override
  String rateLabel(String currency, String base) {
    return '1 $currency = ? $base';
  }

  @override
  String get rateManual => '手动输入 · 未验证';

  @override
  String rateFrom(String source, String date) {
    return '来源 $source · $date';
  }

  @override
  String get rateMissing => '暂无汇率';

  @override
  String get refreshRates => '获取实时汇率（需联网）';

  @override
  String get ratesUpdated => '汇率已更新';

  @override
  String ratesUnsupported(String currencies) {
    return '无法在线获取：$currencies，请手动输入。';
  }

  @override
  String ratesFailed(String error) {
    return '无法获取汇率：$error';
  }

  @override
  String get addRate => '添加汇率';

  @override
  String get rateInvalid => '请输入大于 0 的数字';

  @override
  String ratesHelp(String base) {
    return '其他货币的金额按以下汇率换算为 $base。';
  }

  @override
  String get amountInvalid => '请输入 0 或以上的金额';

  @override
  String get catFlights => '机票';

  @override
  String get catTrains => '火车';

  @override
  String get catBuses => '巴士与轮渡';

  @override
  String get catTaxis => '出租车与市内交通';

  @override
  String get catHotels => '住宿';

  @override
  String get catFood => '餐饮';

  @override
  String get catAttractions => '景点门票';

  @override
  String get catActivities => '活动';

  @override
  String get catInternet => '网络与电话卡';

  @override
  String get catInsurance => '保险';

  @override
  String get catShopping => '购物';

  @override
  String get catEmergency => '应急资金';

  @override
  String get catMisc => '其他';

  @override
  String get kindTransport => '交通（方式待定）';

  @override
  String get catTransport => '其他交通';

  @override
  String get timeTbd => '时间待定';

  @override
  String get timeTbdToggle => '时间待定';

  @override
  String get timeTbdHelp => '日程未确认时使用。应用不会猜测时间，设置时间前该日显示“信息不足”。';

  @override
  String issueTimeNotSet(String titles) {
    return '尚未设置时间：$titles';
  }

  @override
  String get notScheduled => '尚未安排时间';

  @override
  String importInvalidDetail(String detail) {
    return '无法导入：$detail';
  }

  @override
  String get importHow => '选择导入方式';

  @override
  String get importChooseFile => '选择文件';

  @override
  String get importChooseFileHelp => '朋友分享的 .wanderplan 文件或 .json 文件';

  @override
  String get importPaste => '粘贴文本';

  @override
  String get importPasteHelp => '粘贴从 ChatGPT、备忘录、邮件等复制的旅行 JSON';

  @override
  String get importPasteHint => '在此粘贴旅行 JSON';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get actionClear => '清除';

  @override
  String get importAction => '导入';

  @override
  String get importFormatHelp => '格式说明：docs/IMPORT_FORMAT.md';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get privacyTitle => '数据与隐私';

  @override
  String get privacyBody => 'WanderPlan 仅在本设备上保存你的旅行和照片，无需注册账号。';

  @override
  String get deleteAllData => '删除全部数据';

  @override
  String get deleteAllDataBody => '本设备上的所有旅行、照片和设置将被永久删除。';

  @override
  String get allDataDeleted => '已删除全部数据';

  @override
  String get atlasEyebrow => '你的私人旅行图册';

  @override
  String get atlasSubtitle => '记录计划、地点与旅途中的每一天。';

  @override
  String atlasCollection(int count) {
    return '已收录 $count 段旅行';
  }

  @override
  String get atlasJourney => '旅程';

  @override
  String get atlasFilters => '筛选旅行';

  @override
  String get atlasBegin => '开启新一章';

  @override
  String get atlasFooter => '好旅程，从一点点规划开始。';

  @override
  String get atlasEdition => '旅行集';

  @override
  String get atlasSigninHeadline => '下一站，\n值得期待。';
}
