import { ref } from 'vue'
import { useDb } from './useDb'
import type { PlayerStats, GroupTotals } from '~/types'
import {
  fetchStandingsByPoints,
  fetchStandingsPerMatch,
  fetchIneligiblePlayers,
  fetchEligibilityThreshold,
  fetchTopScorers,
  fetchTopAssists,
  fetchTopCards,
  fetchGroupTotals,
} from '~/lib/db/queries'

// Module-level state, like the other composables.
const standingsPoints = ref<PlayerStats[]>([])
const standingsPerMatch = ref<PlayerStats[]>([])
const ineligiblePlayers = ref<PlayerStats[]>([])
const requiredSessions = ref(0)
const topScorers = ref<PlayerStats[]>([])
const topAssists = ref<PlayerStats[]>([])
const topCards = ref<PlayerStats[]>([])
const groupTotals = ref<GroupTotals | null>(null)
// Starts true: the first fetch only runs on mount, and an empty state flashing
// before it resolves reads as "no data" rather than "not loaded yet".
const loading = ref(true)
const error = ref<string | null>(null)

export function useStandings() {
  const { getDb } = useDb()

  async function fetchStandings(): Promise<void> {
    const db = getDb()
    loading.value = true
    error.value = null
    try {
      // No connection: fall through to `finally` so the spinner always clears.
      if (!db) return
      standingsPoints.value = await fetchStandingsByPoints(db)
      standingsPerMatch.value = await fetchStandingsPerMatch(db)
      ineligiblePlayers.value = await fetchIneligiblePlayers(db)
      requiredSessions.value = (await fetchEligibilityThreshold(db)).required_sessions
    } catch (e: any) {
      error.value = e?.message || 'Erreur lors du chargement du classement'
    } finally {
      loading.value = false
    }
  }

  async function fetchSecondaryRankings(): Promise<void> {
    const db = getDb()
    if (!db) return
    try {
      topScorers.value = await fetchTopScorers(db)
      topAssists.value = await fetchTopAssists(db)
      topCards.value = await fetchTopCards(db)
    } catch (e: any) {
      error.value = e?.message || 'Erreur lors du chargement des classements'
    }
  }

  async function fetchTotals(): Promise<void> {
    const db = getDb()
    loading.value = true
    error.value = null
    try {
      if (!db) return
      groupTotals.value = await fetchGroupTotals(db)
    } catch (e: any) {
      error.value = e?.message || 'Erreur lors du chargement des statistiques'
    } finally {
      loading.value = false
    }
  }

  return {
    standingsPoints,
    standingsPerMatch,
    ineligiblePlayers,
    requiredSessions,
    topScorers,
    topAssists,
    topCards,
    groupTotals,
    loading,
    error,
    fetchStandings,
    fetchSecondaryRankings,
    fetchTotals,
  }
}
