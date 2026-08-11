<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div v-if="open" class="modal-backdrop" @click.self="$emit('cancel')">
        <div class="modal-sheet" role="dialog" aria-modal="true" :aria-labelledby="titleId">
          <!-- Handle bar -->
          <div class="modal-sheet__handle" />

          <h2 :id="titleId" class="modal-sheet__title">
            Remplacer la composition actuelle ?
          </h2>
          <p class="modal-sheet__description">
            Le tirage écrase les équipes que vous avez ajustées à la main.
            Les statistiques déjà saisies sont conservées.
          </p>

          <div class="modal-sheet__actions">
            <button class="btn btn--ghost" type="button" @click="$emit('cancel')">
              Annuler
            </button>
            <button class="btn btn--destructive" type="button" @click="$emit('confirm')">
              🎲 Tirer au sort
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
const props = defineProps<{
  open: boolean
}>()

defineEmits<{
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()

const titleId = useId()
</script>

<style scoped>
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 100;
  display: flex;
  align-items: flex-end;
}

.modal-sheet {
  width: 100%;
  background: var(--color-pitch-900);
  border-top-left-radius: 20px;
  border-top-right-radius: 20px;
  padding: 12px 20px 40px;
  border-top: 1px solid var(--color-pitch-700);
}

.modal-sheet__handle {
  width: 36px;
  height: 4px;
  border-radius: 2px;
  background: var(--color-pitch-600);
  margin: 0 auto 20px;
}

.modal-sheet__title {
  font-family: 'Archivo Expanded', sans-serif;
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--color-pitch-50);
  margin: 0 0 10px;
  text-align: center;
}

.modal-sheet__description {
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.875rem;
  color: var(--color-pitch-400);
  text-align: center;
  line-height: 1.5;
  margin: 0 0 24px;
}

.modal-sheet__actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.btn {
  height: 52px;
  border-radius: 12px;
  font-family: 'Instrument Sans', sans-serif;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: all 0.15s ease;
  width: 100%;
}

.btn--ghost {
  background: transparent;
  border: 1.5px solid var(--color-pitch-600);
  color: var(--color-pitch-200);
}

.btn--ghost:active {
  background: var(--color-pitch-700);
}

.btn--destructive {
  background: #F0503C;
  color: #fff;
}

.btn--destructive:active {
  background: #d43f2c;
}

/* Sheet slide-up transition */
.sheet-enter-active,
.sheet-leave-active {
  transition: opacity 0.25s ease;
}
.sheet-enter-active .modal-sheet,
.sheet-leave-active .modal-sheet {
  transition: transform 0.25s cubic-bezier(0.32, 0.72, 0, 1);
}
.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
}
.sheet-enter-from .modal-sheet,
.sheet-leave-to .modal-sheet {
  transform: translateY(100%);
}
</style>
