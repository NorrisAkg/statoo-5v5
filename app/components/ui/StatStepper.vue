<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    modelValue: number
    min?: number
    max?: number
    label?: string
  }>(),
  {
    min: 0,
    max: 99,
  }
)

const emit = defineEmits<{
  (e: 'update:modelValue', value: number): void
}>()

function decrement() {
  if (props.modelValue > props.min) {
    emit('update:modelValue', props.modelValue - 1)
  }
}

function increment() {
  if (props.modelValue < props.max) {
    emit('update:modelValue', props.modelValue + 1)
  }
}
</script>

<template>
  <div class="flex items-center justify-between py-1.5">
    <span v-if="label" class="text-[13px] text-text-muted font-medium select-none">
      {{ label }}
    </span>
    <div class="flex items-center space-x-1.5 ml-auto">
      <!-- Decrement button (52px min touch target) -->
      <button
        type="button"
        @click="decrement"
        :disabled="modelValue <= min"
        class="w-[52px] h-[44px] flex items-center justify-center rounded-md bg-surface-2 border border-hairline text-text text-xl font-bold transition-opacity active:scale-95 disabled:opacity-40 disabled:pointer-events-none cursor-pointer"
        aria-label="Diminuer"
      >
        −
      </button>

      <!-- Value container -->
      <div class="w-[44px] h-[44px] flex items-center justify-center font-display text-[22px] font-bold text-text tnum select-none">
        {{ modelValue }}
      </div>

      <!-- Increment button (52px min touch target) -->
      <button
        type="button"
        @click="increment"
        :disabled="modelValue >= max"
        class="w-[52px] h-[44px] flex items-center justify-center rounded-md bg-surface-2 border border-hairline text-text text-xl font-bold transition-opacity active:scale-95 disabled:opacity-40 disabled:pointer-events-none cursor-pointer"
        aria-label="Augmenter"
      >
        +
      </button>
    </div>
  </div>
</template>
