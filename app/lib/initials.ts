/**
 * Avatar initials for a player name: "Jean Dupont" -> "JD", "Ana" -> "AN".
 *
 * Shared by every avatar in the app — it used to be copy-pasted per component,
 * where indexing straight into `split()` results tripped TypeScript's
 * `noUncheckedIndexedAccess` and would have thrown on an empty or
 * whitespace-only name.
 *
 * Characters are taken with the spread operator rather than `charAt`, so a name
 * starting outside the Basic Multilingual Plane yields a whole character
 * instead of half a surrogate pair.
 */
export function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return ''

  const firstChar = (word: string) => [...word][0] ?? ''

  if (parts.length >= 2) {
    return (firstChar(parts[0]!) + firstChar(parts[parts.length - 1]!)).toUpperCase()
  }

  return [...parts[0]!].slice(0, 2).join('').toUpperCase()
}
