<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
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
        style="width:44px;height:44px;background:transparent;border:1px solid #2A3831;border-radius:8px;color:#EAF0EC;font:400 20px/1 'Instrument Sans',sans-serif;display:flex;align-items:center;justify-content:center;text-decoration:none;"
      >+</NuxtLink>
    </div>

    <!-- Liste ou état vide -->
    <div style="flex:1;padding:8px 16px 16px;display:flex;flex-direction:column;gap:12px;overflow-y:auto;">
      <!-- Loading -->
      <div
        v-if="loading"
        style="display:flex;align-items:center;justify-content:center;padding:48px 0;"
      >
        <span style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">
          Chargement…
        </span>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="sessions.length === 0"
        style="padding:48px 0;text-align:center;display:flex;flex-direction:column;gap:16px;align-items:center;"
      >
        <p style="font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
          Aucune séance. La première prend deux minutes.
        </p>
        <NuxtLink
          to="/sessions/new"
          style="display:inline-block;padding:14px 24px;background:#FFC94F;border-radius:8px;font:600 15px/1 'Instrument Sans',system-ui,sans-serif;color:#0B120F;text-decoration:none;"
        >
          Nouvelle séance
        </NuxtLink>
      </div>

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
