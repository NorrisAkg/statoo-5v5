<template>
  <button
    class="attendee-chip"
    :class="{ 'attendee-chip--selected': selected }"
    type="button"
    :aria-pressed="selected"
    :aria-label="`${player.name}${player.nickname ? ` (${player.nickname})` : ''}`"
    @click="$emit('toggle', player.id)"
  >
    <!-- Avatar initials -->
    <span class="attendee-chip__avatar" :class="{ 'attendee-chip__avatar--selected': selected }">
      {{ initials }}
    </span>
    <!-- Name -->
    <span class="attendee-chip__name">{{ player.nickname || player.name }}</span>
  </button>
</template>

<script setup lang="ts">
import type { AttendeePlayer } from '~/types'

const props = defineProps<{
  player: AttendeePlayer
  selected: boolean
}>()

defineEmits<{
  (e: 'toggle', id: string): void
}>()

const initials = computed(() => {
  const parts = props.player.name.trim().split(/\s+/)
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  }
  return parts[0].slice(0, 2).toUpperCase()
})
</script>

<style scoped>
.attendee-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 52px;
  padding: 0 12px;
  border-radius: 10px;
  border: 1.5px solid var(--color-pitch-600);
  background: var(--color-pitch-800);
  cursor: pointer;
  transition: all 0.15s ease;
  width: 100%;
  text-align: left;
  min-width: 0;
}

.attendee-chip--selected {
  border-color: var(--color-bib-400);
  background: rgba(255, 201, 79, 0.1);
}

.attendee-chip:active {
  scale: 0.97;
}

.attendee-chip__avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--color-pitch-700);
  border: 1.5px solid var(--color-pitch-600);
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.65rem;
  font-weight: 700;
  color: var(--color-pitch-300);
  flex-shrink: 0;
  transition: all 0.15s ease;
}

.attendee-chip__avatar--selected {
  background: var(--color-bib-400);
  border-color: var(--color-bib-400);
  color: var(--color-pitch-950);
}

.attendee-chip__name {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-pitch-100);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attendee-chip--selected .attendee-chip__name {
  color: var(--color-bib-300);
}
</style>
