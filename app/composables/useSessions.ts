import { ref, computed } from 'vue'
import { nanoid } from 'nanoid'
import { useDb } from './useDb'
import type { Session, TeamAssignment, AttendeePlayer } from '~/types'
import {
  fetchAllSessions,
  fetchSessionById,
  insertSession,
  fetchParticipationsBySession,
  insertParticipation,
  deleteParticipationsBySession,
  updateSessionSplitMode,
  swapPlayerTeam,
} from '~/lib/db/queries'
import { saveWebStore } from '~/lib/db/connection'
import { RandomSplitter } from '~/lib/splitter/RandomSplitter'

const splitter = new RandomSplitter()

export function useSessions() {
  const { getDb } = useDb()

  const sessions = ref<Session[]>([])
  const currentSession = ref<Session | null>(null)
  const currentAssignments = ref<TeamAssignment[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // ---------------------------------------------------------------------------
  // Load all sessions
  // ---------------------------------------------------------------------------
  async function loadSessions() {
    const db = getDb()
    if (!db) return
    loading.value = true
    error.value = null
    try {
      sessions.value = await fetchAllSessions(db)
    } catch (e: any) {
      error.value = e?.message || 'Erreur lors du chargement des séances'
    } finally {
      loading.value = false
    }
  }

  // ---------------------------------------------------------------------------
  // Load a single session + its composition
  // ---------------------------------------------------------------------------
  async function loadSession(id: string) {
    const db = getDb()
    if (!db) return
    loading.value = true
    error.value = null
    try {
      currentSession.value = await fetchSessionById(db, id)
      currentAssignments.value = await fetchParticipationsBySession(db, id)
    } catch (e: any) {
      error.value = e?.message || 'Erreur lors du chargement de la séance'
    } finally {
      loading.value = false
    }
  }

  // ---------------------------------------------------------------------------
  // Create a new DRAFT session
  // Returns the new session id
  // ---------------------------------------------------------------------------
  async function createSession(options: {
    played_at: string
    is_ranked: boolean
    allow_uneven_teams: boolean
    attendees: AttendeePlayer[]
    notes?: string | null
  }): Promise<string> {
    const db = getDb()
    if (!db) throw new Error('DB not ready')

    const sessionId = `session_${nanoid(10)}`

    await insertSession(db, {
      id: sessionId,
      played_at: options.played_at,
      is_ranked: options.is_ranked,
      allow_uneven_teams: options.allow_uneven_teams,
      notes: options.notes,
    })

    // Insert preliminary participation for each attendee with team 'A'
    // Real split happens on the composition screen
    for (const attendee of options.attendees) {
      await insertParticipation(db, {
        id: `part_${nanoid(10)}`,
        session_id: sessionId,
        player_id: attendee.id,
        team: 'A',
      })
    }

    await saveWebStore()
    await loadSessions()
    return sessionId
  }

  // ---------------------------------------------------------------------------
  // Split teams (RANDOM) — clears and re-inserts participations
  // ---------------------------------------------------------------------------
  async function splitTeams(
    sessionId: string,
    players: { id: string; name: string }[]
  ) {
    const db = getDb()
    if (!db) return

    if (players.length < 4) {
      throw new Error('Il faut au moins 4 joueurs pour créer une séance.')
    }

    const { teamA, teamB } = splitter.split(players)

    await deleteParticipationsBySession(db, sessionId)

    for (const playerId of teamA) {
      await insertParticipation(db, {
        id: `part_${nanoid(10)}`,
        session_id: sessionId,
        player_id: playerId,
        team: 'A',
      })
    }

    for (const playerId of teamB) {
      await insertParticipation(db, {
        id: `part_${nanoid(10)}`,
        session_id: sessionId,
        player_id: playerId,
        team: 'B',
      })
    }

    await updateSessionSplitMode(db, sessionId, 'RANDOM')
    await saveWebStore()
    await loadSession(sessionId)
  }

  // ---------------------------------------------------------------------------
  // Swap a player from one team to the other
  // ---------------------------------------------------------------------------
  async function swapPlayer(
    sessionId: string,
    playerId: string,
    newTeam: 'A' | 'B'
  ) {
    const db = getDb()
    if (!db) return

    await swapPlayerTeam(db, sessionId, playerId, newTeam)

    // Upgrade split_mode on swap
    const current = currentSession.value?.split_mode
    if (current === 'RANDOM') {
      await updateSessionSplitMode(db, sessionId, 'RANDOM_ADJUSTED')
    }

    await saveWebStore()
    await loadSession(sessionId)
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------
  const teamA = computed<TeamAssignment[]>(() =>
    currentAssignments.value.filter((a) => a.team === 'A')
  )

  const teamB = computed<TeamAssignment[]>(() =>
    currentAssignments.value.filter((a) => a.team === 'B')
  )

  const hasAssignments = computed<boolean>(
    () => currentAssignments.value.length > 0
  )

  const format = computed<string>(() => {
    if (!hasAssignments.value) return '?v?'
    return `${teamA.value.length}v${teamB.value.length}`
  })

  return {
    sessions,
    currentSession,
    currentAssignments,
    teamA,
    teamB,
    hasAssignments,
    format,
    loading,
    error,
    loadSessions,
    loadSession,
    createSession,
    splitTeams,
    swapPlayer,
  }
}
