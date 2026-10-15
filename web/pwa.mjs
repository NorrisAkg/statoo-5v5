export function registerPwa(installButton) {
  let prompt;
  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    prompt = event;
    installButton.hidden = false;
  });
  installButton.addEventListener("click", async () => {
    if (!prompt) return;
    await prompt.prompt();
    await prompt.userChoice;
    prompt = null;
    installButton.hidden = true;
  });
  window.addEventListener("appinstalled", () => {
    installButton.hidden = true;
    prompt = null;
  });
  if (!("serviceWorker" in navigator)) return;
  navigator.serviceWorker
    .register(new URL("./sw.js", import.meta.url), {
      scope: "./",
      updateViaCache: "none",
    })
    .then((registration) => {
      let update;
      function ready() {
        if (!registration.waiting || update) return;
        update = document.createElement("button");
        update.type = "button";
        update.className = "secondary";
        update.textContent = "Mettre à jour Statoo";
        update.addEventListener("click", () => {
          if (
            confirm(
              "Installer la mise à jour ? Vos brouillons enregistrés seront conservés.",
            )
          )
            registration.waiting?.postMessage({ type: "SKIP_WAITING" });
        });
        installButton.parentElement.append(update);
      }
      ready();
      registration.addEventListener("updatefound", () =>
        registration.installing?.addEventListener("statechange", () => {
          if (registration.waiting && navigator.serviceWorker.controller)
            ready();
        }),
      );
      let refreshing = false,
        controlled = !!navigator.serviceWorker.controller;
      navigator.serviceWorker.addEventListener("controllerchange", () => {
        if (controlled && !refreshing) {
          refreshing = true;
          location.reload();
        }
        controlled = true;
      });
    })
    .catch(() => {
      /* The web app remains usable when installation is unavailable. */
    });
}
