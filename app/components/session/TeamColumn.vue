<template>
  <div class="team-column" :class="`team-column--${team.toLowerCase()}`">
    <!-- Team header pill -->
    <div class="team-column__header" :class="`team-column__header--${team.toLowerCase()}`">
      <span class="team-column__label">Équipe {{ team }}</span>
      <span class="team-column__count">{{ players.length }}</span>
    </div>

    <!-- Player list -->
    <div class="team-column__players">
      <div
        v-for="player in players"
        :key="player.player_id"
        class="player-chip"
      >
        <!-- Avatar -->
        <span class="player-chip__avatar" :class="`player-chip__avatar--${team.toLowerCase()}`">
          {{ getInitials(player.name) }}
        </span>
        <!-- Name -->
        <span class="player-chip__name">{{ player.nickname || player.name }}</span>
        <!-- Swap button -->
        <button
          class="player-chip__swap"
          type="button"
          :aria-label="`Déplacer ${player.name} vers l'équipe ${otherTeam}`"
          :title="`→ Éq. ${otherTeam}`"
          @click="$emit('swap', player.player_id, otherTeam)"
        >
          <span class="swap-icon">{{ team === 'A' ? '→' : '←' }}</span>
        </button>
      </div>

      <!-- Empty state -->
      <div v-if="players.length === 0" class="team-column__empty">
        <span class="empty-icon">⚽</span>
        <span>Aucun joueur</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { TeamAssignment, Team } from '~/types'
import { getInitials } from '~/lib/initials'

const props = defineProps<{
  team: Team
  players: TeamAssignment[]
}>()

defineEmits<{
  (e: 'swap', playerId: string, toTeam: Team): void
}>()

const otherTeam = computed<Team>(() => (props.team === 'A' ? 'B' : 'A'))
</script>

<style scoped>
.team-column {
  display: flex;
  flex-direction: column;
  gap: 0;
  flex: 1;
  min-width: 0;
}

/* ---- Header pill ---- */
.team-column__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 12px;
  border-radius: 8px;
  margin-bottom: 10px;
}

/* Team A — solid Bib Yellow */
.team-column__header--a {
  background: var(--team-a);
}
.team-column__header--a .team-column__label,
.team-column__header--a .team-column__count {
  color: var(--ground);
}

/* Team B — hatched pattern */
.team-column__header--b {
  background: repeating-linear-gradient(
    45deg,
    var(--surface-2),
    var(--surface-2) 4px,
    transparent 4px,
    transparent 10px
  );
  border: 1.5px solid var(--hairline-2);
}
.team-column__header--b .team-column__label,
.team-column__header--b .team-column__count {
  color: var(--text-strong);
}

.team-column__label {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.team-column__count {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.9rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* ---- Player chips ---- */
.team-column__players {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.player-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 44px;
  background: var(--surface-2);
  border: 1px solid var(--hairline);
  border-radius: 8px;
  padding: 0 8px 0 6px;
}

.player-chip__avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 0.6rem;
  font-weight: 700;
  flex-shrink: 0;
}

.player-chip__avatar--a {
  color: var(--accent-text);
  border: 1.5px solid var(--accent-text);
}

.player-chip__avatar--b {
  background: var(--hairline);
  color: var(--text-muted);
  border: 1.5px solid var(--hairline-2);
}

.player-chip__name {
  flex: 1;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--text-strong);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.player-chip__swap {
  width: 30px;
  height: 30px;
  border-radius: 6px;
  border: 1px solid var(--hairline-2);
  background: var(--hairline);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.12s ease;
  flex-shrink: 0;
}

.player-chip__swap:active {
  background: var(--hairline-2);
  scale: 0.92;
}

.swap-icon {
  font-size: 0.85rem;
  color: var(--text-muted);
}

/* ---- Empty state ---- */
.team-column__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 24px 0;
  color: var(--hairline-2);
  border: 1.5px dashed var(--hairline);
  border-radius: 8px;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.8rem;
}

.empty-icon {
  font-size: 1.5rem;
  opacity: 0.4;
}
</style>
