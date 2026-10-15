export function apiAddress(config, origin) {
  const value = config.api_url?.trim() || origin;
  let url;
  try {
    url = new URL(value);
  } catch {
    throw Error("La configuration du serveur est invalide.");
  }
  if (
    !["http:", "https:"].includes(url.protocol) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash
  )
    throw Error("La configuration du serveur est invalide.");
  return url.href.replace(/\/+$/, "");
}
