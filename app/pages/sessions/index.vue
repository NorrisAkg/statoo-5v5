<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
import EmptyState from '~/components/ui/EmptyState.vue'
import type { Session, SessionSummary } from '~/types'

const { getDb } = useDb()
const sessions = ref<Session[]>([])
const summaries = ref<Record<string, SessionSummary>>({})
const loading = ref(true)

onMounted(async () => {
  const db = getDb()
  if (!db) return
  try {
    const resS = await db.query(`SELECT * FROM sessions ORDER BY played_at DESC;`)
    sessions.value = (resS.values || []) as Session[]

    const resSummaries = await db.query(`SELECT * FROM v_session_summary;`)
    const summaryRows = (resSummaries.values || []) as SessionSummary[]
    for (const s of summaryRows) {
      summaries.value[s.session_id] = s
    }
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div style="display:flex;flex-direction:column;height:100%;">
    <!-- Header -->
    <div
      style="height:56px;flex:none;display:flex;align-items:center;justify-content:space-between;padding:0 16px;"
    >
      <span
        style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;"
      >Séances</span>
      <NuxtLink
        to="/sessions/new"
        style="width:44px;height:44px;background:transparent;border:1px solid var(--hairline);border-radius:8px;color:var(--text);font:400 20px/1 'Instrument Sans',sans-serif;display:flex;align-items:center;justify-content:center;text-decoration:none;"
      >+</NuxtLink>
    </div>

    <!-- Liste ou état vide -->
    <div style="flex:1;padding:8px 16px 16px;display:flex;flex-direction:column;gap:12px;overflow-y:auto;">
      <!-- Loading -->
      <div
        v-if="loading"
        style="display:flex;align-items:center;justify-content:center;padding:48px 0;"
      >
        <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:var(--text-faint);">
          Chargement…
        </span>
      </div>

      <!-- Empty state -->
      <EmptyState
        v-else-if="sessions.length === 0"
        text="Pas encore de séance. La première prend deux minutes."
      >
        <template #illustration>
          <!-- Sleeping football (ball + zzz) -->
          <svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <!-- Ball circle -->
            <circle cx="44" cy="56" r="28" stroke="currentColor" stroke-width="2.5" fill="none"/>
            <!-- Pentagon center -->
            <path d="M44 44 L52 50 L49 60 L39 60 L36 50 Z" stroke="currentColor" stroke-width="2" fill="none"/>
            <!-- Ball seam lines -->
            <path d="M44 28 L44 44 M52 50 L68 46 M49 60 L58 74 M39 60 L30 74 M36 50 L20 46" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
            <!-- zzz -->
            <text x="66" y="36" font-family="Instrument Sans, system-ui, sans-serif" font-size="11" font-weight="700" fill="currentColor" opacity="0.9">z</text>
            <text x="72" y="26" font-family="Instrument Sans, system-ui, sans-serif" font-size="13" font-weight="700" fill="currentColor" opacity="0.7">z</text>
            <text x="79" y="16" font-family="Instrument Sans, system-ui, sans-serif" font-size="15" font-weight="700" fill="currentColor" opacity="0.5">z</text>
          </svg>
        </template>
        <template #action>
          <NuxtLink
            to="/sessions/new"
            style="display:inline-block;padding:14px 24px;background:var(--team-a);border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:var(--ground);text-decoration:none;min-height:44px;display:flex;align-items:center;"
          >
            Nouvelle séance
          </NuxtLink>
        </template>
      </EmptyState>

      <!-- Cards -->
      <SessionCard
        v-else
        v-for="session in sessions"
        :key="session.id"
        :session="session"
        :summary="summaries[session.id] ?? null"
      />
    </div>
  </div>
</template>
