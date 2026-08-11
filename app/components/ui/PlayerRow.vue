<script setup lang="ts">
import { computed } from 'vue'
import type { PlayerStats } from '~/types'

const props = defineProps<{
  player: PlayerStats
  showStats?: boolean
}>()

const initials = computed(() => {
  const name = props.player.name || ''
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase()
  }
  return name.slice(0, 2).toUpperCase()
})

const isArchived = computed(() => props.player.is_active === 0)
</script>

<template>
  <div
    class="flex items-center justify-between p-3 rounded-md bg-surface border border-hairline transition-colors hover:border-hairline"
    :class="{ 'opacity-60': isArchived }"
  >
    <!-- Left: Identity -->
    <div class="flex items-center space-x-3 min-w-0">
      <!-- Avatar 36px -->
      <div
        class="w-9 h-9 rounded-full bg-surface-2 border border-hairline flex items-center justify-center font-display text-xs font-bold text-text-strong shrink-0"
        :class="{ 'opacity-50': isArchived }"
      >
        {{ initials }}
      </div>

      <!-- Name & Nickname -->
      <div class="min-w-0 flex-1">
        <div class="flex items-center space-x-2">
          <span class="text-[15px] font-medium text-text truncate">
            {{ player.name }}
          </span>
          <span
            v-if="isArchived"
            class="px-1.5 py-0.5 rounded-xs text-[10px] uppercase font-semibold bg-surface-2 text-text-muted tracking-wider"
          >
            Archivé
          </span>
        </div>
        <div v-if="player.nickname" class="text-[13px] text-text-muted truncate">
          {{ player.nickname }}
        </div>
      </div>
    </div>

    <!-- Right: Stats (J / PTS / BUTS) -->
    <div v-if="showStats" class="flex items-center space-x-4 ml-3 shrink-0 tnum font-display text-sm">
      <div class="text-right">
        <span class="text-text-muted text-xs block font-sans uppercase text-[10px]">J</span>
        <span class="text-text font-bold">{{ player.appearances || 0 }}</span>
      </div>
      <div class="text-right">
        <span class="text-text-muted text-xs block font-sans uppercase text-[10px]">PTS</span>
        <span class="text-accent-text font-bold">{{ player.points || 0 }}</span>
      </div>
      <div class="text-right">
        <span class="text-text-muted text-xs block font-sans uppercase text-[10px]">BUTS</span>
        <span class="text-text font-bold">{{ player.goals || 0 }}</span>
      </div>
    </div>
  </div>
</template>
