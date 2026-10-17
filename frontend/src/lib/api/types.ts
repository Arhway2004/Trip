import type { components } from './schema'

export type Trip = components['schemas']['Trip']
export type TripInput = components['schemas']['TripInput']
export type Member = components['schemas']['Member']
export type User = components['schemas']['User']
export type Role = Trip['role']
export type TravelStyle = NonNullable<TripInput['travelStyle']>
export type Stage = NonNullable<TripInput['stage']>
