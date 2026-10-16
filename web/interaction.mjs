// Rebuilding a view must not interrupt an interaction already in progress.
export function preserveInteraction(root, update) {
  const active = document.activeElement;
  const selector = "input,select,textarea,button,a,[tabindex]";
  function key(node) {
    return JSON.stringify([
      node.tagName,
      node.id,
      node.getAttribute("aria-label"),
      node.matches("button,a") ? node.textContent.trim() : null,
    ]);
  }
  const focused = root.contains(active) ? key(active) : null;
  const index = focused
    ? [...root.querySelectorAll(selector)]
        .filter((node) => key(node) === focused)
        .indexOf(active)
    : -1;
  let selection;
  if (focused && typeof active.selectionStart === "number")
    selection = [
      active.selectionStart,
      active.selectionEnd,
      active.selectionDirection,
    ];
  const scroll = [];
  for (let node = root; node; node = node.parentElement)
    scroll.push([node, node.scrollLeft, node.scrollTop]);

  const result = update();

  if (focused) {
    const replacement = [...root.querySelectorAll(selector)].filter(
      (node) => key(node) === focused,
    )[index];
    if (replacement) {
      replacement.focus({ preventScroll: true });
      if (selection) replacement.setSelectionRange(...selection);
    }
  }
  for (const [node, left, top] of scroll) {
    node.scrollLeft = left;
    node.scrollTop = top;
  }
  return result;
}
