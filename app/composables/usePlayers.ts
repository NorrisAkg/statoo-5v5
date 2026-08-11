import { ref, computed } from 'vue'
import { useDb } from '~/composables/useDb'
import { saveWebStore } from '~/lib/db/connection'
import type { PlayerStats } from '~/types'
import {
  fetchAllPlayerStats,
  insertPlayer,
  updatePlayer as dbUpdatePlayer,
  setPlayerActiveStatus,
  deletePlayerById,
  getPlayerParticipationCount,
  fetchPlayerStatsById,
  fetchPlayerMatchHistory,
} from '~/lib/db/queries'

const playersList = ref<PlayerStats[]>([])
const isLoading = ref(false)
const searchQuery = ref('')

export function usePlayers() {
  const { getDb } = useDb()

  async function fetchPlayers() {
    const db = getDb()
    if (!db) return
    isLoading.value = true
    try {
      playersList.value = await fetchAllPlayerStats(db)
    } finally {
      isLoading.value = false
    }
  }

  const activePlayers = computed(() =>
    playersList.value.filter(p => p.is_active === 1)
  )

  const archivedPlayers = computed(() =>
    playersList.value.filter(p => p.is_active === 0)
  )

  const filteredActivePlayers = computed(() => {
    const query = searchQuery.value.trim().toLowerCase()
    if (!query) return activePlayers.value
    return activePlayers.value.filter(
      p =>
        p.name.toLowerCase().includes(query) ||
        (p.nickname && p.nickname.toLowerCase().includes(query))
    )
  })

  async function createPlayer(data: { name: string; nickname?: string; avatar_url?: string }): Promise<string> {
    const db = getDb()
    if (!db) throw new Error('Database not connected')
    const id = 'player_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7)
    await insertPlayer(db, { id, ...data })
    await saveWebStore()
    await fetchPlayers()
    return id
  }

  async function updatePlayer(id: string, data: { name: string; nickname?: string; avatar_url?: string }): Promise<void> {
    const db = getDb()
    if (!db) throw new Error('Database not connected')
    await dbUpdatePlayer(db, id, data)
    await saveWebStore()
    await fetchPlayers()
  }

  async function toggleArchivePlayer(id: string, archive: boolean): Promise<void> {
    const db = getDb()
    if (!db) throw new Error('Database not connected')
    await setPlayerActiveStatus(db, id, !archive)
    await saveWebStore()
    await fetchPlayers()
  }

  async function deletePlayer(id: string): Promise<boolean> {
    const db = getDb()
    if (!db) throw new Error('Database not connected')

    const count = await getPlayerParticipationCount(db, id)
    if (count > 0) {
      throw new Error('Impossible de supprimer un joueur ayant déjà disputé des séances. Vous pouvez seulement l\'archiver.')
    }

    await deletePlayerById(db, id)
    await saveWebStore()
    await fetchPlayers()
    return true
  }

  async function getPlayerProfile(id: string) {
    const db = getDb()
    if (!db) throw new Error('Database not connected')
    const stats = await fetchPlayerStatsById(db, id)
    const history = await fetchPlayerMatchHistory(db, id)
    return { stats, history }
  }

  function checkDuplicateName(name: string, excludeId?: string): boolean {
    const normalized = name.trim().toLowerCase()
    return playersList.value.some(
      p => p.name.toLowerCase() === normalized && p.player_id !== excludeId
    )
  }

  return {
    playersList,
    activePlayers,
    archivedPlayers,
    filteredActivePlayers,
    searchQuery,
    isLoading,
    fetchPlayers,
    createPlayer,
    updatePlayer,
    toggleArchivePlayer,
    deletePlayer,
    getPlayerProfile,
    checkDuplicateName,
  }
}
