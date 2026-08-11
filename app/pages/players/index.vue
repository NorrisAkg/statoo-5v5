<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
import PlayerFormModal from '~/components/player/PlayerFormModal.vue'
import type { PlayerStats } from '~/types'

const { getDb } = useDb()
const players = ref<PlayerStats[]>([])
const searchQuery = ref('')
const showModal = ref(false)
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

function initials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return name.slice(0, 2).toUpperCase()
}

function statVal(val: number | null | undefined): string {
  if (val == null || val === 0) return '—'
  return String(val)
}
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;justify-content:space-between;">
      <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;">Joueurs</span>
      <button
        @click="showModal = true"
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
    <div
      v-else-if="activePlayers.length === 0 && archivedPlayers.length === 0"
      style="padding:48px 0;text-align:center;display:flex;flex-direction:column;align-items:center;gap:16px;"
    >
      <p style="font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
        Ajoutez les joueurs du groupe pour commencer.
      </p>
      <button
        @click="showModal = true"
        style="padding:14px 24px;background:var(--team-a);border:none;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--ground);cursor:pointer;"
      >
        Nouveau joueur
      </button>
    </div>

    <template v-else>
      <!-- Column Header right-aligned (J, Pts, Buts) -->
      <div style="display:flex;justify-content:flex-end;gap:20px;padding-bottom:8px;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">
        <span style="width:32px;text-align:right;">J</span>
        <span style="width:32px;text-align:right;">Pts</span>
        <span style="width:32px;text-align:right;">Buts</span>
      </div>

      <!-- Active Players List -->
      <div style="display:flex;flex-direction:column;border-top:1px solid var(--hairline);">
        <NuxtLink
          v-for="p in filteredActivePlayers"
          :key="p.player_id"
          :to="`/players/${p.player_id}`"
          style="display:flex;align-items:center;gap:12px;min-height:60px;border-bottom:1px solid var(--hairline);text-decoration:none;color:inherit;"
        >
          <!-- Initials square avatar -->
          <div style="width:36px;height:36px;flex:none;border-radius:8px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 13px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">
            {{ initials(p.name) }}
          </div>

          <!-- Name & Nickname -->
          <div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:2px;">
            <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--text);">{{ p.name }}</span>
            <span v-if="p.nickname" style="font:400 13px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ p.nickname }}</span>
          </div>

          <!-- Right numeric columns -->
          <div style="display:flex;gap:20px;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">
            <span style="width:32px;text-align:right;" :style="p.appearances === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.appearances) }}</span>
            <span style="width:32px;text-align:right;" :style="p.points === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.points) }}</span>
            <span style="width:32px;text-align:right;" :style="p.goals === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.goals) }}</span>
          </div>
        </NuxtLink>
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
          <NuxtLink
            v-for="p in filteredArchivedPlayers"
            :key="p.player_id"
            :to="`/players/${p.player_id}`"
            style="display:flex;align-items:center;gap:12px;min-height:60px;border-bottom:1px solid var(--hairline);text-decoration:none;color:inherit;opacity:0.6;"
          >
            <div style="width:36px;height:36px;flex:none;border-radius:8px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 13px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">
              {{ initials(p.name) }}
            </div>
            <div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:2px;">
              <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text);">{{ p.name }}</span>
              <span v-if="p.nickname" style="font:400 13px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">{{ p.nickname }}</span>
            </div>
            <div style="display:flex;gap:20px;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">
              <span style="width:32px;text-align:right;" :style="p.appearances === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.appearances) }}</span>
              <span style="width:32px;text-align:right;" :style="p.points === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.points) }}</span>
              <span style="width:32px;text-align:right;" :style="p.goals === 0 ? 'color:var(--text-faint);' : 'color:var(--text-muted);'">{{ statVal(p.goals) }}</span>
            </div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <!-- Create Player Modal -->
    <PlayerFormModal v-model="showModal" @saved="fetchPlayers" />
  </div>
</template>
