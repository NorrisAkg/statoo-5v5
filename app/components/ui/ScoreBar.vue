<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    scoreA?: number | null
    scoreB?: number | null
    status?: 'DRAFT' | 'CLOSED'
    size?: 'xs' | 'sm' | 'md' | 'lg'
  }>(),
  {
    scoreA: 0,
    scoreB: 0,
    status: 'CLOSED',
    size: 'sm',
  }
)

const heightClass = computed(() => {
  switch (props.size) {
    case 'xs': return 'h-[2px]'
    case 'sm': return 'h-[6px]'
    case 'md': return 'h-[20px]'
    case 'lg': return 'h-[40px]'
    default: return 'h-[6px]'
  }
})

const isDraft = computed(() => props.status === 'DRAFT')

const percentages = computed(() => {
  const a = props.scoreA ?? 0
  const b = props.scoreB ?? 0
  const total = a + b

  if (total === 0) {
    return { percentA: 50, percentB: 50 }
  }

  let pctA = (a / total) * 100
  let pctB = (b / total) * 100

  // Minimum 5% per side if a team has goals but would round to very thin
  if (pctA < 5 && a > 0) pctA = 5
  if (pctB < 5 && b > 0) pctB = 5

  return { percentA: pctA, percentB: pctB }
})
</script>

<template>
  <div
    class="w-full rounded-xs overflow-hidden relative border border-pitch-700 flex transition-all duration-300"
    :class="[
      heightClass,
      isDraft ? 'border-dashed border-pitch-600 bg-pitch-900' : 'bg-pitch-900'
    ]"
    role="img"
    :aria-label="`Équipe A ${scoreA ?? 0}, Équipe B ${scoreB ?? 0}`"
  >
    <template v-if="!isDraft">
      <!-- Team A: Solid Bib Yellow -->
      <div
        class="bg-bib-400 h-full transition-all duration-300"
        :style="{ width: `${percentages.percentA}%` }"
      />
      <!-- Separator line -->
      <div class="w-[1px] bg-pitch-950 h-full shrink-0" />
      <!-- Team B: 45° Diagonal Hatching -->
      <div
        class="bg-team-b-hatch h-full transition-all duration-300 flex-1"
        :style="{ width: `${percentages.percentB}%` }"
      />
    </template>
  </div>
</template>
