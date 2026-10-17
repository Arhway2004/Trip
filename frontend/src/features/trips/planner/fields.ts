import type { Section } from './model'
import type { PlanText } from './copy'

export interface PlanField {
  key: string
  label: PlanText
  type?:
    'textarea' | 'date' | 'clock' | 'number' | 'checkbox' | 'select' | 'color'
  required?: boolean
  min?: number
  max?: number
  options?: Array<[string, PlanText]>
  advanced?: boolean
}
export const activityKinds: Array<[string, PlanText]> = [
  ['sightseeing', 'kindSightseeing'],
  ['food', 'kindFood'],
  ['activity', 'kindActivity'],
  ['shopping', 'kindShopping'],
  ['rest', 'kindRest'],
  ['flight', 'kindFlight'],
  ['train', 'kindTrain'],
  ['bus', 'kindBus'],
  ['transfer', 'kindTransfer'],
  ['ferry', 'kindFerry'],
  ['transport', 'kindTransport'],
  ['hotel', 'kindHotel'],
  ['other', 'kindOther'],
]
export const bookingStatuses: Array<[string, PlanText]> = [
  ['notBooked', 'bookingNotBooked'],
  ['booked', 'bookingBooked'],
  ['confirmed', 'bookingConfirmed'],
  ['cancelled', 'bookingCancelled'],
]
const categories: Array<[string, PlanText]> = [
  ['flights', 'catFlights'],
  ['trains', 'catTrains'],
  ['buses', 'catBuses'],
  ['taxis', 'catTaxis'],
  ['transport', 'catTransport'],
  ['hotels', 'catHotels'],
  ['food', 'catFood'],
  ['attractions', 'catAttractions'],
  ['activities', 'catActivities'],
  ['internet', 'catInternet'],
  ['insurance', 'catInsurance'],
  ['shopping', 'catShopping'],
  ['emergency', 'catEmergency'],
  ['misc', 'catMisc'],
]
const money: Array<PlanField> = [
  { key: 'currency', label: 'currency' },
  { key: 'notes', label: 'fieldNotes', type: 'textarea' },
]
export const fields: Record<Section | 'banner', Array<PlanField>> = {
  activities: [
    { key: 'title', label: 'activityTitle', required: true },
    {
      key: 'kind',
      label: 'activityKind',
      type: 'select',
      options: activityKinds,
    },
    { key: 'date', label: 'fieldDate', type: 'date', required: true },
    { key: 'endDate', label: 'fieldEndDate', type: 'date' },
    { key: 'start', label: 'fieldStart', type: 'clock' },
    { key: 'end', label: 'fieldEnd', type: 'clock' },
    { key: 'location.name', label: 'fieldLocation' },
    { key: 'destination.name', label: 'fieldTo' },
    { key: 'cost', label: 'fieldCost', type: 'number', min: 0 },
    { key: 'currency', label: 'currency' },
    {
      key: 'bookingStatus',
      label: 'fieldBooking',
      type: 'select',
      options: bookingStatuses,
    },
    { key: 'provider', label: 'fieldProvider', advanced: true },
    { key: 'serviceNumber', label: 'fieldServiceNumber', advanced: true },
    { key: 'bookingReference', label: 'fieldBookingRef', advanced: true },
    { key: 'bookingUrl', label: 'fieldBookingUrl', advanced: true },
    {
      key: 'location.lat',
      label: 'latitude',
      type: 'number',
      min: -90,
      max: 90,
      advanced: true,
    },
    {
      key: 'location.lng',
      label: 'longitude',
      type: 'number',
      min: -180,
      max: 180,
      advanced: true,
    },
    {
      key: 'destination.lat',
      label: 'latitude',
      type: 'number',
      min: -90,
      max: 90,
      advanced: true,
    },
    {
      key: 'destination.lng',
      label: 'longitude',
      type: 'number',
      min: -180,
      max: 180,
      advanced: true,
    },
    { key: 'isLocked', label: 'fieldLocked', type: 'checkbox', advanced: true },
    {
      key: 'isOptional',
      label: 'fieldOptional',
      type: 'checkbox',
      advanced: true,
    },
    { key: 'notes', label: 'fieldNotes', type: 'textarea' },
  ],
  todos: [
    { key: 'title', label: 'todoTitleField', required: true },
    {
      key: 'category',
      label: 'todoCategory',
      type: 'select',
      options: [
        ['documents', 'todoCatDocuments'],
        ['bookings', 'todoCatBookings'],
        ['packing', 'todoCatPacking'],
        ['health', 'todoCatHealth'],
        ['money', 'todoCatMoney'],
        ['connectivity', 'todoCatConnectivity'],
        ['home', 'todoCatHome'],
        ['other', 'todoCatOther'],
      ],
    },
    { key: 'dueDate', label: 'todoDueDate', type: 'date' },
    { key: 'isDone', label: 'actionDone', type: 'checkbox' },
    { key: 'notes', label: 'todoNotes', type: 'textarea' },
  ],
  expenses: [
    { key: 'title', label: 'expenseTitle', required: true },
    {
      key: 'amount',
      label: 'fieldAmount',
      type: 'number',
      min: 0,
      required: true,
    },
    {
      key: 'kind',
      label: 'activityKind',
      type: 'select',
      options: [
        ['actual', 'expenseActual'],
        ['planned', 'expensePlanned'],
      ],
    },
    {
      key: 'category',
      label: 'fieldCategory',
      type: 'select',
      options: categories,
    },
    { key: 'date', label: 'fieldDate', type: 'date' },
    { key: 'activityRef', label: 'activityLink', type: 'select', options: [] },
    { key: 'isPaid', label: 'expensePaid', type: 'checkbox' },
    { key: 'isShared', label: 'expenseShared', type: 'checkbox' },
    ...money,
  ],
  exchangeRates: [
    { key: 'currency', label: 'currency', required: true },
    {
      key: 'rate',
      label: 'rate',
      type: 'number',
      min: 0.00000001,
      required: true,
    },
  ],
  destinations: [
    { key: 'city', label: 'fieldCity' },
    { key: 'country', label: 'fieldCountry' },
  ],
  places: [
    { key: 'name', label: 'placeName', required: true },
    {
      key: 'category',
      label: 'fieldCategory',
      type: 'select',
      options: [
        ['attraction', 'placeAttraction'],
        ['restaurant', 'placeRestaurant'],
        ['hotel', 'placeHotel'],
        ['airport', 'placeAirport'],
        ['railwayStation', 'placeRailwayStation'],
        ['busStation', 'placeBusStation'],
        ['other', 'placeOther'],
      ],
    },
    {
      key: 'lat',
      label: 'latitude',
      type: 'number',
      min: -90,
      max: 90,
      required: true,
    },
    {
      key: 'lng',
      label: 'longitude',
      type: 'number',
      min: -180,
      max: 180,
      required: true,
    },
    { key: 'address', label: 'address' },
    { key: 'notes', label: 'fieldNotes', type: 'textarea' },
  ],
  photos: [
    { key: 'caption', label: 'photoCaption', type: 'textarea' },
    { key: 'activityRef', label: 'activityLink', type: 'select', options: [] },
    { key: 'date', label: 'fieldDate', type: 'date' },
    { key: 'isFavorite', label: 'photoFavorite', type: 'checkbox' },
  ],
  actuals: [
    {
      key: 'activityRef',
      label: 'activityLink',
      type: 'select',
      options: [],
      required: true,
    },
    { key: 'date', label: 'actualDate', type: 'date', required: true },
    { key: 'start', label: 'actualArrival', type: 'clock' },
    { key: 'endDate', label: 'actualEndDate', type: 'date' },
    { key: 'end', label: 'actualDeparture', type: 'clock' },
    { key: 'notes', label: 'actualNotes', type: 'textarea' },
  ],
  banner: [
    {
      key: 'kind',
      label: 'bannerTabBackground',
      type: 'select',
      options: [
        ['gradient', 'bannerGradient'],
        ['solid', 'bannerSolid'],
        ['photo', 'bannerTabImage'],
      ],
    },
    { key: 'colorA', label: 'colorA', type: 'color' },
    { key: 'colorB', label: 'colorB', type: 'color' },
    { key: 'showTitle', label: 'bannerShowTitle', type: 'checkbox' },
    {
      key: 'titlePlacement',
      label: 'bannerPlacement',
      type: 'select',
      options: [
        ['topLeft', 'placementTopLeft'],
        ['center', 'placementCenter'],
        ['bottomLeft', 'placementBottomLeft'],
        ['bottomCenter', 'placementBottomCenter'],
      ],
    },
    { key: 'textColor', label: 'bannerTextColor', type: 'color' },
    {
      key: 'style',
      label: 'bannerTabStyle',
      type: 'select',
      options: [
        ['classic', 'bannerStyleClassic'],
        ['minimal', 'bannerStyleMinimal'],
        ['bold', 'bannerStyleBold'],
        ['framed', 'bannerStyleFramed'],
      ],
    },
    { key: 'image', label: 'choosePhoto', type: 'select', options: [] },
    { key: 'scale', label: 'bannerZoom', type: 'number', min: 1, max: 5 },
    { key: 'alignX', label: 'alignX', type: 'number', min: -1, max: 1 },
    { key: 'alignY', label: 'alignY', type: 'number', min: -1, max: 1 },
  ],
}
