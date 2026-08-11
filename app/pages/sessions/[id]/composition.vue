<template>
  <div class="composition-page">
    <!-- Header -->
    <div class="composition-header">
      <div class="header-top">
        <NuxtLink to="/sessions" class="btn-back" aria-label="Retour">←</NuxtLink>
        <div class="header-badges">
          <span class="badge badge--draft">Brouillon</span>
          <span v-if="format !== '?v?'" class="badge badge--format">{{ format }}</span>
          <span v-if="currentSession?.is_ranked" class="badge badge--ranked">Classée</span>
        </div>
      </div>

      <p class="header-date">{{ formattedDate }}</p>

      <!-- ScoreBar placeholder (dashed empty) -->
      <div class="score-bar-placeholder">
        <div class="score-placeholder-inner">
          <span class="score-dash">—</span>
          <span class="score-sep">·</span>
          <span class="score-dash">—</span>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="composition-loading">
      <div class="spinner" />
    </div>

    <!-- Composition grid -->
    <div v-else class="composition-grid">
      <TeamColumn
        team="A"
        :players="teamA"
        @swap="handleSwap"
      />

      <!-- Vertical hairline -->
      <div class="composition-divider" />

      <TeamColumn
        team="B"
        :players="teamB"
        @swap="handleSwap"
      />
    </div>

    <!-- Split mode indicator -->
    <div v-if="currentSession?.split_mode !== 'MANUAL'" class="split-mode-badge">
      <span v-if="currentSession?.split_mode === 'RANDOM'">🎲 Tirage aléatoire</span>
      <span v-else-if="currentSession?.split_mode === 'RANDOM_ADJUSTED'">🎲 Tirage ajusté</span>
    </div>

    <!-- Bottom actions -->
    <div class="composition-footer">
      <button class="btn-draw" type="button" :disabled="drawLoading" @click="handleDraw">
        <span v-if="drawLoading" class="btn-spinner" />
        <span v-else>🎲 Tirer au sort</span>
      </button>

      <button class="btn-stats" type="button" @click="goToStats">
        Saisir les statistiques
      </button>
    </div>

    <!-- Draw confirm modal -->
    <DrawConfirmModal
      :open="showConfirmModal"
      @confirm="confirmDraw"
      @cancel="showConfirmModal = false"
    />
  </div>
</template>

<script setup lang="ts">
import { useSessions } from '~/composables/useSessions'
import type { Team } from '~/types'

useHead({ title: 'Composition — Statoo' })

const route = useRoute()
const router = useRouter()
const sessionId = route.params.id as string

const {
  currentSession,
  teamA,
  teamB,
  hasAssignments,
  format,
  loading,
  loadSession,
  splitTeams,
  swapPlayer,
} = useSessions()

const drawLoading = ref(false)
const showConfirmModal = ref(false)

const formattedDate = computed(() => {
  if (!currentSession.value) return ''
  const d = new Date(currentSession.value.played_at)
  return d.toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  })
})

async function handleDraw() {
  // If already has assignments, ask confirmation first
  if (hasAssignments.value) {
    showConfirmModal.value = true
    return
  }
  await executeDraw()
}

async function confirmDraw() {
  showConfirmModal.value = false
  await executeDraw()
}

async function executeDraw() {
  drawLoading.value = true
  try {
    const allPlayers = [...teamA.value, ...teamB.value].map((a) => ({
      id: a.player_id,
      name: a.name,
    }))
    await splitTeams(sessionId, allPlayers)
  } catch (e: any) {
    console.error('Draw error:', e)
  } finally {
    drawLoading.value = false
  }
}

async function handleSwap(playerId: string, toTeam: Team) {
  await swapPlayer(sessionId, playerId, toTeam)
}

function goToStats() {
  // Lot 3 placeholder
  router.push(`/sessions/${sessionId}/stats`)
}

onMounted(async () => {
  await loadSession(sessionId)
})
</script>

<style scoped>
.composition-page {
  padding: 16px 16px 120px;
  min-height: 100vh;
}

/* Header */
.composition-header {
  margin-bottom: 20px;
}

.header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.btn-back {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--color-pitch-800);
  border: 1px solid var(--color-pitch-700);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.1rem;
  text-decoration: none;
  color: var(--color-pitch-200);
  transition: background 0.15s ease;
}
.btn-back:active { background: var(--color-pitch-700); }

.header-badges {
  display: flex;
  gap: 6px;
  align-items: center;
}

.badge {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.68rem;
  font-weight: 700;
  border-radius: 999px;
  padding: 3px 9px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.badge--draft {
  background: rgba(255, 201, 79, 0.12);
  color: var(--color-bib-400);
  border: 1px solid rgba(255, 201, 79, 0.3);
}

.badge--format {
  background: var(--color-pitch-800);
  color: var(--color-pitch-200);
  border: 1px solid var(--color-pitch-700);
}

.badge--ranked {
  background: rgba(255, 201, 79, 0.1);
  color: var(--color-bib-400);
}

.header-date {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.85rem;
  color: var(--color-pitch-400);
  margin: 0 0 12px;
  text-transform: capitalize;
}

/* Score placeholder bar */
.score-bar-placeholder {
  height: 40px;
  border: 1.5px dashed var(--color-pitch-700);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-pitch-900);
}

.score-placeholder-inner {
  display: flex;
  align-items: center;
  gap: 10px;
}

.score-dash {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--color-pitch-700);
}

.score-sep {
  font-size: 0.7rem;
  color: var(--color-pitch-700);
}

/* Loading */
.composition-loading {
  display: flex;
  justify-content: center;
  padding: 60px 0;
}

.spinner {
  width: 36px;
  height: 36px;
  border: 3px solid var(--color-pitch-700);
  border-top-color: var(--color-bib-400);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* Composition grid */
.composition-grid {
  display: flex;
  gap: 0;
  align-items: flex-start;
  margin-bottom: 12px;
}

.composition-divider {
  width: 1px;
  background: var(--color-pitch-700);
  align-self: stretch;
  margin: 0 10px;
  min-height: 200px;
}

/* Split mode badge */
.split-mode-badge {
  text-align: center;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.75rem;
  color: var(--color-pitch-500);
  margin-bottom: 16px;
  padding: 4px 0;
}

/* Footer actions */
.composition-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 12px 16px calc(70px + 12px); /* above bottom nav */
  background: linear-gradient(to top, var(--color-pitch-950) 60%, transparent);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.btn-draw {
  width: 100%;
  height: 48px;
  border-radius: 12px;
  border: 1.5px solid var(--color-pitch-600);
  background: transparent;
  color: var(--color-pitch-200);
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.15s ease;
}

.btn-draw:not(:disabled):active {
  background: var(--color-pitch-800);
}

.btn-draw:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-stats {
  width: 100%;
  height: 56px;
  border-radius: 14px;
  border: none;
  background: var(--color-bib-400);
  color: var(--color-pitch-950);
  font-family: 'Instrument Sans', sans-serif;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s ease;
}

.btn-stats:active {
  background: var(--color-bib-300);
  scale: 0.98;
}

.btn-spinner {
  width: 18px;
  height: 18px;
  border: 2.5px solid rgba(255,255,255,0.3);
  border-top-color: var(--color-pitch-200);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
</style>
