import { readFileSync, writeFileSync } from 'node:fs'
import vm from 'node:vm'
const context = { window: { CTP: {} } }
vm.createContext(context)
vm.runInContext(readFileSync('Reference/Trip/js/i18n.js', 'utf8'), context)
const i = context.window.CTP.I18n,
  rows = Object.fromEntries(
    i
      .keys()
      .map((key) => [
        key,
        ['en', 'zh', 'th'].map((lang) => i.t(key, null, lang)),
      ]),
  )
Object.assign(rows, {
  'c.previous': ['Previous', '上一个', 'ก่อนหน้า'],
  'c.next': ['Next', '下一个', 'ถัดไป'],
  'dash.editDates': [
    'Shift planning dates',
    '调整计划日期',
    'เลื่อนวันที่วางแผน',
  ],
  'dash.shiftBookings': [
    'Also shift booked and confirmed dates',
    '同时调整已预订和已确认日期',
    'เลื่อนวันที่จองและยืนยันด้วย',
  ],
  'it.clearConfirm': [
    'Remove this day’s planned activities? Actual records and photos are kept.',
    '移除此日的计划活动？实际记录和照片将保留。',
    'ลบกิจกรรมตามแผนของวันนี้หรือไม่ เก็บบันทึกจริงและรูปภาพไว้',
  ],
  'it.insertDay': ['Insert day after', '在之后插入一天', 'แทรกวันถัดไป'],
  'it.insertConfirm': [
    'Later flexible activities move one day. Bookings keep their dates.',
    '后续可调整活动顺延一天，预订日期不变。',
    'เลื่อนกิจกรรมที่ย้ายได้หนึ่งวัน วันที่จองคงเดิม',
  ],
  'att.addToDay': ['Add to day', '加入当天行程', 'เพิ่มในวัน'],
  'map.myLocation': ['My location', '我的位置', 'ตำแหน่งของฉัน'],
  'map.locFail': [
    'Location unavailable. Choose a pin on the map.',
    '无法获取位置，请选择地图上的图钉。',
    'ไม่พบตำแหน่ง เลือกหมุดบนแผนที่',
  ],
  'map.nearby': [
    'Find nearby, within 1.5 km',
    '查找附近 1.5 公里内的地点',
    'ค้นหาใกล้เคียงในระยะ 1.5 กม.',
  ],
  'ex.backupHint': [
    'Includes this trip’s full plan, scenarios, photos and actual records. Restore it with Import trip.',
    '包含此行程的完整计划、方案、照片及实际记录，可通过导入行程恢复。',
    'รวมแผน สถานการณ์ รูป และบันทึกจริงของทริปนี้ กู้คืนด้วยนำเข้าทริป',
  ],
  'ex.backupPrivate': [
    'Full backups include private booking references and notes.',
    '完整备份包含私人预订编号和备注。',
    'ข้อมูลสำรองเต็มมีรหัสจองและหมายเหตุส่วนตัว',
  ],
  'sc.use': ['Use this scenario', '使用此方案', 'ใช้แผนนี้'],
  'w.activityOverlap': [
    'Overlapping appointments',
    '活动时间重叠',
    'กิจกรรมเวลาทับกัน',
  ],
  'w.openingHours': [
    'Outside entered opening hours',
    '超出填写的营业时间',
    'นอกเวลาเปิดที่กรอกไว้',
  ],
  localDraft: [
    'Unsaved local draft available',
    '有未保存的本地草稿',
    'มีฉบับร่างในเครื่องที่ยังไม่บันทึก',
  ],
  restoreDraft: [
    'Review and restore draft',
    '查看并恢复草稿',
    'ตรวจสอบและกู้คืนฉบับร่าง',
  ],
  localDraftHelp: [
    'Your last failed save is kept on this device. Review it before saving again.',
    '最近未成功保存的内容已保留在此设备，请检查后再保存。',
    'เก็บข้อมูลที่บันทึกไม่สำเร็จล่าสุดในเครื่องนี้ ตรวจสอบก่อนบันทึกอีกครั้ง',
  ],
  savedLocally: [
    'Draft kept on this device; server save failed.',
    '草稿已保留在此设备，服务器保存失败。',
    'เก็บฉบับร่างในเครื่องแล้ว บันทึกเซิร์ฟเวอร์ไม่สำเร็จ',
  ],
})
writeFileSync(
  'frontend/src/features/trips/planner/reference/copy.ts',
  `// Labels reused from Reference/Trip/js/i18n.js.\nimport { getLocale } from '#/paraglide/runtime'\n\nconst labels: Record<string, Array<string> | undefined> = ${JSON.stringify(rows, null, 2)}\nexport function r(key: string, params: Record<string, string | number> = {}) {\n const lang = getLocale(); const value = labels[key]?.[lang === 'zh' ? 1 : lang === 'th' ? 2 : 0] || key\n return value.replace(/\\{(\\w+)\\}/g, (match, name: string) => String(params[name] ?? match))\n}\n`,
)
