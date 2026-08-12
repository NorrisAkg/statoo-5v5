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
  updateSessionSplitMode,
  swapPlayerTeam,
} from '~/lib/db/queries'
import { saveWebStore } from '~/lib/db/connection'
import { RandomSplitter } from '~/lib/splitter/RandomSplitter'

const splitter = new RandomSplitter()

/**
 * A session needs at least a 3v3. Below that the format stops being football and
 * the ranking it feeds is meaningless, so this one is blocking — unlike the
 * informative footnote shown during onboarding.
 */
export const MIN_ATTENDEES = 6

/** How the teams are decided when the session is created. */
export type CreationSplit = 'RANDOM' | 'MANUAL'

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
    /**
     * 'RANDOM' draws the teams straight away, so the composition screen opens
     * on a balanced draft. 'MANUAL' records the attendees with no team, leaving
     * them in the "à placer" zone — the only way to reach split_mode 'MANUAL'.
     */
    split: CreationSplit
    notes?: string | null
  }): Promise<string> {
    const db = getDb()
    if (!db) throw new Error('DB not ready')

    if (options.attendees.length < MIN_ATTENDEES) {
      throw new Error(`Il faut au moins ${MIN_ATTENDEES} joueurs pour créer une séance.`)
    }

    const sessionId = `session_${nanoid(10)}`

    await insertSession(db, {
      id: sessionId,
      played_at: options.played_at,
      is_ranked: options.is_ranked,
      allow_uneven_teams: options.allow_uneven_teams,
      split_mode: options.split === 'RANDOM' ? 'RANDOM' : 'MANUAL',
      notes: options.notes,
    })

    // Attendees are always recorded now; only their team differs. Assigning
    // everyone to 'A' as a placeholder would show a bogus "Nv0" format.
    const teams = new Map<string, 'A' | 'B' | null>()
    if (options.split === 'RANDOM') {
      const { teamA, teamB } = splitter.split(
        options.attendees.map((a) => ({ id: a.id, name: a.name }))
      )
      teamA.forEach((id) => teams.set(id, 'A'))
      teamB.forEach((id) => teams.set(id, 'B'))
    }

    for (const attendee of options.attendees) {
      await insertParticipation(db, {
        id: `part_${nanoid(10)}`,
        session_id: sessionId,
        player_id: attendee.id,
        team: teams.get(attendee.id) ?? null,
      })
    }

    await saveWebStore()
    await loadSessions()
    return sessionId
  }

  // ---------------------------------------------------------------------------
  // Split teams (RANDOM) — clears and re-inserts participations
  // ---------------------------------------------------------------------------
  /**
   * Redraws the teams over every attendee of the session, including any still
   * waiting to be placed. Teams are UPDATEd rather than deleted and reinserted,
   * so the stats already entered survive — which is what the confirmation sheet
   * promises the organizer.
   */
  async function splitTeams(sessionId: string) {
    const db = getDb()
    if (!db) return

    const players = currentAssignments.value.map((a) => ({
      id: a.player_id,
      name: a.name,
    }))

    if (players.length < MIN_ATTENDEES) {
      throw new Error(`Il faut au moins ${MIN_ATTENDEES} joueurs pour tirer les équipes.`)
    }

    const { teamA, teamB } = splitter.split(players)

    for (const playerId of teamA) {
      await swapPlayerTeam(db, sessionId, playerId, 'A')
    }
    for (const playerId of teamB) {
      await swapPlayerTeam(db, sessionId, playerId, 'B')
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

  /**
   * Present but not yet placed. Non-empty only on a hand-composed draft.
   *
   * Loose `== null` on purpose, to match both `null` and `undefined`: sql.js
   * returns a NULL column as `null` with the key present, but the native
   * @capacitor-community/sqlite plugin serialises its rows to JSON and may drop
   * null keys entirely. With a strict `=== null`, an unplaced player would then
   * appear in no list at all — invisible on screen, yet still counted by the
   * SQL closure check, leaving the organizer blocked with nobody to place.
   */
  const unassigned = computed<TeamAssignment[]>(() =>
    currentAssignments.value.filter((a) => a.team == null)
  )

  const hasAssignments = computed<boolean>(
    () => teamA.value.length > 0 || teamB.value.length > 0
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
    unassigned,
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
