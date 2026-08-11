<template>
  <div class="new-session-page">
    <!-- Back header -->
    <div class="page-header">
      <NuxtLink to="/sessions" class="btn-back" aria-label="Retour">
        ←
      </NuxtLink>
      <h1 class="page-title">Nouvelle séance</h1>
    </div>

    <form @submit.prevent="handleCreate">
      <!-- Section: QUAND -->
      <section class="form-section">
        <h2 class="section-label">Quand</h2>
        <div class="field-row">
          <label class="field-label" for="played-date">Date</label>
          <input
            id="played-date"
            v-model="dateValue"
            type="date"
            class="field-input"
            required
          />
        </div>
        <div class="field-row">
          <label class="field-label" for="played-time">Heure</label>
          <input
            id="played-time"
            v-model="timeValue"
            type="time"
            class="field-input"
            required
          />
        </div>
      </section>

      <!-- Section: PRÉSENTS -->
      <section class="form-section">
        <div class="section-header">
          <h2 class="section-label">Présents</h2>
          <span class="section-count">{{ selectedCount }} sélectionné(s)</span>
        </div>

        <!-- Select all / none -->
        <div class="attendees-actions">
          <button type="button" class="btn-text" @click="selectAll">Tous</button>
          <span class="divider">·</span>
          <button type="button" class="btn-text" @click="selectNone">Aucun</button>
        </div>

        <!-- Attendee grid -->
        <div class="attendees-grid">
          <AttendeeChip
            v-for="player in attendees"
            :key="player.id"
            :player="player"
            :selected="player.selected"
            @toggle="toggleAttendee"
          />
        </div>

        <!-- Validation warning -->
        <p v-if="showMinWarning" class="warning-text">
          ⚠️ Il faut au moins 4 joueurs pour créer une séance.
        </p>
      </section>

      <!-- Section: OPTIONS -->
      <section class="form-section">
        <h2 class="section-label">Options</h2>

        <div class="toggle-row">
          <div class="toggle-info">
            <span class="toggle-label">Séance classée</span>
            <span class="toggle-hint">Comptabilisée dans les statistiques</span>
          </div>
          <button
            type="button"
            class="toggle-switch"
            :class="{ 'toggle-switch--on': isRanked }"
            role="switch"
            :aria-checked="isRanked"
            @click="isRanked = !isRanked"
          >
            <span class="toggle-knob" />
          </button>
        </div>

        <div class="toggle-row">
          <div class="toggle-info">
            <span class="toggle-label">Effectifs inégaux</span>
            <span class="toggle-hint">Autoriser des équipes de tailles différentes</span>
          </div>
          <button
            type="button"
            class="toggle-switch"
            :class="{ 'toggle-switch--on': allowUneven }"
            role="switch"
            :aria-checked="allowUneven"
            @click="allowUneven = !allowUneven"
          >
            <span class="toggle-knob" />
          </button>
        </div>
      </section>

      <!-- Submit -->
      <div class="form-footer">
        <button
          type="submit"
          class="btn-create"
          :disabled="creating || selectedCount < 4"
        >
          <span v-if="creating" class="btn-spinner" />
          <span v-else>Créer la séance</span>
        </button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { usePlayers } from '~/composables/usePlayers'
import { useSessions } from '~/composables/useSessions'
import type { AttendeePlayer } from '~/types'

useHead({ title: 'Nouvelle séance — Statoo' })

const router = useRouter()

const { playersList, fetchPlayers } = usePlayers()
const { createSession } = useSessions()

// Default date = today, time = 19:00
const now = new Date()
const dateValue = ref(now.toISOString().slice(0, 10))
const timeValue = ref('19:00')

const isRanked = ref(true)
const allowUneven = ref(false)
const creating = ref(false)

// Build attendees list from players
const attendees = ref<AttendeePlayer[]>([])

function buildAttendees() {
  attendees.value = playersList.value.map((p) => ({
    id: p.player_id,
    name: p.name,
    nickname: p.nickname,
    is_active: p.is_active,
    selected: p.is_active === 1, // pre-select active players
  }))
}

const selectedCount = computed(() =>
  attendees.value.filter((a) => a.selected).length
)

const showMinWarning = computed(() => selectedCount.value > 0 && selectedCount.value < 4)

function toggleAttendee(id: string) {
  const a = attendees.value.find((p) => p.id === id)
  if (a) a.selected = !a.selected
}

function selectAll() {
  attendees.value.forEach((a) => (a.selected = true))
}

function selectNone() {
  attendees.value.forEach((a) => (a.selected = false))
}

async function handleCreate() {
  const selected = attendees.value.filter((a) => a.selected)
  if (selected.length < 4) return

  creating.value = true
  try {
    const playedAt = `${dateValue.value}T${timeValue.value}:00`
    const sessionId = await createSession({
      played_at: playedAt,
      is_ranked: isRanked.value,
      allow_uneven_teams: allowUneven.value,
      attendees: selected,
    })
    router.push(`/sessions/${sessionId}/composition`)
  } catch (e) {
    console.error('Failed to create session:', e)
  } finally {
    creating.value = false
  }
}

onMounted(async () => {
  await fetchPlayers()
  buildAttendees()
})
</script>

<style scoped>
.new-session-page {
  padding: 20px 16px 120px;
  min-height: 100vh;
}

/* Header */
.page-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 28px;
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

.page-title {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text);
  margin: 0;
}

/* Sections */
.form-section {
  background: var(--surface);
  border: 1px solid var(--surface-2);
  border-radius: 14px;
  padding: 16px;
  margin-bottom: 14px;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.section-label {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-faint);
  margin: 0 0 12px;
}

.section-count {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.75rem;
  color: var(--accent-text);
  font-weight: 600;
}

/* Date/time fields */
.field-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 0;
}
.field-row + .field-row {
  border-top: 1px solid var(--surface-2);
}

.field-label {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.9rem;
  font-weight: 500;
  color: var(--text-strong);
}

.field-input {
  background: var(--surface-2);
  border: 1px solid var(--hairline);
  border-radius: 8px;
  color: var(--text-strong);
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.9rem;
  padding: 8px 12px;
  height: 44px;
  color-scheme: dark;
  outline: none;
}
.field-input:focus {
  border-color: var(--accent-text);
}

/* Attendees */
.attendees-actions {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-bottom: 12px;
}

.btn-text {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--accent-text);
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
}

.divider {
  color: var(--hairline-2);
}

.attendees-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.warning-text {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.8rem;
  color: var(--danger-text);
  margin: 10px 0 0;
}

/* Toggles */
.toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0;
  gap: 12px;
}
.toggle-row + .toggle-row {
  border-top: 1px solid var(--surface-2);
}

.toggle-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.toggle-label {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.9rem;
  font-weight: 500;
  color: var(--text-strong);
}

.toggle-hint {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.75rem;
  color: var(--text-faint);
}

.toggle-switch {
  width: 48px;
  height: 28px;
  border-radius: 14px;
  border: none;
  background: var(--hairline);
  cursor: pointer;
  position: relative;
  flex-shrink: 0;
  transition: background 0.2s ease;
}

.toggle-switch--on {
  background: var(--team-a);
}

.toggle-knob {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: #fff;
  transition: transform 0.2s ease;
  display: block;
}

.toggle-switch--on .toggle-knob {
  transform: translateX(20px);
}

/* Submit button */
.form-footer {
  padding: 8px 0 20px;
}

.btn-create {
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
  gap: 8px;
  transition: all 0.15s ease;
}

.btn-create:disabled {
  background: var(--hairline);
  color: var(--text-faint);
  cursor: not-allowed;
}

.btn-create:not(:disabled):active {
  background: var(--team-a-press);
  scale: 0.98;
}

.btn-spinner {
  width: 20px;
  height: 20px;
  border: 2.5px solid var(--hairline);
  border-top-color: var(--ground);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }
</style>
