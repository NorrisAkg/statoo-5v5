<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { usePlayers } from '~/composables/usePlayers'
import PlayerFormModal from '~/components/player/PlayerFormModal.vue'
import type { PlayerStats } from '~/types'

const route = useRoute()
const router = useRouter()
const playerId = route.params.id as string

const { getPlayerProfile, toggleArchivePlayer, deletePlayer } = usePlayers()

const playerStats = ref<PlayerStats | null>(null)
const matchHistory = ref<any[]>([])
const isLoading = ref(true)
const showEditModal = ref(false)
const errorMessage = ref<string | null>(null)

async function loadProfile() {
  isLoading.value = true
  try {
    const data = await getPlayerProfile(playerId)
    playerStats.value = data.stats
    matchHistory.value = data.history
  } catch (err: any) {
    console.error('Error loading player profile:', err)
  } finally {
    isLoading.value = false
  }
}

onMounted(loadProfile)

const initials = computed(() => {
  if (!playerStats.value?.name) return ''
  const parts = playerStats.value.name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return playerStats.value.name.slice(0, 2).toUpperCase()
})

function formatPtsPerMatch(val: number | null | undefined): string {
  if (val == null) return '0,00'
  return val.toFixed(2).replace('.', ',')
}

function formatDate(isoStr: string): string {
  if (!isoStr) return ''
  const d = new Date(isoStr)
  return d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })
}

function formatContribution(item: any): string {
  const parts = []
  if (item.goals > 0) parts.push(`${item.goals} ${item.goals > 1 ? 'buts' : 'but'}`)
  if (item.assists > 0) parts.push(`${item.assists} ${item.assists > 1 ? 'passes' : 'passe'}`)
  if (item.yellow_cards > 0) parts.push(`${item.yellow_cards} CJ`)
  if (item.red_cards > 0) parts.push(`${item.red_cards} CR`)
  return parts.length > 0 ? parts.join(' · ') : '—'
}

function scoreBarWidths(scoreA: number | null, scoreB: number | null) {
  const a = scoreA ?? 0
  const b = scoreB ?? 0
  const total = a + b
  if (total === 0) return { a: 50, b: 50 }
  let pA = (a / total) * 100
  let pB = (b / total) * 100
  if (pA < 5 && a > 0) pA = 5
  if (pB < 5 && b > 0) pB = 5
  return { a: pA, b: pB }
}
</script>

<template>
  <div v-if="isLoading" style="padding:24px 16px;color:var(--text-muted);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
    Chargement…
  </div>

  <div v-else-if="playerStats" style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Back button row -->
    <div style="height:56px;flex:none;display:flex;align-items:center;">
      <NuxtLink to="/players" style="display:flex;align-items:center;color:inherit;text-decoration:none;">
        <span style="width:10px;height:10px;border-left:1.5px solid var(--text);border-bottom:1.5px solid var(--text);transform:rotate(45deg);margin-left:4px;display:inline-block;"></span>
      </NuxtLink>
    </div>

    <!-- Error Banner -->
    <div v-if="errorMessage" style="background:var(--danger-bg);border:1px solid var(--danger-border);border-radius:8px;padding:12px 14px;margin-bottom:12px;">
      <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--danger-text);">{{ errorMessage }}</span>
    </div>

    <!-- Player Identity Row -->
    <div style="display:flex;align-items:center;gap:14px;padding-bottom:20px;">
      <div style="width:56px;height:56px;flex:none;border-radius:8px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">
        {{ initials }}
      </div>
      <div style="flex:1;display:flex;flex-direction:column;gap:2px;">
        <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;color:var(--text);">{{ playerStats.name }}</span>
        <span v-if="playerStats.nickname" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">{{ playerStats.nickname }}</span>
      </div>
      <button
        @click="showEditModal = true"
        style="height:36px;padding:0 12px;background:transparent;border:1px solid var(--hairline);border-radius:8px;font:500 13px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text);cursor:pointer;"
      >
        Modifier
      </button>
    </div>

    <!-- Synthèse Card -->
    <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:16px;">
      <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Synthèse</span>

      <div style="display:flex;justify-content:space-between;">
        <div style="display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.played }}</span>
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Séances</span>
        </div>
        <div style="display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatPtsPerMatch(playerStats.points_per_match) }}</span>
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Pts/match</span>
        </div>
        <div style="display:flex;flex-direction:column;gap:6px;align-items:flex-end;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.win_rate ? Math.round(playerStats.win_rate) : 0 }} %</span>
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Victoires</span>
        </div>
      </div>

      <div style="display:flex;justify-content:space-between;padding-top:12px;border-top:1px solid var(--hairline);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
        <span style="font-variant-numeric:tabular-nums;">{{ playerStats.wins }} V · {{ playerStats.draws }} N · {{ playerStats.losses }} D</span>
        <span style="color:var(--text);font-variant-numeric:tabular-nums;">{{ playerStats.points }} points</span>
      </div>
    </div>

    <!-- Statistiques brutes Card -->
    <div style="padding:16px 0 8px;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Statistiques brutes</div>
    <div style="display:flex;flex-direction:column;border-top:1px solid var(--hairline);">
      <div style="display:flex;justify-content:space-between;align-items:center;height:48px;border-bottom:1px solid var(--hairline);font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        <span style="color:var(--text-strong);">Buts</span>
        <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.goals }}</span>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;height:48px;border-bottom:1px solid var(--hairline);font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        <span style="color:var(--text-strong);">Passes</span>
        <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.assists }}</span>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;height:48px;border-bottom:1px solid var(--hairline);font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        <span style="color:var(--text-strong);">Cartons jaunes</span>
        <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.yellow_cards }}</span>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;height:48px;border-bottom:1px solid var(--hairline);font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        <span style="color:var(--text-strong);">Cartons rouges</span>
        <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.red_cards }}</span>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;height:48px;border-bottom:1px solid var(--hairline);font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        <span style="color:var(--text-strong);">Apparitions</span>
        <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ playerStats.appearances }}</span>
      </div>
    </div>

    <!-- Historique -->
    <div style="padding:16px 0 10px;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Historique</div>

    <div v-if="matchHistory.length === 0" style="padding:16px 0;color:var(--text-faint);font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;">
      Aucune séance jouée pour l'instant.
    </div>

    <div v-else style="display:flex;flex-direction:column;gap:12px;padding-bottom:24px;">
      <NuxtLink
        v-for="item in matchHistory"
        :key="item.session_id"
        :to="`/sessions/${item.session_id}`"
        style="display:flex;flex-direction:column;gap:8px;text-decoration:none;color:inherit;"
      >
        <!-- 2px ScoreBar -->
        <div style="display:flex;height:2px;">
          <div :style="`width:${scoreBarWidths(item.score_a, item.score_b).a}%;background:var(--team-a)`"></div>
          <div :style="`width:${scoreBarWidths(item.score_a, item.score_b).b}%;background-color:var(--surface-2);background-image:repeating-linear-gradient(45deg,var(--hatch-line) 0 1px,transparent 1px 3px)`"></div>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:baseline;">
          <div style="display:flex;flex-direction:column;gap:2px;">
            <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text);">{{ formatDate(item.played_at) }}</span>
            <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">{{ formatContribution(item) }}</span>
          </div>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:var(--text);">{{ item.score_a }} — {{ item.score_b }}</span>
        </div>
      </NuxtLink>
    </div>

    <!-- Edit Modal -->
    <PlayerFormModal
      v-model="showEditModal"
      :player-to-edit="playerStats"
      @saved="loadProfile"
    />
  </div>
</template>
