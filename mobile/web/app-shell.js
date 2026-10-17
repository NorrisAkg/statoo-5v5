// Browser-only controls. No business state or database is read, changed or cleared.
(() => {
  if (document.getElementById("statoo-pwa")) return;
  const create = (tag, text, id) => {
    const element = document.createElement(tag);
    if (text) element.textContent = text;
    if (id) element.id = id;
    return element;
  };
  const menu = create("details", null, "statoo-pwa");
  const summary = create("summary", "Application");
  const panel = create("div", null, "statoo-pwa-panel");
  const status = create("p", "", "statoo-pwa-status");
  status.setAttribute("role", "status");
  const install = create("button", "Installer Statoo", "statoo-pwa-install");
  const update = create("button", "Mettre à jour Statoo", "statoo-pwa-update");
  const check = create("button", "Vérifier les mises à jour");
  for (const button of [install, update, check]) button.type = "button";
  update.hidden = true;
  panel.append(install, update, check, status);
  menu.append(summary, panel);
  document.body.append(menu);
  let prompt,
    registration,
    checking = false,
    installing = false;
  let requested = false,
    reloading = false,
    activatedElsewhere = false;
  let lastCheck = 0;
  let controlled = !!navigator.serviceWorker?.controller;
  const standalone = () =>
    matchMedia("(display-mode: standalone)").matches ||
    navigator.standalone === true;
  const syncInstall = () => {
    install.hidden = standalone();
  };
  syncInstall();
  matchMedia("(display-mode: standalone)").addEventListener(
    "change",
    syncInstall,
  );

  function dialog(title, text, action) {
    if (document.getElementById("statoo-pwa-dialog")) return;
    const d = create("dialog", null, "statoo-pwa-dialog");
    const heading = create("h2", title, "statoo-pwa-dialog-title");
    d.setAttribute("aria-labelledby", heading.id);
    const body = create("p", text);
    const actions = create("div");
    const cancel = create("button", action ? "Plus tard" : "Fermer");
    cancel.type = "button";
    cancel.onclick = () => d.close();
    actions.append(cancel);
    if (action) {
      const confirm = create("button", "Confirmer la mise à jour");
      confirm.type = "button";
      confirm.onclick = () => {
        d.close();
        action();
      };
      actions.append(confirm);
    }
    d.append(heading, body, actions);
    d.addEventListener("close", () => {
      d.remove();
      summary.focus();
    });
    document.body.append(d);
    d.showModal();
  }

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    prompt = event;
    syncInstall();
  });
  window.addEventListener("appinstalled", () => {
    prompt = null;
    install.hidden = true;
    status.textContent = "Statoo est installé sur cet appareil.";
  });
  install.onclick = async () => {
    if (installing) return;
    if (!prompt) {
      const ios =
        /iPad|iPhone|iPod/.test(navigator.userAgent) ||
        (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
      dialog(
        "Installer Statoo",
        ios
          ? "Dans Safari, ouvrez le menu Partager, puis « Sur l’écran d’accueil ». Si vous êtes dans un autre navigateur, ouvrez cette adresse dans Safari."
          : "Ouvrez le menu du navigateur et cherchez « Installer Statoo » ou « Installer cette page comme application ». Si cette option est absente, le navigateur ne propose pas encore l’installation pour cette page. Vous pouvez continuer à utiliser Statoo ici.",
      );
      return;
    }
    const current = prompt;
    prompt = null;
    installing = true;
    install.disabled = true;
    try {
      await current.prompt();
      const choice = await current.userChoice;
      if (choice.outcome === "accepted") {
        install.hidden = true;
        status.textContent = "Installation demandée au navigateur.";
      } else
        status.textContent =
          "Installation reportée. Vous pouvez la relancer depuis le menu du navigateur.";
    } catch {
      status.textContent =
        "Installation indisponible. Réessayez depuis le menu du navigateur.";
    } finally {
      installing = false;
      install.disabled = false;
    }
  };

  const ready = () => {
    const available = !!registration?.waiting || activatedElsewhere;
    update.hidden = !available;
    summary.textContent = available ? "Mise à jour" : "Application";
    summary.setAttribute(
      "aria-label",
      available
        ? "Application : mise à jour disponible"
        : "Options de l’application Statoo",
    );
    if (available)
      status.textContent =
        "Une nouvelle version est prête. Terminez votre saisie avant de l’activer.";
  };
  update.onclick = () =>
    dialog(
      "Mettre à jour Statoo ?",
      "Les données enregistrées sur cet appareil seront conservées. Les saisies non validées de l’écran courant peuvent être perdues : terminez-les avant de confirmer. La page sera ensuite rechargée.",
      () => {
        if (activatedElsewhere) {
          if (!reloading) {
            reloading = true;
            location.reload();
          }
        } else if (registration?.waiting) {
          requested = true;
          update.disabled = true;
          status.textContent = "Activation de la nouvelle version…";
          registration.waiting.postMessage({ type: "SKIP_WAITING" });
        } else {
          requested = false;
          ready();
          status.textContent =
            "La mise à jour n’est plus en attente. Vérifiez à nouveau.";
        }
      },
    );

  async function verify(manual = false) {
    if (checking || (!manual && Date.now() - lastCheck < 60000)) return;
    checking = true;
    check.disabled = true;
    lastCheck = Date.now();
    try {
      if (!("serviceWorker" in navigator)) {
        status.textContent =
          "La mise à jour automatique est indisponible dans ce navigateur.";
        return;
      }
      if (!registration) {
        registration = await navigator.serviceWorker.register(
          new URL("sw.js", document.baseURI),
          {
            scope: new URL("./", document.baseURI).href,
            updateViaCache: "none",
          },
        );
        const watchInstalling = () => {
          const worker = registration.installing;
          worker?.addEventListener("statechange", () => {
            ready();
            if (worker.state === "redundant" && !registration.waiting)
              status.textContent =
                "Téléchargement indisponible. La version actuelle reste disponible. Vérifiez votre connexion et réessayez.";
          });
        };
        registration.addEventListener("updatefound", watchInstalling);
        watchInstalling();
      }
      await registration.update();
      ready();
      if (!registration.waiting && !activatedElsewhere)
        status.textContent = registration.installing
          ? "Téléchargement de la nouvelle version…"
          : "Aucune nouvelle version disponible pour le moment.";
    } catch {
      status.textContent =
        "Vérification indisponible. Vérifiez votre connexion et réessayez.";
    } finally {
      checking = false;
      check.disabled = false;
    }
  }
  navigator.serviceWorker?.addEventListener("controllerchange", () => {
    if (!controlled) {
      controlled = true;
      return;
    }
    if (requested && !reloading) {
      reloading = true;
      location.reload();
    } else if (!requested) {
      activatedElsewhere = true;
      ready();
    }
  });
  check.onclick = () => verify(true);
  window.addEventListener("online", () => verify());
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) verify();
  });
  document.addEventListener("pointerdown", (event) => {
    if (
      menu.open &&
      !document.getElementById("statoo-pwa-dialog") &&
      !menu.contains(event.target)
    )
      menu.open = false;
  });
  menu.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      menu.open = false;
      summary.focus();
    }
  });
  verify();
})();
// Keep pre-migration preparations reachable on the same origin.
try {
  if (
    localStorage.getItem("statoo-registration-draft") ||
    sessionStorage.getItem("statoo-connection")
  ) {
    const link = document.createElement("a");
    link.href = "portal/";
    link.textContent = "Retrouver mes préparations dans l’ancien portail";
    link.setAttribute("aria-label", link.textContent);
    link.style.cssText =
      "position:fixed;bottom:8px;right:8px;z-index:20;max-width:90%;padding:8px 12px;background:#141a22;color:#f8fafc;border:1px solid #22c55e;border-radius:12px;font:12px system-ui;";
    document.body.append(link);
  }
} catch {}
