<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useStandings } from '~/composables/useStandings'

const { groupTotals: stats, loading, fetchTotals } = useStandings()

onMounted(fetchTotals)

function formatVal(val: number | null | undefined): string {
  if (val == null) return '0'
  return String(val)
}

function formatFloat(val: number | null | undefined): string {
  if (val == null) return '0,00'
  return val.toFixed(2).replace('.', ',')
}

// The gap is derived by v_group_totals, not recomputed here.
const goalGap = computed(() => Number(stats.value?.unassigned_goals ?? 0))
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;">
      <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;">Statistiques</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" style="padding:48px 0;text-align:center;color:var(--text-muted);font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
      Chargement…
    </div>

    <template v-else>
      <!-- KPI Grid 2 columns -->
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;flex:none;">
        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.sessions_played) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Séances jouées</span>
        </div>

        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.ranked_sessions) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Dont classées</span>
        </div>

        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.active_players) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Joueurs actifs</span>
        </div>

        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_players) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Joueurs au total</span>
        </div>

        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_goals) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Buts totaux</span>
        </div>

        <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px;">
          <span style="font:700 32px/1.05 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatFloat(stats?.goals_per_session) }}</span>
          <span style="font:600 11px/1.2 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Buts par séance</span>
        </div>
      </div>

      <!-- Attribution des buts card -->
      <div style="margin-top:12px;background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px;flex:none;">
        <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Attribution des buts</span>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Buts marqués</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.total_goals) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid var(--hairline);">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Buts attribués à un joueur</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.assigned_goals) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid var(--hairline);">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Écart</span>
          <span
            style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;"
            :style="goalGap > 0 ? 'color:var(--danger-text);' : ''"
          >{{ goalGap }}</span>
        </div>

        <span style="font:400 13px/1.4 'Instrument Sans',system-ui,sans-serif;color:var(--text-muted);">
          Buts marqués sans buteur identifié.
        </span>
      </div>

      <!-- Discipline card -->
      <div style="margin-top:12px;margin-bottom:24px;background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px;flex:none;">
        <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--text-muted);">Discipline</span>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Passes décisives</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.assists) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid var(--hairline);">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons jaunes</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.yellow_cards) }}</span>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;height:32px;border-top:1px solid var(--hairline);">
          <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:var(--text-strong);">Cartons rouges</span>
          <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;">{{ formatVal(stats?.red_cards) }}</span>
        </div>
      </div>
    </template>
  </div>
</template>
