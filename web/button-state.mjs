// Shared lifecycle for user-triggered async actions. Background refreshes stay silent.
export function prepareBusyButton(button) {
  if (button.querySelector(".button-spinner")) return;
  const spinner = document.createElement("span");
  spinner.className = "button-spinner";
  spinner.setAttribute("aria-hidden", "true");
  button.prepend(spinner);
}
export async function withBusyButton(button, action) {
  if (button.disabled || button.getAttribute("aria-busy") === "true") return;
  prepareBusyButton(button);
  const scope = button.closest("dialog") || button.closest("form");
  const controls = scope
    ? [...scope.querySelectorAll("button,input,select,textarea")]
    : [button];
  const previous = controls.map((control) => [control, control.disabled]);
  controls.forEach((control) => (control.disabled = true));
  button.setAttribute("aria-busy", "true");
  const preventCancel = (event) => event.preventDefault();
  scope?.addEventListener("cancel", preventCancel);
  try {
    return await action();
  } finally {
    scope?.removeEventListener("cancel", preventCancel);
    button.removeAttribute("aria-busy");
    for (const [control, disabled] of previous) control.disabled = disabled;
  }
}
