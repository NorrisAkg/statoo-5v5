<template>
  <div class="player-row-wrapper">
    <!-- Underlay Left Action (Revealed on Swipe Right) -->
    <div class="row-actions row-actions--left">
      <button
        class="action-btn action-btn--archive"
        @click.stop="handleArchiveSwipe"
      >
        <UIcon
          :name="player.is_active ? 'i-heroicons-archive-box' : 'i-heroicons-archive-box-x-mark'"
          class="w-5 h-5"
        />
        <span>{{ player.is_active ? 'Archiver' : 'Activer' }}</span>
      </button>
    </div>

    <!-- Underlay Right Action (Revealed on Swipe Left) -->
    <div class="row-actions row-actions--right">
      <button
        class="action-btn action-btn--delete"
        @click.stop="handleDeleteSwipe"
      >
        <UIcon name="i-heroicons-trash" class="w-5 h-5" />
        <span>Supprimer</span>
      </button>
    </div>

    <!-- Foreground Row Content -->
    <div
      class="player-row-content"
      :class="{ 'is-archived': !player.is_active }"
      :style="{
        transform: `translateX(${translateX}px)`,
        transition: isDragging ? 'none' : 'transform 0.2s cubic-bezier(0.16, 1, 0.3, 1)'
      }"
      @touchstart="onTouchStart"
      @touchmove="onTouchMove"
      @touchend="onTouchEnd"
      @mousedown="onMouseDown"
      @mousemove="onMouseMove"
      @mouseup="onMouseUp"
      @mouseleave="onMouseLeave"
      @click="onRowClick"
    >
      <!-- Initials square avatar -->
      <div class="player-avatar">
        {{ initials(player.name) }}
      </div>

      <!-- Name & Nickname -->
      <div class="player-info">
        <span class="player-name">{{ player.name }}</span>
        <span v-if="player.nickname" class="player-nickname">{{ player.nickname }}</span>
      </div>

      <!-- Right numeric columns -->
      <div class="player-stats">
        <span class="stat-col" :class="{ 'stat-col--faint': player.appearances === 0 }">{{ statVal(player.appearances) }}</span>
        <span class="stat-col" :class="{ 'stat-col--faint': player.points === 0 }">{{ statVal(player.points) }}</span>
        <span class="stat-col" :class="{ 'stat-col--faint': player.goals === 0 }">{{ statVal(player.goals) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import type { PlayerStats } from '~/types'

const props = defineProps<{
  player: PlayerStats
}>()

const emit = defineEmits<{
  (e: 'actions', player: PlayerStats): void
  (e: 'delete-confirm', player: PlayerStats): void
  (e: 'archive-confirm', player: PlayerStats): void
}>()

const router = useRouter()

// Gesture State
const translateX = ref(0)
const isDragging = ref(false)
const swipedState = ref<'none' | 'left' | 'right'>('none')

let startX = 0
let startY = 0
let isHorizontalSwipe = false
let isVerticalScroll = false
let longPressTimer: ReturnType<typeof setTimeout> | null = null
let longPressTriggered = false

const MAX_SWIPE_RIGHT = 100 // Archive
const MAX_SWIPE_LEFT = -100 // Delete

function initials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return name.slice(0, 2).toUpperCase()
}

function statVal(val: number | null | undefined): string {
  if (val == null || val === 0) return '—'
  return String(val)
}

function startGesture(x: number, y: number) {
  startX = x
  startY = y
  isHorizontalSwipe = false
  isVerticalScroll = false
  longPressTriggered = false
  isDragging.value = true

  // Start 450ms long press timer
  longPressTimer = setTimeout(() => {
    longPressTriggered = true
    isDragging.value = false
    translateX.value = 0
    swipedState.value = 'none'
    emit('actions', props.player)
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(40)
    }
  }, 450)
}

function moveGesture(x: number, y: number) {
  if (longPressTriggered) return

  const deltaX = x - startX
  const deltaY = y - startY

  if (Math.abs(deltaX) > 8 || Math.abs(deltaY) > 8) {
    cancelLongPress()
  }

  if (!isHorizontalSwipe && !isVerticalScroll) {
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 6) {
      isHorizontalSwipe = true
    } else if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 6) {
      isVerticalScroll = true
    }
  }

  if (isVerticalScroll) return

  if (isHorizontalSwipe) {
    let offset = deltaX
    if (swipedState.value === 'right') {
      offset += MAX_SWIPE_RIGHT
    } else if (swipedState.value === 'left') {
      offset += MAX_SWIPE_LEFT
    }

    // Resistance curves
    if (offset > MAX_SWIPE_RIGHT + 20) {
      const extra = offset - (MAX_SWIPE_RIGHT + 20)
      offset = MAX_SWIPE_RIGHT + 20 + extra * 0.2
    } else if (offset < MAX_SWIPE_LEFT - 20) {
      const extra = offset - (MAX_SWIPE_LEFT - 20)
      offset = MAX_SWIPE_LEFT - 20 + extra * 0.2
    }

    translateX.value = offset
  }
}

function endGesture() {
  cancelLongPress()
  if (longPressTriggered) return

  isDragging.value = false

  if (isHorizontalSwipe) {
    if (translateX.value > MAX_SWIPE_RIGHT / 2) {
      // Swiped right -> Archive
      translateX.value = MAX_SWIPE_RIGHT
      swipedState.value = 'right'
    } else if (translateX.value < MAX_SWIPE_LEFT / 2) {
      // Swiped left -> Delete
      translateX.value = MAX_SWIPE_LEFT
      swipedState.value = 'left'
    } else {
      translateX.value = 0
      swipedState.value = 'none'
    }
  }
}

function cancelLongPress() {
  if (longPressTimer) {
    clearTimeout(longPressTimer)
    longPressTimer = null
  }
}

// Touch Event Handlers
function onTouchStart(e: TouchEvent) {
  if (e.touches.length === 1) {
    startGesture(e.touches[0].clientX, e.touches[0].clientY)
  }
}

function onTouchMove(e: TouchEvent) {
  if (e.touches.length === 1) {
    moveGesture(e.touches[0].clientX, e.touches[0].clientY)
  }
}

function onTouchEnd() {
  endGesture()
}

// Mouse Event Handlers
function onMouseDown(e: MouseEvent) {
  startGesture(e.clientX, e.clientY)
}

function onMouseMove(e: MouseEvent) {
  if (isDragging.value) {
    moveGesture(e.clientX, e.clientY)
  }
}

function onMouseUp() {
  if (isDragging.value) {
    endGesture()
  }
}

function onMouseLeave() {
  if (isDragging.value) {
    endGesture()
  }
}

function onRowClick(e: MouseEvent) {
  if (longPressTriggered) {
    e.preventDefault()
    e.stopPropagation()
    return
  }

  // Reset swipe state on tap if row was swiped open
  if (swipedState.value !== 'none' || Math.abs(translateX.value) > 10) {
    translateX.value = 0
    swipedState.value = 'none'
    e.preventDefault()
    e.stopPropagation()
    return
  }

  // Otherwise navigate to player page
  router.push(`/players/${props.player.player_id}`)
}

function handleArchiveSwipe() {
  translateX.value = 0
  swipedState.value = 'none'
  emit('archive-confirm', props.player)
}

function handleDeleteSwipe() {
  translateX.value = 0
  swipedState.value = 'none'
  emit('delete-confirm', props.player)
}
</script>

<style scoped>
.player-row-wrapper {
  position: relative;
  width: 100%;
  overflow: hidden;
  background: var(--surface-2);
  border-bottom: 1px solid var(--hairline);
}

.row-actions {
  position: absolute;
  top: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  z-index: 1;
}

.row-actions--left {
  left: 0;
}

.row-actions--right {
  right: 0;
}

.action-btn {
  height: 100%;
  border: none;
  padding: 0 18px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  user-select: none;
}

.action-btn--archive {
  background: var(--team-a);
  color: var(--ground);
}

.action-btn--delete {
  background: var(--danger-solid);
  color: #fff;
}

.player-row-content {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 60px;
  background: var(--ground);
  padding: 0 4px;
  cursor: pointer;
  user-select: none;
  touch-action: pan-y;
}

.player-row-content.is-archived {
  opacity: 0.6;
}

.player-avatar {
  width: 36px;
  height: 36px;
  flex: none;
  border-radius: 8px;
  background: var(--surface-2);
  display: flex;
  align-items: center;
  justify-content: center;
  font: 600 13px/1 'Instrument Sans', system-ui, sans-serif;
  color: var(--text-strong);
}

.player-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.player-name {
  font: 400 15px/1.2 'Instrument Sans', system-ui, sans-serif;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text);
}

.player-nickname {
  font: 400 13px/1.2 'Instrument Sans', system-ui, sans-serif;
  color: var(--text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.player-stats {
  display: flex;
  gap: 20px;
  font: 500 15px/1.2 'Archivo', system-ui, sans-serif;
  font-stretch: 125%;
  font-variant-numeric: tabular-nums;
}

.stat-col {
  width: 32px;
  text-align: right;
  color: var(--text-muted);
}

.stat-col--faint {
  color: var(--text-faint);
}
</style>
