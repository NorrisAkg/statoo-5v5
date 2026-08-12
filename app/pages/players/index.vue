<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
import PlayerFormModal from '~/components/player/PlayerFormModal.vue'
import PlayerActionsSheet, { type SheetMode } from '~/components/player/PlayerActionsSheet.vue'
import PlayerRow from '~/components/player/PlayerRow.vue'
import EmptyState from '~/components/ui/EmptyState.vue'
import type { PlayerStats } from '~/types'

const { getDb } = useDb()
const players = ref<PlayerStats[]>([])
const searchQuery = ref('')
const showModal = ref(false)
const playerToEdit = ref<PlayerStats | null>(null)

const selectedPlayerForActions = ref<PlayerStats | null>(null)
const sheetInitialMode = ref<SheetMode>('menu')
const showArchived = ref(false)
const loading = ref(true)

async function fetchPlayers() {
  const db = getDb()
  if (db) {
    try {
      const res = await db.query('SELECT * FROM v_player_stats ORDER BY is_active DESC, name ASC;')
      players.value = (res.values || []) as PlayerStats[]
    } finally {
      loading.value = false
    }
  }
}

onMounted(fetchPlayers)

const activePlayers = computed(() => {
  return players.value.filter(p => p.is_active === 1)
})

const archivedPlayers = computed(() => {
  return players.value.filter(p => p.is_active === 0)
})

const filteredActivePlayers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return activePlayers.value
  return activePlayers.value.filter(p =>
    p.name.toLowerCase().includes(q) || (p.nickname && p.nickname.toLowerCase().includes(q))
  )
})

const filteredArchivedPlayers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return archivedPlayers.value
  return archivedPlayers.value.filter(p =>
    p.name.toLowerCase().includes(q) || (p.nickname && p.nickname.toLowerCase().includes(q))
  )
})

function handleNewPlayer() {
  playerToEdit.value = null
  showModal.value = true
}

function handleOpenActions(player: PlayerStats) {
  sheetInitialMode.value = 'menu'
  selectedPlayerForActions.value = player
}

function handleOpenArchiveConfirm(player: PlayerStats) {
  sheetInitialMode.value = 'confirm-archive'
  selectedPlayerForActions.value = player
}

function handleOpenDeleteConfirm(player: PlayerStats) {
  sheetInitialMode.value = 'confirm-delete'
  selectedPlayerForActions.value = player
}

function handleEditFromSheet() {
  if (selectedPlayerForActions.value) {
    playerToEdit.value = selectedPlayerForActions.value
    selectedPlayerForActions.value = null
    showModal.value = true
  }
}
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;justify-content:space-between;">
      <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;">Joueurs</span>
      <button
        @click="handleNewPlayer"
        style="width:44px;height:44px;background:transparent;border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 20px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;display:flex;align-items:center;justify-content:center;"
      >+</button>
    </div>

    <!-- Search Input -->
    <input
      v-model="searchQuery"
      type="text"
      placeholder="Rechercher un joueur"
      style="height:44px;flex:none;margin:4px 0 16px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;padding:0 12px;font:400 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text);box-sizing:border-box;outline:none;"
    />

    <!-- Loading -->
    <div v-if="loading" style="padding:48px 0;text-align:center;color:var(--text-muted);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
      Chargement…
    </div>

    <!-- Empty State -->
    <EmptyState
      v-else-if="activePlayers.length === 0 && archivedPlayers.length === 0"
      text="Le vestiaire est vide. Ajoutez vos coéquipiers !"
    >
      <template #illustration>
        <!-- Jersey with a question mark -->
        <svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <!-- Jersey body -->
          <path d="M28 24 L14 38 L24 42 L24 78 L72 78 L72 42 L82 38 L68 24 C64 30 52 32 48 32 C44 32 32 30 28 24Z" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round" fill="none"/>
          <!-- Collar -->
          <path d="M38 24 C38 30 58 30 58 24" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" fill="none"/>
          <!-- ? mark -->
          <text x="48" y="63" text-anchor="middle" font-family="Instrument Sans, system-ui, sans-serif" font-size="26" font-weight="700" fill="currentColor">?</text>
        </svg>
      </template>
      <template #action>
        <button
          @click="handleNewPlayer"
          style="padding:14px 24px;background:var(--team-a);border:none;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--ground);cursor:pointer;min-height:44px;"
        >
          Nouveau joueur
        </button>
      </template>
    </EmptyState>

    <template v-else>
      <!-- Column Header right-aligned (J, Pts, Buts) -->
      <div style="display:flex;justify-content:flex-end;gap:20px;padding-bottom:8px;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">
        <span style="width:32px;text-align:right;">J</span>
        <span style="width:32px;text-align:right;">Pts</span>
        <span style="width:32px;text-align:right;">Buts</span>
      </div>

      <!-- Active Players List -->
      <div style="display:flex;flex-direction:column;border-top:1px solid var(--hairline);">
        <PlayerRow
          v-for="p in filteredActivePlayers"
          :key="p.player_id"
          :player="p"
          @actions="handleOpenActions"
          @archive-confirm="handleOpenArchiveConfirm"
          @delete-confirm="handleOpenDeleteConfirm"
        />
      </div>

      <!-- Archived Section Accordion -->
      <div v-if="archivedPlayers.length > 0">
        <div
          @click="showArchived = !showArchived"
          style="display:flex;align-items:center;justify-content:space-between;height:52px;flex:none;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);cursor:pointer;"
        >
          <span>Archivés ({{ archivedPlayers.length }})</span>
          <span
            style="width:9px;height:9px;border-right:1.5px solid var(--text-muted);border-bottom:1.5px solid var(--text-muted);margin-right:6px;transition:transform 0.2s ease;"
            :style="showArchived ? 'transform:rotate(-135deg);' : 'transform:rotate(-45deg);'"
          ></span>
        </div>

        <div v-if="showArchived" style="display:flex;flex-direction:column;border-top:1px solid var(--hairline);">
          <PlayerRow
            v-for="p in filteredArchivedPlayers"
            :key="p.player_id"
            :player="p"
            @actions="handleOpenActions"
            @archive-confirm="handleOpenArchiveConfirm"
            @delete-confirm="handleOpenDeleteConfirm"
          />
        </div>
      </div>
    </template>

    <!-- Player Actions Sheet (Long press / Swipe / More) -->
    <PlayerActionsSheet
      :player="selectedPlayerForActions"
      :initial-mode="sheetInitialMode"
      @close="selectedPlayerForActions = null"
      @edit="handleEditFromSheet"
      @updated="fetchPlayers"
    />

    <!-- Create / Edit Player Modal -->
    <PlayerFormModal
      v-model="showModal"
      :player-to-edit="playerToEdit"
      @saved="fetchPlayers"
    />
  </div>
</template>


