<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'

const stats = ref<any>(null)
const loading = ref(true)
const { getDb } = useDb()

onMounted(async () => {
  const db = getDb()
  if (db) {
    try {
      const res = await db.query('SELECT * FROM v_group_totals;')
      if (res.values && res.values.length > 0) {
        stats.value = res.values[0]
      }
    } finally {
      loading.value = false
    }
  }
})

function formatVal(val: number | null | undefined): string {
  if (val == null) return '0'
  return String(val)
}

function formatFloat(val: number | null | undefined): string {
  if (val == null) return '0,00'
  return val.toFixed(2).replace('.', ',')
}

const goalGap = computed(() => {
  if (!stats.value) return 0
  const total = Number(stats.value.total_goals || 0)
  const assigned = Number(stats.value.assigned_goals || 0)
  return Math.max(0, total - assigned)
})
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;">
      <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;">Statistiques</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" style="padding:48px 0;text-align:center;color:#8CA096;font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
      Chargement…
    </div>

    <template v-else>
      <!-- KPI Grid 2 columns -->
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;flex:none;">
        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.sessions_played) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Séances jouées</span>
        </div>

        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.ranked_sessions) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Dont classées</span>
        </div>

        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.active_players) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Joueurs actifs</span>
        </div>

        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_players) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Joueurs au total</span>
        </div>

        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_goals) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Buts totaux</span>
        </div>

        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatFloat(stats?.goals_per_session) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Buts par séance</span>
        </div>
      </div>

      <!-- Attribution des buts card -->
      <div style="margin-top:12px;background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px;flex:none;">
        <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Attribution des buts</span>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#D3DED8;">Buts marqués</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_goals) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid #2A3831;">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#D3DED8;">Buts attribués à un joueur</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.assigned_goals) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid #2A3831;">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#D3DED8;">Écart</span>
          <span
            style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;"
            :style="goalGap > 0 ? 'color:#FF7361;' : ''"
          >{{ goalGap }}</span>
        </div>

        <span style="font:400 13px/1.4 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
          Buts marqués sans buteur identifié.
        </span>
      </div>
    </template>
  </div>
</template>
