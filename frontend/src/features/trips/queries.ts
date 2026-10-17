import { queryOptions } from '@tanstack/react-query'
import { unwrap } from '#/lib/api/problem'
import { getSession } from '#/features/auth/auth.functions'
import { getTrip, listMembers, listTrips } from './trips.functions'

export const sessionQuery = queryOptions({
  queryKey: ['session'],
  queryFn: () => getSession(),
  staleTime: 60_000,
})

export const tripsQuery = (includeArchived: boolean) =>
  queryOptions({
    queryKey: ['trips', { includeArchived }],
    queryFn: async () => unwrap(await listTrips({ data: { includeArchived } })),
  })

export const tripQuery = (tripId: string) =>
  queryOptions({
    queryKey: ['trip', tripId],
    queryFn: async () => unwrap(await getTrip({ data: { tripId } })),
  })

export const membersQuery = (tripId: string) =>
  queryOptions({
    queryKey: ['trip', tripId, 'members'],
    queryFn: async () => unwrap(await listMembers({ data: { tripId } })),
  })
