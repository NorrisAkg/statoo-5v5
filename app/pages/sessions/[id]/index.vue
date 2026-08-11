<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useDb } from '~/composables/useDb'
import { saveWebStore } from '~/lib/db/connection'
import {
  fetchSessionById,
  fetchParticipationsBySessionWithId,
  fetchSessionSummary,
  reopenSession,
  deleteSession,
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
const actionPending = ref(false)

const teamA = computed(() => participations.value.filter(p => p.team === 'A'))
const teamB = computed(() => participations.value.filter(p => p.team === 'B'))

const formattedDate = computed(() => {
  if (!session.value) return ''
  const d = new Date(session.value.played_at)
  return d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'long' })
})

const formattedTime = computed(() => {
  if (!session.value) return ''
  const d = new Date(session.value.played_at)
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
})

function statSummary(p: TeamAssignment): string {
  const parts: string[] = []
  if (p.goals > 0) parts.push(`${p.goals} B`)
  if (p.assists > 0) parts.push(`${p.assists} P`)
  if (p.yellow_cards > 0) parts.push(`${p.yellow_cards} CJ`)
  if (p.red_cards > 0) parts.push(`${p.red_cards} CR`)
  return parts.join(' · ')
}

const scoreBarWidths = computed(() => {
  const a = session.value?.score_a ?? 0
  const b = session.value?.score_b ?? 0
  const total = a + b
  if (total === 0) return { a: 50, b: 50 }
  let pA = (a / total) * 100
  let pB = (b / total) * 100
  if (pA < 5 && a > 0) pA = 5
  if (pB < 5 && b > 0) pB = 5
  return { a: pA, b: pB }
})

async function load() {
  const db = getDb()
  if (!db) return
  loading.value = true
  try {
    session.value = await fetchSessionById(db, sessionId)
    if (!session.value) return
    participations.value = await fetchParticipationsBySessionWithId(db, sessionId)
    summary.value = await fetchSessionSummary(db, sessionId)
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function handleReopen() {
  const db = getDb()
  if (!db || actionPending.value) return
  actionPending.value = true
  try {
    await reopenSession(db, sessionId)
    await saveWebStore()
    router.push(`/sessions/${sessionId}/stats`)
  } finally {
    actionPending.value = false
  }
}

async function handleDelete() {
  if (!confirm('Supprimer cette séance ? Cette action est irréversible.')) return
  const db = getDb()
  if (!db || actionPending.value) return
  actionPending.value = true
  try {
    await deleteSession(db, sessionId)
    await saveWebStore()
    router.push('/sessions')
  } finally {
    actionPending.value = false
  }
}
</script>

<template>
  <div v-if="loading" style="padding:24px 16px;color:#8CA096;font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
    Chargement…
  </div>

  <div v-else-if="session" style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Back button row -->
    <div style="height:56px;flex:none;display:flex;align-items:center;">
      <NuxtLink to="/sessions" style="display:flex;align-items:center;color:inherit;text-decoration:none;">
        <span style="width:10px;height:10px;border-left:1.5px solid #EAF0EC;border-bottom:1.5px solid #EAF0EC;transform:rotate(45deg);margin-left:4px;display:inline-block;"></span>
      </NuxtLink>
    </div>

    <!-- DRAFT mode -->
    <template v-if="session.status === 'DRAFT'">
      <div style="display:flex;flex-direction:column;gap:16px;padding-top:16px;">
        <div style="height:40px;border:1px dashed #3F4E48;border-radius:2px;"></div>
        <div style="display:flex;justify-content:space-between;align-items:flex-start;">
          <span style="font:700 44px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;color:#3F4E48;">— —</span>
          <span style="border:1px solid #3F4E48;border-radius:4px;padding:3px 8px;font:500 13px/1 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">Brouillon</span>
        </div>
        <div style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
          {{ summary?.format ?? '?' }} · {{ summary?.attendance ?? 0 }} présents
        </div>
        <NuxtLink
          :to="`/sessions/${sessionId}/stats`"
          style="display:block;height:56px;background:#FFC94F;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:#0B120F;text-align:center;line-height:56px;text-decoration:none;margin-top:16px;"
        >Saisir les stats</NuxtLink>
        <button @click="handleDelete" style="background:none;border:none;font:500 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#FF7361;cursor:pointer;padding:0;text-align:left;">Supprimer</button>
      </div>
    </template>

    <!-- CLOSED mode -->
    <template v-else>
      <!-- ScoreBar 40px full-width (compensate padding) -->
      <div style="margin:0 -16px;display:flex;height:40px;">
        <div :style="`width:${scoreBarWidths.a}%;background:#FFC94F`"></div>
        <div :style="`width:${scoreBarWidths.b}%;background-color:#1B2721;background-image:repeating-linear-gradient(45deg,#8CA096 0 1px,transparent 1px 7px);box-shadow:inset 0 0 0 1px #2A3831`"></div>
      </div>

      <!-- Scores -->
      <div style="display:flex;justify-content:space-between;align-items:flex-start;padding-top:12px;">
        <div style="display:flex;flex-direction:column;gap:4px;">
          <span style="font:700 44px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ session.score_a }}</span>
          <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">Équipe A</span>
        </div>
        <div style="display:flex;flex-direction:column;gap:4px;align-items:flex-end;">
          <span style="font:700 44px/1 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ session.score_b }}</span>
          <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">Équipe B</span>
        </div>
      </div>

      <div style="padding-top:12px;font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
        {{ formattedDate }} · {{ formattedTime }} · {{ summary?.format ?? '?' }}
      </div>

      <!-- Teams columns -->
      <div style="display:flex;padding-top:24px;flex:1;">
        <div style="flex:1;display:flex;flex-direction:column;gap:8px;padding-right:12px;">
          <span style="align-self:flex-start;display:inline-flex;align-items:center;height:26px;padding:0 10px;border-radius:4px;background:#FFC94F;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#0B120F;">Équipe A</span>
          <div v-for="p in teamA" :key="p.id" style="display:flex;align-items:baseline;justify-content:space-between;min-height:32px;">
            <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
            <span v-if="statSummary(p)" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">{{ statSummary(p) }}</span>
          </div>
          <div v-if="(session.unassigned_goals_a ?? 0) > 0" style="padding-top:8px;border-top:1px solid #2A3831;font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">Buts non attribués · {{ session.unassigned_goals_a }}</div>
        </div>

        <div style="width:1px;background:#2A3831;"></div>

        <div style="flex:1;display:flex;flex-direction:column;gap:8px;padding-left:12px;">
          <span style="align-self:flex-end;display:inline-flex;align-items:center;height:26px;padding:0 10px;border-radius:4px;border:1px solid #2A3831;background-color:#1B2721;background-image:repeating-linear-gradient(45deg,#8CA096 0 1px,transparent 1px 6px);font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#EAF0EC;box-sizing:border-box;">Équipe B</span>
          <div v-for="p in teamB" :key="p.id" style="display:flex;align-items:baseline;justify-content:space-between;min-height:32px;">
            <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">{{ p.name }}</span>
            <span v-if="statSummary(p)" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">{{ statSummary(p) }}</span>
          </div>
          <div v-if="(session.unassigned_goals_b ?? 0) > 0" style="padding-top:8px;border-top:1px solid #2A3831;font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">Buts non attribués · {{ session.unassigned_goals_b }}</div>
        </div>
      </div>

      <!-- Actions bas de page -->
      <div style="margin-top:auto;display:flex;flex-direction:column;gap:16px;padding:20px 0 24px;border-top:1px solid #2A3831;">
        <button @click="handleReopen" :disabled="actionPending" style="background:none;border:none;font:500 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#EAF0EC;cursor:pointer;padding:0;text-align:left;">Rouvrir la séance</button>
        <button @click="handleDelete" :disabled="actionPending" style="background:none;border:none;font:500 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#FF7361;cursor:pointer;padding:0;text-align:left;">Supprimer</button>
      </div>
    </template>
  </div>
</template>
