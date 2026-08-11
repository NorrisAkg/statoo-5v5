<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
import type { Session, SessionSummary, PlayerStats } from '~/types'

const { getDb } = useDb()

const lastSession = ref<Session | null>(null)
const lastSummary = ref<SessionSummary | null>(null)
const topPlayers = ref<PlayerStats[]>([])
const loading = ref(true)

onMounted(async () => {
  const db = getDb()
  if (!db) return
  try {
    // Get last closed or draft session
    const resS = await db.query('SELECT * FROM sessions ORDER BY played_at DESC LIMIT 1;')
    if (resS.values && resS.values.length > 0) {
      lastSession.value = resS.values[0] as Session
      const resSum = await db.query('SELECT * FROM v_session_summary WHERE session_id = ?;', [lastSession.value.id])
      if (resSum.values && resSum.values.length > 0) {
        lastSummary.value = resSum.values[0] as SessionSummary
      }
    }

    // Get Top 3 players from standings
    const resP = await db.query('SELECT * FROM v_standings LIMIT 3;')
    topPlayers.value = (resP.values || []) as PlayerStats[]
  } finally {
    loading.value = false
  }
})

const formattedDate = computed(() => {
  if (!lastSession.value) return ''
  const d = new Date(lastSession.value.played_at)
  return d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })
})

const formattedTime = computed(() => {
  if (!lastSession.value) return ''
  const d = new Date(lastSession.value.played_at)
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
})

const scoreBarWidths = computed(() => {
  const a = lastSession.value?.score_a ?? 0
  const b = lastSession.value?.score_b ?? 0
  const total = a + b
  if (total === 0) return { a: 50, b: 50 }
  let pA = (a / total) * 100
  let pB = (b / total) * 100
  if (pA < 5 && a > 0) pA = 5
  if (pB < 5 && b > 0) pB = 5
  return { a: pA, b: pB }
})
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;justify-content:space-between;padding:0 16px;">
      <span style="font:700 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;color:var(--text);">Statoo</span>
      <NuxtLink
        to="/settings"
        style="width:20px;height:20px;border:2px solid var(--text-muted);border-radius:10px;box-sizing:border-box;display:inline-block;"
        title="Réglages"
      ></NuxtLink>
    </div>

    <!-- Content Area -->
    <div style="flex:1;display:flex;flex-direction:column;gap:16px;padding:8px 16px 16px;">

      <!-- Loading -->
      <div v-if="loading" style="padding:24px 0;color:var(--text-muted);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
        Chargement…
      </div>

      <template v-else>
        <!-- Card: Dernière séance -->
        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:12px;">
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Dernière séance</span>

          <template v-if="lastSession && lastSession.status === 'CLOSED'">
            <!-- ScoreBar 6px -->
            <div style="display:flex;height:6px;border-radius:1px;overflow:hidden;">
              <div :style="`width:${scoreBarWidths.a}%;background:var(--team-a)`"></div>
              <div :style="`width:${scoreBarWidths.b}%;background-color:var(--surface-2);background-image:repeating-linear-gradient(45deg,var(--hatch-line) 0 1px,transparent 1px 6px);box-shadow:inset 0 0 0 1px var(--hairline)`"></div>
            </div>

            <!-- Scores row -->
            <div style="display:flex;justify-content:space-between;align-items:flex-start;">
              <div style="display:flex;flex-direction:column;gap:4px;">
                <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:var(--text);">{{ lastSession.score_a }}</span>
                <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">Équipe A</span>
              </div>
              <div style="display:flex;flex-direction:column;gap:4px;align-items:flex-end;">
                <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:var(--text);">{{ lastSession.score_b }}</span>
                <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">Équipe B</span>
              </div>
            </div>

            <div style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
              {{ formattedDate }} · {{ formattedTime }} · {{ lastSummary?.format || '5v5' }}
            </div>
          </template>

          <template v-else-if="lastSession">
            <!-- Draft Session Card preview -->
            <div style="height:6px;border-top:1px dashed var(--hairline-2);"></div>
            <div style="font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
              Séance en cours (brouillon) · {{ formattedDate }}
            </div>
            <NuxtLink
              :to="`/sessions/${lastSession.id}/stats`"
              style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--accent-text);text-decoration:none;"
            >Continuer la séance</NuxtLink>
          </template>

          <template v-else>
            <div style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
              Aucune séance enregistrée pour l'instant.
            </div>
          </template>
        </div>

        <!-- Primary Action Button: Nouvelle séance -->
        <NuxtLink
          to="/sessions/new"
          style="display:block;height:56px;flex:none;background:var(--team-a);border:none;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--ground);text-align:center;line-height:56px;text-decoration:none;"
        >
          Nouvelle séance
        </NuxtLink>

        <!-- Card: Top 3 Classement -->
        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:12px;">
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Classement</span>

          <div v-if="topPlayers.length === 0" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
            Le classement s'affichera après la première séance clôturée.
          </div>

          <template v-else>
            <div
              v-for="(p, idx) in topPlayers"
              :key="p.player_id"
              style="display:flex;align-items:center;gap:12px;"
            >
              <span
                style="width:16px;font:600 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;"
                :style="idx === 0 ? 'color:var(--accent-text);' : 'color:var(--text-muted);'"
              >{{ idx + 1 }}</span>
              <span style="flex:1;font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;color:var(--text);">{{ p.name }}</span>
              <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:var(--text);">{{ p.points }}</span>
            </div>

            <div style="padding-top:4px;border-top:1px solid var(--hairline);margin-top:4px;">
              <NuxtLink to="/standings" style="font:500 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--accent-text);text-decoration:none;">
                Voir le classement
              </NuxtLink>
            </div>
          </template>
        </div>

        <!-- Footer Backup Status -->
        <div style="margin-top:auto;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);padding:12px 0;">
          Sauvegardé récemment
        </div>
      </template>

    </div>
  </div>
</template>
