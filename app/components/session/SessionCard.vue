<script setup lang="ts">
import type { Session, SessionSummary } from '~/types'

const props = defineProps<{
  session: Session
  summary?: SessionSummary | null
}>()

const formattedDate = computed(() => {
  const d = new Date(props.session.played_at)
  return d.toLocaleDateString('fr-FR', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  })
})

const formattedTime = computed(() => {
  const d = new Date(props.session.played_at)
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
})

const scoreText = computed(() => {
  if (
    props.session.status === 'CLOSED' &&
    props.session.score_a != null &&
    props.session.score_b != null
  ) {
    return `${props.session.score_a} — ${props.session.score_b}`
  }
  return '—'
})

// Goal mismatch indicator (red dot) only for closed sessions
const hasGoalMismatch = computed(() =>
  props.session.status === 'CLOSED' && props.summary?.has_goal_mismatch === 1
)

// ScoreBar widths
const scoreBarWidths = computed(() => {
  const a = props.session.score_a ?? 0
  const b = props.session.score_b ?? 0
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
  <NuxtLink
    :to="`/sessions/${session.id}`"
    style="display:block;background:var(--surface);border:1px solid var(--hairline);border-radius:14px;overflow:hidden;text-decoration:none;color:inherit;"
  >
    <!-- ScoreBar 2px full-width en haut (avant padding) -->
    <template v-if="session.status === 'CLOSED' && session.score_a != null">
      <div style="display:flex;height:2px;">
        <div :style="`width:${scoreBarWidths.a}%;background:var(--team-a)`"></div>
        <div
          :style="`width:${scoreBarWidths.b}%;background-color:var(--surface-2);background-image:repeating-linear-gradient(45deg,var(--hatch-line) 0 1px,transparent 1px 3px)`"
        ></div>
      </div>
    </template>
    <!-- Brouillon : barre dashed -->
    <template v-else>
      <div style="height:2px;border-top:1px dashed var(--hairline-2);"></div>
    </template>

    <!-- Contenu de la carte -->
    <div style="display:flex;align-items:center;gap:10px;padding:14px;">
      <!-- Indicateur mismatch buts (point rouge) -->
      <span
        v-if="hasGoalMismatch"
        style="width:6px;height:6px;border-radius:3px;background:var(--danger-text);flex:none;"
      ></span>

      <!-- Date (+ heure si présente) -->
      <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;">
        {{ formattedDate }}
        <template v-if="session.status === 'CLOSED' || true">
          · {{ formattedTime }}
        </template>
      </span>

      <!-- Badges: format + ranked/amical -->
      <template v-if="summary && session.status === 'CLOSED'">
        <span
          style="border:1px solid var(--hairline-2);border-radius:4px;padding:3px 8px;font:500 13px/1 'Instrument Sans',system-ui,sans-serif;font-variant-numeric:tabular-nums;color:var(--text-strong);"
        >{{ summary.format }}</span>
        <span
          v-if="!session.is_ranked"
          style="border:1px solid var(--hairline-2);border-radius:4px;padding:3px 8px;font:500 13px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);"
        >Amical</span>
      </template>
      <template v-else>
        <!-- Brouillon badge -->
        <span
          style="border:1px solid var(--hairline-2);border-radius:4px;padding:3px 8px;font:500 13px/1 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);"
        >Brouillon</span>
      </template>

      <!-- Score -->
      <span
        style="margin-left:auto;font:600 18px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;"
        :style="session.status === 'DRAFT' ? 'color:var(--text-faint)' : 'color:var(--text)'"
      >{{ scoreText }}</span>
    </div>
  </NuxtLink>
</template>
