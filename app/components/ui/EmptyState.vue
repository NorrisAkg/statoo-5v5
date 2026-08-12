<template>
  <div class="empty-state">
    <div class="empty-state__illustration">
      <slot name="illustration" />
    </div>
    <p class="empty-state__text">{{ text }}</p>
    <div v-if="$slots.action" class="empty-state__action">
      <slot name="action" />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  text: string
}>()
</script>

<style scoped>
.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
  padding: 48px 24px;
  text-align: center;
}

.empty-state__illustration {
  color: var(--text-faint);
  animation: bounce-in 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) both;
}

.empty-state__text {
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 15px;
  line-height: 1.5;
  color: var(--text-muted);
  max-width: 240px;
  margin: 0;
}

.empty-state__action {
  margin-top: 4px;
}

@keyframes bounce-in {
  0%   { opacity: 0; transform: scale(0.7) translateY(8px); }
  60%  { opacity: 1; transform: scale(1.06) translateY(-4px); }
  80%  { transform: scale(0.97) translateY(2px); }
  100% { opacity: 1; transform: scale(1) translateY(0); }
}
</style>
