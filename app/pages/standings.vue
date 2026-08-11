<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useStandings } from '~/composables/useStandings'
import StandingsTable from '~/components/ui/StandingsTable.vue'
import RankingCard from '~/components/ui/RankingCard.vue'

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
    <div v-else-if="isEmpty" class="py-12 text-center text-[15px] text-text-muted">
      Le classement apparaîtra après la première séance close.
    </div>

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
