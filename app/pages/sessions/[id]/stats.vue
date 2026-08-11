<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useDb } from '~/composables/useDb'
import { saveWebStore } from '~/lib/db/connection'
import {
  fetchSessionById,
  fetchParticipationsBySessionWithId,
  fetchSessionSummary,
  updateParticipationStats,
  updateSessionScores,
  closeSession,
} from '~/lib/db/queries'
import type { Session, TeamAssignment, SessionSummary } from '~/types'

const route = useRoute()
const router = useRouter()
const { getDb } = useDb()
const sessionId = route.params.id as string

const session = ref<Session | null>(null)
const participations = ref<TeamAssignment[]>([])
const summary = ref<SessionSummary | null>(null)
const loading = ref(true)
const closing = ref(false)
const closeError = ref<string | null>(null)

// Score locals (synced with session)
const scoreA = ref(0)
const scoreB = ref(0)
const unassignedA = ref(0)
const unassignedB = ref(0)

// Accordion open state: participation id -> boolean
const expanded = ref<Record<string, boolean>>({})

// Local stats cache per participation id
const localStats = ref<Record<string, { goals: number; assists: number; yellow_cards: number; red_cards: number }>>({})

const teamA = computed(() => participations.value.filter(p => p.team === 'A'))
const teamB = computed(() => participations.value.filter(p => p.team === 'B'))

// Warning: goals attributed + unassigned != score
const goalMismatch = computed(() => {
  const sumA = teamA.value.reduce((s, p) => s + (localStats.value[p.id]?.goals ?? p.goals), 0)
  const sumB = teamB.value.reduce((s, p) => s + (localStats.value[p.id]?.goals ?? p.goals), 0)
  const mismatchA = sumA + unassignedA.value !== scoreA.value
  const mismatchB = sumB + unassignedB.value !== scoreB.value
  return { mismatchA, mismatchB, sumA, sumB, any: mismatchA || mismatchB }
})

function statLabel(p: TeamAssignment): string {
  const s = localStats.value[p.id]
  const g = s?.goals ?? p.goals
  const a = s?.assists ?? p.assists
  const parts: string[] = []
  if (g > 0) parts.push(`${g} B`)
  if (a > 0) parts.push(`${a} P`)
  return parts.join(' · ')
}

function initLocalStats() {
  for (const p of participations.value) {
    if (!localStats.value[p.id]) {
      localStats.value[p.id] = {
        goals: p.goals,
        assists: p.assists,
        yellow_cards: p.yellow_cards,
        red_cards: p.red_cards,
      }
    }
  }
}

async function load() {
  const db = getDb()
  if (!db) return
  loading.value = true
  try {
    session.value = await fetchSessionById(db, sessionId)
    if (!session.value) return

    // Redirect if already closed
    if (session.value.status === 'CLOSED') {
      router.replace(`/sessions/${sessionId}`)
      return
    }

    scoreA.value = session.value.score_a ?? 0
    scoreB.value = session.value.score_b ?? 0
    unassignedA.value = session.value.unassigned_goals_a ?? 0
    unassignedB.value = session.value.unassigned_goals_b ?? 0

    participations.value = await fetchParticipationsBySessionWithId(db, sessionId)
    summary.value = await fetchSessionSummary(db, sessionId)
    initLocalStats()
  } finally {
    loading.value = false
  }
}

onMounted(load)

// Debounce for saving scores to DB
let scoreTimer: ReturnType<typeof setTimeout> | null = null
function onScoreChange() {
  if (scoreTimer) clearTimeout(scoreTimer)
  scoreTimer = setTimeout(saveScores, 600)
}

async function saveScores() {
  const db = getDb()
  if (!db) return
  await updateSessionScores(db, sessionId, scoreA.value, scoreB.value, unassignedA.value, unassignedB.value)
  await saveWebStore()
  summary.value = await fetchSessionSummary(db, sessionId)
}

watch([scoreA, scoreB, unassignedA, unassignedB], onScoreChange)

// Save individual participation stat
let statTimers: Record<string, ReturnType<typeof setTimeout>> = {}
async function onStatChange(participationId: string) {
  if (statTimers[participationId]) clearTimeout(statTimers[participationId])
  statTimers[participationId] = setTimeout(async () => {
    const db = getDb()
    if (!db) return
    const s = localStats.value[participationId]
    if (!s) return
    await updateParticipationStats(db, participationId, s)
    await saveWebStore()
  }, 600)
}

function setStat(participationId: string, key: 'goals' | 'assists' | 'yellow_cards' | 'red_cards', delta: number) {
  if (!localStats.value[participationId]) return
  const current = localStats.value[participationId][key]
  const next = Math.max(0, current + delta)
  localStats.value[participationId][key] = next
  onStatChange(participationId)
}

function toggleExpand(id: string) {
  expanded.value[id] = !expanded.value[id]
}

async function handleClose() {
  closeError.value = null
  const db = getDb()
  if (!db) return

  if (scoreA.value == null || scoreB.value == null) {
    closeError.value = 'Renseignez les deux scores pour clore.'
    return
  }

  const sum = summary.value
  if (sum && Math.abs(sum.size_a - sum.size_b) > 1 && !session.value?.allow_uneven_teams) {
    closeError.value = `Écart d'effectif trop grand (${sum.size_a}v${sum.size_b}). Activez « Effectifs inégaux » ou ajustez les équipes.`
    return
  }

  closing.value = true
  try {
    // Save scores first
    await updateSessionScores(db, sessionId, scoreA.value, scoreB.value, unassignedA.value, unassignedB.value)
    await closeSession(db, sessionId)
    await saveWebStore()
    router.push(`/sessions/${sessionId}`)
  } catch (e: any) {
    closeError.value = e?.message || 'Erreur lors de la clôture.'
  } finally {
    closing.value = false
  }
}

// ScoreBar widths
const scoreBarWidths = computed(() => {
  const total = scoreA.value + scoreB.value
  if (total === 0) return { a: 50, b: 50 }
  let pA = (scoreA.value / total) * 100
  let pB = (scoreB.value / total) * 100
  if (pA < 5 && scoreA.value > 0) pA = 5
  if (pB < 5 && scoreB.value > 0) pB = 5
  return { a: pA, b: pB }
})
</script>

<template>
  <div v-if="loading" style="padding:24px 16px;color:var(--text-muted);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
    Chargement…
  </div>

  <div v-else-if="session" style="display:flex;flex-direction:column;min-height:100vh;">
    <!-- Scrollable content -->
    <div style="flex:1;overflow-y:auto;display:flex;flex-direction:column;padding:0 16px;">

      <!-- Back button row -->
      <div style="height:56px;flex:none;display:flex;align-items:center;">
        <NuxtLink :to="`/sessions/${sessionId}`" style="display:flex;align-items:center;color:inherit;text-decoration:none;">
          <span style="width:10px;height:10px;border-left:1.5px solid var(--text);border-bottom:1.5px solid var(--text);transform:rotate(45deg);margin-left:4px;display:inline-block;"></span>
        </NuxtLink>
      </div>

      <!-- SCORE SECTION -->
      <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);padding-bottom:8px;">Score</span>

      <div style="display:flex;gap:12px;">
        <!-- Équipe A -->
        <div style="flex:1;display:flex;flex-direction:column;gap:10px;">
          <span style="align-self:flex-start;display:inline-flex;align-items:center;height:26px;padding:0 10px;border-radius:4px;background:var(--team-a);font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ground);">Équipe A</span>
          <div style="display:flex;align-items:center;gap:2px;">
            <button
              @click="scoreA = Math.max(0, scoreA - 1)"
              style="width:48px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;"
              :style="scoreA === 0 ? 'color:var(--hairline-2)' : ''"
              :disabled="scoreA === 0"
            >−</button>
            <span style="flex:1;text-align:center;font:700 44px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ scoreA }}</span>
            <button
              @click="scoreA++"
              style="width:48px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;"
            >+</button>
          </div>
        </div>

        <!-- Équipe B -->
        <div style="flex:1;display:flex;flex-direction:column;gap:10px;">
          <span style="align-self:flex-end;display:inline-flex;align-items:center;height:26px;padding:0 10px;border-radius:4px;border:1px solid var(--hairline);background-color:var(--surface-2);background-image:repeating-linear-gradient(45deg,var(--hatch-line) 0 1px,transparent 1px 6px);font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text);box-sizing:border-box;">Équipe B</span>
          <div style="display:flex;align-items:center;gap:2px;">
            <button
              @click="scoreB = Math.max(0, scoreB - 1)"
              style="width:48px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;"
              :style="scoreB === 0 ? 'color:var(--hairline-2)' : ''"
              :disabled="scoreB === 0"
            >−</button>
            <span style="flex:1;text-align:center;font:700 44px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ scoreB }}</span>
            <button
              @click="scoreB++"
              style="width:48px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;"
            >+</button>
          </div>
        </div>
      </div>

      <!-- ScoreBar 40px -->
      <div style="display:flex;height:40px;flex:none;margin:12px 0 14px;">
        <div :style="`width:${scoreBarWidths.a}%;background:var(--team-a)`"></div>
        <div :style="`width:${scoreBarWidths.b}%;background-color:var(--surface-2);background-image:repeating-linear-gradient(45deg,var(--hatch-line) 0 1px,transparent 1px 7px);box-shadow:inset 0 0 0 1px var(--hairline)`"></div>
      </div>

      <!-- PLAYER LIST ACCORDION — Équipe A then B -->
      <div style="display:flex;flex-direction:column;border-top:1px solid var(--hairline);flex:none;">

        <!-- Équipe A players -->
        <template v-for="p in teamA" :key="p.id">
          <!-- Collapsed row -->
          <div
            v-if="!expanded[p.id]"
            style="display:flex;align-items:center;gap:10px;height:44px;border-bottom:1px solid var(--hairline);cursor:pointer;"
            @click="toggleExpand(p.id)"
          >
            <span style="width:28px;height:28px;border-radius:6px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);flex:none;">
              {{ p.name.slice(0,2).toUpperCase() }}
            </span>
            <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
            <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">{{ statLabel(p) }}</span>
            <span style="width:9px;height:9px;border-right:1.5px solid var(--text-muted);border-bottom:1.5px solid var(--text-muted);transform:rotate(-45deg);flex:none;"></span>
          </div>

          <!-- Expanded row -->
          <div v-else style="background:var(--surface);border-bottom:1px solid var(--hairline);padding:0 10px;">
            <div
              style="display:flex;align-items:center;gap:10px;height:44px;cursor:pointer;"
              @click="toggleExpand(p.id)"
            >
              <span style="width:28px;height:28px;border-radius:6px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);flex:none;">
                {{ p.name.slice(0,2).toUpperCase() }}
              </span>
              <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
              <span style="width:9px;height:9px;border-right:1.5px solid var(--text-muted);border-bottom:1.5px solid var(--text-muted);transform:rotate(-135deg);flex:none;"></span>
            </div>
            <div style="display:flex;flex-direction:column;gap:2px;padding-bottom:6px;">
              <!-- Buts -->
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;">
                <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Buts</span>
                <div style="display:flex;align-items:center;gap:6px;">
                  <button
                    @click.stop="setStat(p.id, 'goals', -1)"
                    :disabled="(localStats[p.id]?.goals ?? 0) === 0"
                    style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;"
                    :style="(localStats[p.id]?.goals ?? 0) === 0 ? 'color:var(--hairline-2);cursor:default' : ''"
                  >−</button>
                  <span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ localStats[p.id]?.goals ?? p.goals }}</span>
                  <button @click.stop="setStat(p.id, 'goals', 1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
                </div>
              </div>
              <!-- Passes -->
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;">
                <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Passes</span>
                <div style="display:flex;align-items:center;gap:6px;">
                  <button @click.stop="setStat(p.id, 'assists', -1)" :disabled="(localStats[p.id]?.assists ?? 0) === 0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.assists ?? 0) === 0 ? 'color:var(--hairline-2);cursor:default' : ''">−</button>
                  <span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ localStats[p.id]?.assists ?? p.assists }}</span>
                  <button @click.stop="setStat(p.id, 'assists', 1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
                </div>
              </div>
              <!-- Cartons jaunes -->
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;">
                <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons jaunes</span>
                <div style="display:flex;align-items:center;gap:6px;">
                  <button @click.stop="setStat(p.id, 'yellow_cards', -1)" :disabled="(localStats[p.id]?.yellow_cards ?? 0) === 0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.yellow_cards ?? 0) === 0 ? 'color:var(--hairline-2);cursor:default' : ''">−</button>
                  <span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ localStats[p.id]?.yellow_cards ?? p.yellow_cards }}</span>
                  <button @click.stop="setStat(p.id, 'yellow_cards', 1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
                </div>
              </div>
              <!-- Cartons rouges -->
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;">
                <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons rouges</span>
                <div style="display:flex;align-items:center;gap:6px;">
                  <button @click.stop="setStat(p.id, 'red_cards', -1)" :disabled="(localStats[p.id]?.red_cards ?? 0) === 0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.red_cards ?? 0) === 0 ? 'color:var(--hairline-2);cursor:default' : ''">−</button>
                  <span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ localStats[p.id]?.red_cards ?? p.red_cards }}</span>
                  <button @click.stop="setStat(p.id, 'red_cards', 1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
                </div>
              </div>
            </div>
          </div>
        </template>

        <!-- Équipe B players — même pattern -->
        <template v-for="p in teamB" :key="p.id">
          <div v-if="!expanded[p.id]" style="display:flex;align-items:center;gap:10px;height:44px;border-bottom:1px solid var(--hairline);cursor:pointer;" @click="toggleExpand(p.id)">
            <span style="width:28px;height:28px;border-radius:6px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);flex:none;">{{ p.name.slice(0,2).toUpperCase() }}</span>
            <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
            <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">{{ statLabel(p) }}</span>
            <span style="width:9px;height:9px;border-right:1.5px solid var(--text-muted);border-bottom:1.5px solid var(--text-muted);transform:rotate(-45deg);flex:none;"></span>
          </div>
          <div v-else style="background:var(--surface);border-bottom:1px solid var(--hairline);padding:0 10px;">
            <div style="display:flex;align-items:center;gap:10px;height:44px;cursor:pointer;" @click="toggleExpand(p.id)">
              <span style="width:28px;height:28px;border-radius:6px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);flex:none;">{{ p.name.slice(0,2).toUpperCase() }}</span>
              <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
              <span style="width:9px;height:9px;border-right:1.5px solid var(--text-muted);border-bottom:1.5px solid var(--text-muted);transform:rotate(-135deg);flex:none;"></span>
            </div>
            <div style="display:flex;flex-direction:column;gap:2px;padding-bottom:6px;">
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;"><span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Buts</span><div style="display:flex;align-items:center;gap:6px;"><button @click.stop="setStat(p.id,'goals',-1)" :disabled="(localStats[p.id]?.goals??0)===0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.goals??0)===0?'color:var(--hairline-2);cursor:default':''">−</button><span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{localStats[p.id]?.goals??p.goals}}</span><button @click.stop="setStat(p.id,'goals',1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button></div></div>
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;"><span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Passes</span><div style="display:flex;align-items:center;gap:6px;"><button @click.stop="setStat(p.id,'assists',-1)" :disabled="(localStats[p.id]?.assists??0)===0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.assists??0)===0?'color:var(--hairline-2);cursor:default':''">−</button><span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{localStats[p.id]?.assists??p.assists}}</span><button @click.stop="setStat(p.id,'assists',1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button></div></div>
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;"><span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons jaunes</span><div style="display:flex;align-items:center;gap:6px;"><button @click.stop="setStat(p.id,'yellow_cards',-1)" :disabled="(localStats[p.id]?.yellow_cards??0)===0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.yellow_cards??0)===0?'color:var(--hairline-2);cursor:default':''">−</button><span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{localStats[p.id]?.yellow_cards??p.yellow_cards}}</span><button @click.stop="setStat(p.id,'yellow_cards',1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button></div></div>
              <div style="display:flex;align-items:center;justify-content:space-between;background:var(--ground);border-radius:8px;padding:0 10px;"><span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons rouges</span><div style="display:flex;align-items:center;gap:6px;"><button @click.stop="setStat(p.id,'red_cards',-1)" :disabled="(localStats[p.id]?.red_cards??0)===0" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="(localStats[p.id]?.red_cards??0)===0?'color:var(--hairline-2);cursor:default':''">−</button><span style="width:44px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{localStats[p.id]?.red_cards??p.red_cards}}</span><button @click.stop="setStat(p.id,'red_cards',1)" style="width:52px;height:52px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 22px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button></div></div>
            </div>
          </div>
        </template>
      </div>

      <!-- BUTS NON ATTRIBUÉS -->
      <div style="padding:14px 0 8px;flex:none;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Buts non attribués</div>
      <div style="display:flex;flex-direction:column;gap:4px;flex:none;padding-bottom:8px;">
        <!-- Équipe A -->
        <div style="display:flex;align-items:center;justify-content:space-between;background:var(--surface);border-radius:8px;padding:6px 10px;">
          <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Équipe A</span>
          <div style="display:flex;align-items:center;gap:6px;">
            <button @click="unassignedA = Math.max(0, unassignedA - 1)" :disabled="unassignedA === 0" style="width:44px;height:44px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 18px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="unassignedA===0?'color:var(--hairline-2);cursor:default':''">−</button>
            <span style="width:36px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ unassignedA }}</span>
            <button @click="unassignedA++" style="width:44px;height:44px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 18px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
          </div>
        </div>
        <!-- Équipe B -->
        <div style="display:flex;align-items:center;justify-content:space-between;background:var(--surface);border-radius:8px;padding:6px 10px;">
          <span style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Équipe B</span>
          <div style="display:flex;align-items:center;gap:6px;">
            <button @click="unassignedB = Math.max(0, unassignedB - 1)" :disabled="unassignedB === 0" style="width:44px;height:44px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 18px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;" :style="unassignedB===0?'color:var(--hairline-2);cursor:default':''">−</button>
            <span style="width:36px;text-align:center;font:700 22px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ unassignedB }}</span>
            <button @click="unassignedB++" style="width:44px;height:44px;background:var(--surface-2);border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 18px/1 'Instrument Sans',system-ui,sans-serif;cursor:pointer;">+</button>
          </div>
        </div>
        <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);padding-top:4px;">Buts marqués sans buteur identifié (csc, oubli).</span>
      </div>
    </div>

    <!-- BOTTOM BAR: warning + button -->
    <div style="flex:none;padding:12px 16px 20px;border-top:1px solid var(--hairline);display:flex;flex-direction:column;gap:12px;">
      <!-- Goal mismatch warning -->
      <div
        v-if="goalMismatch.any"
        style="background:var(--danger-bg);border:1px solid var(--danger-border);border-radius:8px;padding:12px 14px;display:flex;flex-direction:column;gap:4px;"
      >
        <span style="font:600 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--danger-text);">Écart de buts</span>
        <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text);">
          <template v-if="goalMismatch.mismatchA">Équipe A : {{ scoreA }} marqués, {{ goalMismatch.sumA + unassignedA }} attribués. </template>
          <template v-if="goalMismatch.mismatchB">Équipe B : {{ scoreB }} marqués, {{ goalMismatch.sumB + unassignedB }} attribués. </template>
          Vous pouvez clore quand même.
        </span>
      </div>

      <!-- Close error -->
      <div
        v-if="closeError"
        style="background:var(--danger-bg);border:1px solid var(--danger-border);border-radius:8px;padding:12px 14px;"
      >
        <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--danger-text);">{{ closeError }}</span>
      </div>

      <!-- Clôturer button -->
      <button
        @click="handleClose"
        :disabled="closing"
        style="width:100%;height:56px;background:var(--team-a);border:none;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--ground);cursor:pointer;"
        :style="closing ? 'opacity:0.6;cursor:not-allowed' : ''"
      >
        {{ closing ? 'Clôture en cours…' : 'Clôturer la séance' }}
      </button>
    </div>
  </div>
</template>
