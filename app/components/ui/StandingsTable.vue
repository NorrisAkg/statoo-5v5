<script setup lang="ts">
import type { PlayerStats } from '~/types'

defineProps<{
  players: PlayerStats[]
  activeTab: 'points' | 'perMatch'
  /** Players below the eligibility threshold — the "SOUS LE SEUIL" block. */
  ineligiblePlayers?: PlayerStats[]
}>()

/** French decimals: 2,00 — never 2.00. */
function ptsPerMatch(value: number | null | undefined): string {
  return (value ?? 0).toFixed(2).replace('.', ',')
}

function missingLabel(n: number): string {
  return `il manque ${n} ${n > 1 ? 'séances' : 'séance'}`
}

const MEDALS = ['🥇', '🥈', '🥉'] as const

/**
 * The medal REPLACES the rank digit rather than sitting next to it: the rank
 * column is 18px and the table must fit 390px without horizontal scrolling.
 * It also stops rank 1 from being carried by colour alone.
 */
function rankLabel(idx: number): string {
  return MEDALS[idx] ?? String(idx + 1)
}
</script>

<template>
  <div>
    <!-- Column headers -->
    <div class="standings-row h-9 text-[11px] font-semibold uppercase tracking-[0.08em] text-text-muted">
      <span />
      <span>Joueur</span>
      <span class="text-right">J</span>
      <span class="text-right">V</span>
      <span class="text-right">N</span>
      <span class="text-right">D</span>
      <span class="text-right">Pts</span>
      <span class="text-right">Pts/m</span>
    </div>

    <div class="border-t border-hairline">
      <NuxtLink
        v-for="(player, idx) in players"
        :key="player.player_id"
        :to="`/players/${player.player_id}`"
        class="standings-row h-12 border-b border-hairline font-display font-medium text-[15px] tnum text-text-muted"
      >
        <!-- Podium: medal instead of the digit, rank 1 keeps the accent too -->
        <span :class="idx === 0 ? 'text-accent-text' : ''">{{ rankLabel(idx) }}</span>
        <span class="font-sans font-normal text-text truncate">{{ player.name }}</span>
        <span class="text-right">{{ player.played }}</span>
        <span class="text-right">{{ player.wins }}</span>
        <span class="text-right">{{ player.draws }}</span>
        <span class="text-right">{{ player.losses }}</span>
        <span class="text-right" :class="activeTab === 'points' ? 'text-text' : ''">
          {{ player.points }}
        </span>
        <span class="text-right" :class="activeTab === 'perMatch' ? 'text-text' : ''">
          {{ ptsPerMatch(player.points_per_match) }}
        </span>
      </NuxtLink>
    </div>

    <!-- Under threshold — shown alongside the Pts/match table -->
    <div
      v-if="ineligiblePlayers && ineligiblePlayers.length > 0"
      class="flex flex-col gap-2.5 pt-4 text-text-muted"
    >
      <span class="text-[11px] font-semibold uppercase tracking-[0.08em]">Sous le seuil</span>
      <NuxtLink
        v-for="player in ineligiblePlayers"
        :key="player.player_id"
        :to="`/players/${player.player_id}`"
        class="flex h-9 items-center gap-2.5 text-[15px] text-text-muted"
      >
        <span class="w-[18px]" />
        <span>{{ player.name }} — {{ missingLabel(player.missing_sessions) }}</span>
      </NuxtLink>
    </div>
  </div>
</template>

<style scoped>
/* Fixed grid so the columns line up across header and rows, and so the table
 * fits 390px without horizontal scroll. J is never dropped. */
.standings-row {
  display: grid;
  grid-template-columns: 18px 1fr 22px 22px 22px 22px 30px 42px;
  column-gap: 6px;
  align-items: center;
}
</style>
