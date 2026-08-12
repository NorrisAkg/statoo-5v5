<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useStandings } from '~/composables/useStandings'
import StandingsTable from '~/components/ui/StandingsTable.vue'
import RankingCard from '~/components/ui/RankingCard.vue'
import EmptyState from '~/components/ui/EmptyState.vue'

type Tab = 'points' | 'perMatch' | 'secondary'
const activeTab = ref<Tab>('points')

const {
  standingsPoints,
  standingsPerMatch,
  ineligiblePlayers,
  requiredSessions,
  topScorers,
  topAssists,
  topCards,
  loading,
  fetchStandings,
  fetchSecondaryRankings,
} = useStandings()

onMounted(async () => {
  await fetchStandings()
  await fetchSecondaryRankings()
})

const rows = computed(() =>
  activeTab.value === 'points' ? standingsPoints.value : standingsPerMatch.value
)

/**
 * Only the two standings tabs can be empty. The secondary rankings count
 * friendlies, so a group that plays nothing but unranked sessions still has
 * top scorers — its cards carry their own empty labels.
 */
const isEmpty = computed(
  () => activeTab.value !== 'secondary' && standingsPoints.value.length === 0
)

function plural(n: number): string {
  return n > 1 ? 'séances' : 'séance'
}

/** Nobody clears the bar: say why rather than show an empty table. */
const noneEligible = computed(
  () => activeTab.value === 'perMatch' && standingsPerMatch.value.length === 0 && !isEmpty.value
)
</script>

<template>
  <div class="flex min-h-screen flex-col px-4">

    <!-- Header -->
    <div class="flex h-14 flex-none items-center">
      <span class="font-display text-xl font-semibold">Classement</span>
    </div>

    <!-- Segmented control -->
    <div class="mb-3 grid h-11 flex-none grid-cols-3 gap-0.75 rounded-lg bg-surface-2 p-0.75">
      <button
        v-for="tab in ([
          { id: 'points', label: 'Points' },
          { id: 'perMatch', label: 'Pts/match' },
          { id: 'secondary', label: 'Secondaires' },
        ] as { id: Tab; label: string }[])"
        :key="tab.id"
        type="button"
        class="flex flex-col items-center justify-center gap-0.75 rounded-md text-[13px]"
        :class="activeTab === tab.id ? 'bg-surface font-semibold text-text' : 'font-medium text-text-muted'"
        @click="activeTab = tab.id"
      >
        <span>{{ tab.label }}</span>
        <span v-if="activeTab === tab.id" class="h-0.5 w-6 bg-team-a" />
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="py-12 text-center text-[15px] text-text-muted">
      Chargement…
    </div>

    <!-- Empty state — covers all three tabs -->
    <EmptyState
      v-else-if="isEmpty"
      text="Le classement s'affiche après la première séance close."
    >
      <template #illustration>
        <!-- Blank scoreboard with dashes -->
        <svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <!-- Board frame -->
          <rect x="8" y="16" width="80" height="56" rx="4" stroke="currentColor" stroke-width="2.5" fill="none"/>
          <!-- Stand -->
          <path d="M48 72 L48 84 M36 84 L60 84" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/>
          <!-- Dashed lines (empty scores) -->
          <line x1="20" y1="38" x2="36" y2="38" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <line x1="20" y1="50" x2="36" y2="50" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <line x1="20" y1="62" x2="36" y2="62" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <!-- Score dashes right column -->
          <line x1="58" y1="38" x2="76" y2="38" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <line x1="58" y1="50" x2="76" y2="50" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <line x1="58" y1="62" x2="76" y2="62" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 3"/>
          <!-- Header line -->
          <line x1="8" y1="28" x2="88" y2="28" stroke="currentColor" stroke-width="1.5"/>
          <!-- ? in center divider -->
          <text x="48" y="58" text-anchor="middle" font-family="Instrument Sans, system-ui, sans-serif" font-size="18" font-weight="700" fill="currentColor" opacity="0.4">—</text>
        </svg>
      </template>
    </EmptyState>

    <!-- Tabs 1 & 2: standings table -->
    <template v-else-if="activeTab === 'points' || activeTab === 'perMatch'">
      <div class="flex flex-1 flex-col pb-6">
        <StandingsTable
          :players="rows"
          :active-tab="activeTab"
          :ineligible-players="activeTab === 'perMatch' ? ineligiblePlayers : undefined"
        />

        <p v-if="noneEligible" class="pt-3.5 text-[13px] leading-[1.4] text-text-muted">
          Personne n'atteint encore le seuil de {{ requiredSessions }} {{ plural(requiredSessions) }}.
        </p>

        <p v-if="activeTab === 'points'" class="pt-3.5 text-[13px] leading-[1.4] text-text-muted">
          Seules les séances classées comptent.
          <template v-if="requiredSessions > 0">
            Il faut {{ requiredSessions }} {{ plural(requiredSessions) }} pour figurer au classement Pts/match.
          </template>
        </p>
      </div>
    </template>

    <!-- Tab 3: secondary rankings (screen 14) -->
    <template v-else>
      <div class="flex flex-col gap-3 pb-6">
        <RankingCard
          title="Meilleurs buteurs"
          :players="topScorers"
          field="goals"
          empty-label="Aucun but enregistré."
        />
        <RankingCard
          title="Meilleurs passeurs"
          :players="topAssists"
          field="assists"
          empty-label="Aucune passe enregistrée."
        />
        <RankingCard
          title="Cartons"
          :players="topCards"
          variant="cards"
          empty-label="Aucun carton enregistré."
        />
        <p class="text-[13px] leading-[1.4] text-text-muted">
          Ces classements comptent toutes les séances, amicales incluses.
        </p>
      </div>
    </template>
  </div>
</template>
