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

    <template v-else>
      <!-- Attendees still to place — only on a hand-composed draft -->
      <section v-if="unassigned.length > 0" class="unassigned">
        <div class="unassigned__header">
          <h2 class="unassigned__label">À placer</h2>
          <span class="unassigned__count">{{ unassigned.length }}</span>
        </div>

        <div class="unassigned__list">
          <div
            v-for="player in unassigned"
            :key="player.player_id"
            class="unassigned__row"
          >
            <span class="unassigned__avatar">{{ getInitials(player.name) }}</span>
            <span class="unassigned__name">{{ player.nickname || player.name }}</span>
            <div class="unassigned__actions">
              <button
                class="place-btn place-btn--a"
                type="button"
                :aria-label="`Placer ${player.name} dans l'équipe A`"
                @click="handleSwap(player.player_id, 'A')"
              >
                A
              </button>
              <button
                class="place-btn place-btn--b"
                type="button"
                :aria-label="`Placer ${player.name} dans l'équipe B`"
                @click="handleSwap(player.player_id, 'B')"
              >
                B
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Composition grid -->
      <div class="composition-grid">
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

        <button
          class="btn-stats"
          type="button"
          :disabled="unassigned.length > 0"
          @click="goToStats"
        >
          Saisir les statistiques
        </button>

        <p v-if="unassigned.length > 0" class="footer-hint">
          Placez les {{ unassigned.length }} joueur{{ unassigned.length > 1 ? 's' : '' }} restant{{ unassigned.length > 1 ? 's' : '' }} pour continuer.
        </p>
        <p v-if="drawError" class="footer-hint footer-hint--error">{{ drawError }}</p>
      </div>
    </template>

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
import { getInitials } from '~/lib/initials'
import type { Team } from '~/types'

useHead({ title: 'Composition — Statoo' })

const route = useRoute()
const router = useRouter()
const sessionId = route.params.id as string

const {
  currentSession,
  teamA,
  teamB,
  unassigned,
  hasAssignments,
  format,
  loading,
  loadSession,
  splitTeams,
  swapPlayer,
} = useSessions()

const drawLoading = ref(false)
const drawError = ref<string | null>(null)
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
  // Nothing to overwrite while every attendee is still unplaced
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
  drawError.value = null
  try {
    // splitTeams reads the session's own attendees, so players still waiting to
    // be placed are drawn too — the caller cannot forget them.
    await splitTeams(sessionId)
  } catch (e: any) {
    drawError.value = e?.message || 'Erreur lors du tirage.'
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
  background: var(--surface-2);
  border: 1px solid var(--hairline);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.1rem;
  text-decoration: none;
  color: var(--text-strong);
  transition: background 0.15s ease;
}
.btn-back:active { background: var(--hairline); }

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
  color: var(--accent-text);
  border: 1px solid var(--accent-text);
}

.badge--format {
  background: var(--surface-2);
  color: var(--text-strong);
  border: 1px solid var(--hairline);
}

.badge--ranked {
  color: var(--accent-text);
}

.header-date {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.85rem;
  color: var(--text-muted);
  margin: 0 0 12px;
  text-transform: capitalize;
}

/* Score placeholder bar */
.score-bar-placeholder {
  height: 40px;
  border: 1.5px dashed var(--hairline);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--surface);
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
  color: var(--hairline);
}

.score-sep {
  font-size: 0.7rem;
  color: var(--hairline);
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
  border: 3px solid var(--hairline);
  border-top-color: var(--accent-text);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* Attendees waiting for a team — a flat filet-separated list, not a card grid,
   so it reads as a queue to empty rather than a third team. */
.unassigned {
  background: var(--surface);
  border: 1px solid var(--hairline);
  border-radius: 14px;
  padding: 12px;
  margin-bottom: 14px;
}

.unassigned__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.unassigned__label {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-faint);
  margin: 0;
}

.unassigned__count {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.85rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--accent-text);
}

.unassigned__row {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 48px;
}
.unassigned__row + .unassigned__row {
  border-top: 1px solid var(--hairline);
}

.unassigned__avatar {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  background: var(--surface-2);
  border: 1px solid var(--hairline-2);
  color: var(--text-muted);
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.6rem;
  font-weight: 700;
  flex-shrink: 0;
}

.unassigned__name {
  flex: 1;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-strong);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.unassigned__actions {
  display: flex;
  gap: 6px;
  flex-shrink: 0;
}

/* 44px targets: placing a player is the primary gesture of this screen */
.place-btn {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  cursor: pointer;
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.8rem;
  font-weight: 700;
  transition: all 0.12s ease;
}

.place-btn:active { scale: 0.94; }

/* Team A — solid fill, as everywhere else */
.place-btn--a {
  background: var(--team-a);
  border: none;
  color: var(--ground);
}

/* Team B — the 45° hatch, never a second solid colour */
.place-btn--b {
  background: repeating-linear-gradient(
    45deg,
    var(--surface-2),
    var(--surface-2) 4px,
    transparent 4px,
    transparent 10px
  );
  border: 1.5px solid var(--hairline-2);
  color: var(--text-strong);
}

/* Composition grid */
.composition-grid {
  display: flex;
  gap: 0;
  align-items: flex-start;
  margin-bottom: 12px;
}

.composition-divider {
  width: 1px;
  background: var(--hairline);
  align-self: stretch;
  margin: 0 10px;
  min-height: 200px;
}

/* Split mode badge */
.split-mode-badge {
  text-align: center;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.75rem;
  color: var(--text-faint);
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
  background: linear-gradient(to top, var(--ground) 60%, transparent);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.btn-draw {
  width: 100%;
  height: 48px;
  border-radius: 12px;
  border: 1.5px solid var(--hairline-2);
  background: transparent;
  color: var(--text-strong);
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
  background: var(--surface-2);
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
  background: var(--team-a);
  color: var(--ground);
  font-family: 'Instrument Sans', sans-serif;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s ease;
}

.btn-stats:disabled {
  background: var(--hairline);
  color: var(--text-faint);
  cursor: not-allowed;
}

.btn-stats:not(:disabled):active {
  background: var(--team-a-press);
  scale: 0.98;
}

.footer-hint {
  margin: 8px 0 0;
  text-align: center;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.8rem;
  color: var(--text-muted);
}

.footer-hint--error {
  color: var(--danger-text);
}

.btn-spinner {
  width: 18px;
  height: 18px;
  border: 2.5px solid var(--hairline);
  border-top-color: var(--text-strong);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
</style>
