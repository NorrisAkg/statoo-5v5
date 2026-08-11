<script setup lang="ts">
import type { PlayerStats } from '~/types'

defineProps<{
  players: PlayerStats[]
  activeTab?: 'points' | 'perMatch'
}>()
</script>

<template>
  <div class="w-full overflow-x-hidden">
    <table class="w-full text-left border-collapse">
      <thead>
        <tr class="border-b border-pitch-700 text-[11px] font-sans font-semibold uppercase text-pitch-300 tracking-wider">
          <th class="py-2 px-1 w-6 text-center">#</th>
          <th class="py-2 px-2">Joueur</th>
          <th class="py-2 px-1 text-right">J</th>
          <th class="py-2 px-1 text-right">V</th>
          <th class="py-2 px-1 text-right">N</th>
          <th class="py-2 px-1 text-right">D</th>
          <th class="py-2 px-1 text-right" :class="{ 'text-pitch-50': activeTab === 'points' }">PTS</th>
          <th class="py-2 px-1 text-right" :class="{ 'text-pitch-50': activeTab === 'perMatch' }">PTS/M</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-pitch-800 text-sm">
        <tr
          v-for="(player, idx) in players"
          :key="player.player_id"
          class="hover:bg-pitch-900/50 transition-colors"
        >
          <!-- Rank -->
          <td class="py-3 px-1 text-center font-display font-bold text-xs" :class="idx === 0 ? 'text-bib-400' : 'text-pitch-300'">
            {{ idx + 1 }}
          </td>

          <!-- Player Identity -->
          <td class="py-3 px-2 font-medium text-pitch-50 truncate max-w-[120px]">
            <NuxtLink :to="`/players/${player.player_id}`" class="hover:underline">
              {{ player.name }}
            </NuxtLink>
          </td>

          <!-- Numbers -->
          <td class="py-3 px-1 text-right tnum font-display text-pitch-300">{{ player.played }}</td>
          <td class="py-3 px-1 text-right tnum font-display text-pitch-300">{{ player.wins }}</td>
          <td class="py-3 px-1 text-right tnum font-display text-pitch-300">{{ player.draws }}</td>
          <td class="py-3 px-1 text-right tnum font-display text-pitch-300">{{ player.losses }}</td>

          <td
            class="py-3 px-1 text-right tnum font-display font-bold"
            :class="activeTab === 'points' ? 'text-pitch-50' : 'text-pitch-300'"
          >
            {{ player.points }}
          </td>

          <td
            class="py-3 px-1 text-right tnum font-display font-bold"
            :class="activeTab === 'perMatch' ? 'text-pitch-50' : 'text-pitch-300'"
          >
            {{ player.points_per_match ? player.points_per_match.toFixed(2) : '0,00' }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
