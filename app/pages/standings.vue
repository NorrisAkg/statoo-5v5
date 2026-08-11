<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDb } from '~/composables/useDb'
import type { PlayerStats } from '~/types'

const { getDb } = useDb()
const activeTab = ref<'points' | 'perMatch' | 'secondary'>('points')
const players = ref<PlayerStats[]>([])
const rankedCount = ref(0)
const loading = ref(true)

onMounted(async () => {
  const db = getDb()
  if (db) {
    try {
      const resP = await db.query('SELECT * FROM v_player_stats ORDER BY points DESC, points_per_match DESC, played DESC, (goals + assists) DESC, name ASC;')
      players.value = (resP.values || []) as PlayerStats[]

      const resR = await db.query('SELECT total FROM v_ranked_session_count;')
      if (resR.values && resR.values.length > 0) {
        rankedCount.value = Number(resR.values[0].total)
      }
    } finally {
      loading.value = false
    }
  }
})

// Minimum matches needed for eligibility (50% of ranked sessions)
const threshold = computed(() => Math.ceil(rankedCount.value * 0.5))

// Tab 1: Points ranking (all players who played at least 1 match)
const pointsRanking = computed(() => {
  return [...players.value]
    .filter(p => p.played > 0)
    .sort((a, b) => {
      if (b.points !== a.points) return b.points - a.points
      if (b.points_per_match !== a.points_per_match) return b.points_per_match - a.points_per_match
      if (b.played !== a.played) return b.played - a.played
      return a.name.localeCompare(b.name)
    })
})

// Tab 2: Pts/match ranking (eligible players first)
const perMatchRanking = computed(() => {
  return [...players.value]
    .filter(p => p.played > 0 && p.is_eligible === 1)
    .sort((a, b) => {
      if (b.points_per_match !== a.points_per_match) return b.points_per_match - a.points_per_match
      if (b.played !== a.played) return b.played - a.played
      return a.name.localeCompare(b.name)
    })
})

// Ineligible players (under threshold)
const underThresholdPlayers = computed(() => {
  return [...players.value]
    .filter(p => p.played > 0 && p.is_eligible === 0)
    .map(p => ({
      ...p,
      missing: threshold.value - p.played
    }))
    .sort((a, b) => a.missing - b.missing || a.name.localeCompare(b.name))
})

// Tab 3: Secondary rankings (Top scorers, Top assists, Cards)
const topScorers = computed(() => {
  return [...players.value]
    .filter(p => p.goals > 0)
    .sort((a, b) => b.goals - a.goals || a.name.localeCompare(b.name))
    .slice(0, 5)
})

const topAssists = computed(() => {
  return [...players.value]
    .filter(p => p.assists > 0)
    .sort((a, b) => b.assists - a.assists || a.name.localeCompare(b.name))
    .slice(0, 5)
})

const topCards = computed(() => {
  return [...players.value]
    .filter(p => p.yellow_cards > 0 || p.red_cards > 0)
    .sort((a, b) => {
      if (b.yellow_cards !== a.yellow_cards) return b.yellow_cards - a.yellow_cards
      return b.red_cards - a.red_cards
    })
    .slice(0, 5)
})

function formatPtsPerMatch(val: number | null | undefined): string {
  if (val == null) return '0,00'
  return val.toFixed(2).replace('.', ',')
}
</script>

<template>
  <div style="display:flex;flex-direction:column;min-height:100vh;padding:0 16px;box-sizing:border-box;">

    <!-- Header -->
    <div style="height:56px;flex:none;display:flex;align-items:center;">
      <span style="font:600 20px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;">Classement</span>
    </div>

    <!-- Segmented Tab Switcher (3 tabs: Points, Pts/match, Secondaires) -->
    <div style="height:44px;flex:none;display:grid;grid-template-columns:1fr 1fr 1fr;background:#1B2721;border-radius:8px;padding:3px;box-sizing:border-box;gap:3px;margin-bottom:12px;">
      <!-- Tab 1: Points -->
      <button
        @click="activeTab = 'points'"
        style="background:none;border:none;border-radius:6px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;cursor:pointer;padding:0;"
        :style="activeTab === 'points' ? 'background:#121B17;' : ''"
      >
        <span style="font:600 13px/1 'Instrument Sans',system-ui,sans-serif;" :style="activeTab === 'points' ? 'color:#EAF0EC;' : 'color:#8CA096;'">Points</span>
        <span v-if="activeTab === 'points'" style="width:24px;height:2px;background:#FFC94F;"></span>
      </button>

      <!-- Tab 2: Pts/match -->
      <button
        @click="activeTab = 'perMatch'"
        style="background:none;border:none;border-radius:6px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;cursor:pointer;padding:0;"
        :style="activeTab === 'perMatch' ? 'background:#121B17;' : ''"
      >
        <span style="font:600 13px/1 'Instrument Sans',system-ui,sans-serif;" :style="activeTab === 'perMatch' ? 'color:#EAF0EC;' : 'color:#8CA096;'">Pts/match</span>
        <span v-if="activeTab === 'perMatch'" style="width:24px;height:2px;background:#FFC94F;"></span>
      </button>

      <!-- Tab 3: Secondaires -->
      <button
        @click="activeTab = 'secondary'"
        style="background:none;border:none;border-radius:6px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;cursor:pointer;padding:0;"
        :style="activeTab === 'secondary' ? 'background:#121B17;' : ''"
      >
        <span style="font:600 13px/1 'Instrument Sans',system-ui,sans-serif;" :style="activeTab === 'secondary' ? 'color:#EAF0EC;' : 'color:#8CA096;'">Secondaires</span>
        <span v-if="activeTab === 'secondary'" style="width:24px;height:2px;background:#FFC94F;"></span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" style="padding:48px 0;text-align:center;color:#8CA096;font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
      Chargement…
    </div>

    <!-- TAB 1: POINTS & TAB 2: PTS/MATCH -->
    <template v-else-if="activeTab === 'points' || activeTab === 'perMatch'">
      <!-- Empty state -->
      <div v-if="players.length === 0 || (activeTab === 'points' && pointsRanking.length === 0)" style="padding:48px 0;text-align:center;color:#8CA096;font:400 15px/1.45 'Instrument Sans',system-ui,sans-serif;">
        Le classement apparaîtra après la première séance close.
      </div>

      <div v-else style="display:flex;flex-direction:column;flex:1;">
        <!-- Table Header (8 columns grid) -->
        <div style="display:grid;grid-template-columns:18px 1fr 22px 22px 22px 22px 30px 42px;column-gap:6px;align-items:center;height:36px;flex:none;font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">
          <span></span>
          <span>Joueur</span>
          <span style="text-align:right;">J</span>
          <span style="text-align:right;">V</span>
          <span style="text-align:right;">N</span>
          <span style="text-align:right;">D</span>
          <span style="text-align:right;" :style="activeTab === 'points' ? 'color:#EAF0EC;' : ''">Pts</span>
          <span style="text-align:right;" :style="activeTab === 'perMatch' ? 'color:#EAF0EC;' : ''">Pts/m</span>
        </div>

        <!-- Table Body -->
        <div style="flex:none;border-top:1px solid #2A3831;">
          <NuxtLink
            v-for="(p, idx) in (activeTab === 'points' ? pointsRanking : perMatchRanking)"
            :key="p.player_id"
            :to="`/players/${p.player_id}`"
            style="display:grid;grid-template-columns:18px 1fr 22px 22px 22px 22px 30px 42px;column-gap:6px;align-items:center;height:48px;border-bottom:1px solid #2A3831;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:#8CA096;text-decoration:none;"
          >
            <!-- Rank -->
            <span :style="idx === 0 ? 'color:#FFC94F;' : ''">{{ idx + 1 }}</span>
            <!-- Name -->
            <span style="font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#EAF0EC;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ p.name }}</span>
            <!-- J, V, N, D -->
            <span style="text-align:right;">{{ p.played }}</span>
            <span style="text-align:right;">{{ p.wins }}</span>
            <span style="text-align:right;">{{ p.draws }}</span>
            <span style="text-align:right;">{{ p.losses }}</span>
            <!-- Pts -->
            <span style="text-align:right;" :style="activeTab === 'points' ? 'color:#EAF0EC;' : ''">{{ p.points }}</span>
            <!-- Pts/m -->
            <span style="text-align:right;" :style="activeTab === 'perMatch' ? 'color:#EAF0EC;' : ''">{{ formatPtsPerMatch(p.points_per_match) }}</span>
          </NuxtLink>
        </div>

        <!-- Footer Notice / Threshold -->
        <template v-if="activeTab === 'points'">
          <div style="padding-top:14px;font:400 13px/1.4 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
            Seules les séances classées comptent. Il faut {{ threshold }} séances pour figurer au classement Pts/match.
          </div>
        </template>

        <!-- Under threshold section (Pts/match tab) -->
        <template v-else-if="activeTab === 'perMatch' && underThresholdPlayers.length > 0">
          <div style="padding-top:20px;display:flex;flex-direction:column;gap:10px;color:#8CA096;">
            <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;">Sous le seuil</span>
            <div
              v-for="u in underThresholdPlayers"
              :key="u.player_id"
              style="display:flex;align-items:center;gap:10px;height:36px;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;"
            >
              <span style="width:18px;"></span>
              <span>{{ u.name }} — il manque {{ u.missing }} séance{{ u.missing > 1 ? 's' : '' }}</span>
            </div>
          </div>
        </template>
      </div>
    </template>

    <!-- TAB 3: CLASSEMENTS SECONDAIRES (Écran 14) -->
    <template v-else-if="activeTab === 'secondary'">
      <div style="display:flex;flex-direction:column;gap:12px;padding-bottom:24px;">

        <!-- Meilleurs buteurs -->
        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:12px 14px;display:flex;flex-direction:column;gap:8px;">
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Meilleurs buteurs</span>
          <div v-if="topScorers.length === 0" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">Aucun but enregistré.</div>
          <div
            v-else
            v-for="(s, idx) in topScorers"
            :key="s.player_id"
            style="display:flex;align-items:center;gap:12px;height:28px;"
          >
            <span style="width:16px;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;" :style="idx === 0 ? 'color:#FFC94F;' : 'color:#8CA096;'">{{ idx + 1 }}</span>
            <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#EAF0EC;">{{ s.name }}</span>
            <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:#EAF0EC;">{{ s.goals }}</span>
          </div>
        </div>

        <!-- Meilleurs passeurs -->
        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:12px 14px;display:flex;flex-direction:column;gap:8px;">
          <span style="font:600 11px/1 'Instrument Sans',sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Meilleurs passeurs</span>
          <div v-if="topAssists.length === 0" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">Aucune passe enregistrée.</div>
          <div
            v-else
            v-for="(a, idx) in topAssists"
            :key="a.player_id"
            style="display:flex;align-items:center;gap:12px;height:28px;"
          >
            <span style="width:16px;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;" :style="idx === 0 ? 'color:#FFC94F;' : 'color:#8CA096;'">{{ idx + 1 }}</span>
            <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#EAF0EC;">{{ a.name }}</span>
            <span style="font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:#EAF0EC;">{{ a.assists }}</span>
          </div>
        </div>

        <!-- Cartons -->
        <div style="background:#121B17;border:1px solid #2A3831;border-radius:14px;padding:12px 14px;display:flex;flex-direction:column;gap:8px;">
          <span style="font:600 11px/1 'Instrument Sans',system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#8CA096;">Cartons</span>
          <div v-if="topCards.length === 0" style="font:400 13px/1.3 'Instrument Sans',system-ui,sans-serif;color:#556860;">Aucun carton enregistré.</div>
          <div
            v-else
            v-for="(c, idx) in topCards"
            :key="c.player_id"
            style="display:flex;align-items:center;gap:12px;height:28px;"
          >
            <span style="width:16px;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;" :style="idx === 0 ? 'color:#FFC94F;' : 'color:#8CA096;'">{{ idx + 1 }}</span>
            <span style="flex:1;font:400 15px/1.2 'Instrument Sans',system-ui,sans-serif;color:#EAF0EC;">{{ c.name }}</span>
            <div style="display:flex;align-items:center;gap:6px;">
              <!-- Yellow card bar -->
              <span style="width:3px;height:10px;background:#FFC94F;"></span>
              <span style="width:18px;text-align:right;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:#EAF0EC;">{{ c.yellow_cards }}</span>
              <!-- Red card bar -->
              <span style="width:3px;height:10px;background:#FF7361;margin-left:6px;"></span>
              <span style="width:18px;text-align:right;font:500 15px/1.2 'Archivo',system-ui,sans-serif;font-stretch:125%;font-variant-numeric:tabular-nums;color:#EAF0EC;">{{ c.red_cards }}</span>
            </div>
          </div>
        </div>

        <div style="font:400 13px/1.4 'Instrument Sans',system-ui,sans-serif;color:#8CA096;">
          Ces classements comptent toutes les séances, amicales incluses.
        </div>
      </div>
    </template>
  </div>
</template>
