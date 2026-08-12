<script setup lang="ts">
import type { PlayerStats } from '~/types'

/**
 * A secondary ranking card (screen 14): top scorers, top assists, or cards.
 * `variant` picks what sits on the right of each row — a single number, or the
 * yellow/red pair. Rank 1 shows a 🥇 in place of its digit, and keeps the accent
 * colour — the medal replaces the number so the 16px rank column stays put.
 */
defineProps<{
  title: string
  players: PlayerStats[]
  variant?: 'count' | 'cards'
  /** Which numeric field to display when variant is 'count'. */
  field?: 'goals' | 'assists'
  emptyLabel?: string
}>()
</script>

<template>
  <div class="flex flex-col gap-2 rounded-lg border border-hairline bg-surface px-3.5 py-3">
    <span class="text-[11px] font-semibold uppercase tracking-[0.08em] text-text-muted">
      {{ title }}
    </span>

    <p v-if="players.length === 0" class="py-1 text-[13px] text-text-muted">
      {{ emptyLabel ?? 'Rien à afficher pour l’instant.' }}
    </p>

    <!-- Rows are inert: 28px is below the 44px touch target, so they are not
         tappable. The standings table is where you navigate to a player. -->
    <div
      v-for="(player, idx) in players"
      :key="player.player_id"
      class="flex h-7 items-center gap-3"
    >
      <span
        class="w-4 font-display text-[15px] font-medium tnum"
        :class="idx === 0 ? 'text-accent-text' : 'text-text-muted'"
      >{{ idx === 0 ? '🥇' : idx + 1 }}</span>

      <span class="flex-1 truncate text-[15px] text-text">{{ player.name }}</span>

      <span v-if="variant === 'cards'" class="flex items-center gap-1.5">
        <span class="h-2.5 w-0.75 bg-team-a" />
        <span class="w-4.5 text-right font-display text-[15px] font-medium tnum text-text">
          {{ player.yellow_cards }}
        </span>
        <span class="ml-1.5 h-2.5 w-0.75 bg-danger-solid" />
        <span class="w-4.5 text-right font-display text-[15px] font-medium tnum text-text">
          {{ player.red_cards }}
        </span>
      </span>

      <span v-else class="font-display text-[15px] font-medium tnum text-text">
        {{ field === 'assists' ? player.assists : player.goals }}
      </span>
    </div>
  </div>
</template>
