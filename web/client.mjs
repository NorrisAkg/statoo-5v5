import {
  validate,
  credentialsSchema,
  registrationSchema,
  validateMutation,
} from "./validation.mjs";
import { capabilities, operation } from "./domain.mjs";
const connectionKey = "statoo-connection";
export class PortalClient {
  constructor({
    storage,
    session,
    fetch = globalThis.fetch.bind(globalThis),
  } = {}) {
    const unavailable = {
      getItem() {
        throw Error("Le stockage local est indisponible.");
      },
      setItem() {
        throw Error("Le stockage local est indisponible.");
      },
      removeItem() {
        throw Error("Le stockage local est indisponible.");
      },
    };
    const browserStorage = (name, supplied) => {
      try {
        const value = supplied ?? globalThis[name];
        if (!value) throw Error();
        return value;
      } catch {
        this.storageWarning =
          "Le stockage local est indisponible. La conservation des saisies et la connexion nécessitent un stockage autorisé.";
        return unavailable;
      }
    };
    this.storage = browserStorage("localStorage", storage);
    this.session = browserStorage("sessionStorage", session);
    this.fetch = fetch;
    this.connection = null;
    this.snapshot = null;
    this.busy = false;
    this.refreshSequence = 0;
    this.refreshWarning = null;
  }
  prefix() {
    const c = this.connection;
    return c
      ? "statoo:" +
          encodeURIComponent(c.api) +
          "|" +
          encodeURIComponent(c.group) +
          "|" +
          encodeURIComponent(c.account?.id) +
          ":"
      : null;
  }
  write(key, value) {
    try {
      this.storage.setItem(key, JSON.stringify(value));
    } catch {
      throw Error(
        "Le stockage local est indisponible. Libérez de la place avant de poursuivre.",
      );
    }
  }
  read(key) {
    try {
      return JSON.parse(this.storage.getItem(key) || "null");
    } catch {
      return null;
    }
  }
  saveDraft(domain, id, payload) {
    if (!this.connection) return;
    this.write(this.prefix() + "draft:" + domain + ":" + id, payload);
  }
  readDraft(domain, id) {
    return this.read(this.prefix() + "draft:" + domain + ":" + id);
  }
  removeDraft(domain, id) {
    this.storage.removeItem(this.prefix() + "draft:" + domain + ":" + id);
  }
  pending() {
    try {
      const data = JSON.parse(
        this.storage.getItem(this.prefix() + "pending") || "[]",
      );
      if (
        !Array.isArray(data) ||
        data.some(
          (p) => !p?.operation_id || !["sport", "finance"].includes(p.domain),
        )
      )
        throw Error();
      return data;
    } catch {
      throw Error(
        "La file des envois est illisible. N’envoyez pas de nouvelle version avant d’avoir vérifié les données publiées. Déconnectez-vous pour effacer les données locales corrompues.",
      );
    }
  }
  restore() {
    try {
      const c = JSON.parse(this.session.getItem(connectionKey) || "null");
      if (
        !c?.token ||
        !c.account?.id ||
        !Number.isFinite(Date.parse(c.expires_at)) ||
        Date.parse(c.expires_at) <= Date.now()
      )
        return this.clear(c);
      this.connection = c;
      const cache = this.read(this.prefix() + "snapshot");
      this.snapshot = cache?.data || null;
      this.updatedAt = cache?.at || null;
    } catch {
      this.storageWarning =
        "Le stockage local est indisponible. Autorisez-le pour retrouver votre connexion et vos brouillons.";
      this.clear();
    }
  }
  clear(connection = this.connection) {
    if (connection) {
      const previous = this.connection;
      this.connection = connection;
      const prefix = this.prefix();
      this.connection = previous;
      try {
        const keys = Array.from({ length: this.storage.length }, (_, i) =>
          this.storage.key(i),
        );
        for (const key of keys)
          if (key?.startsWith(prefix)) this.storage.removeItem(key);
      } catch {}
    }
    try {
      this.session.removeItem(connectionKey);
    } catch {}
    this.connection = null;
    this.snapshot = null;
    this.updatedAt = null;
  }
  async request(path, body, method = body === undefined ? "GET" : "POST") {
    const connection = this.connection;
    if (!connection) throw Error("Connexion requise.");
    const controller = new AbortController(),
      timer = setTimeout(() => controller.abort(), 30000);
    try {
      const r = await this.fetch(connection.api + path, {
        method,
        cache: "no-store",
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          ...(connection.token
            ? { Authorization: "Bearer " + connection.token }
            : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      let data;
      try {
        const text = await r.text();
        data = text ? JSON.parse(text) : {};
      } catch {
        if (r.ok)
          throw Error(
            "Réponse du serveur invalide. Réessayez l’actualisation.",
          );
        data = {};
      }
      if (!r.ok) {
        const message =
          typeof data?.detail === "string"
            ? data.detail
            : r.status === 401
              ? "Connexion expirée. Reconnectez-vous."
              : r.status >= 500
                ? "Le serveur est indisponible. Réessayez plus tard."
                : r.status === 403
                  ? "Le serveur refuse cette action : vérifiez vos droits."
                  : "Le serveur a refusé la demande. Vérifiez les champs saisis.";
        if (r.status === 401 && this.connection === connection) this.clear();
        const error = Error(message);
        error.status = r.status;
        throw error;
      }
      return data;
    } catch (error) {
      if (error.name === "AbortError")
        throw Error(
          "Délai dépassé. Votre envoi est conservé pour un nouvel essai.",
        );
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
  async connect(api, group, username, password, registration) {
    const url = new URL(api);
    if (
      url.protocol !== "https:" &&
      !(
        url.protocol === "http:" &&
        ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)
      )
    )
      throw Error("Utilisez une adresse HTTPS.");
    if (url.username || url.password || url.search || url.hash)
      throw Error("Adresse du serveur invalide.");
    const credentials = registration
      ? validate(registrationSchema, registration)
      : validate(credentialsSchema, { group_id: group, username, password });
    if (this.connection) this.clear();
    this.connection = { api: url.href.replace(/\/$/, ""), group };
    try {
      const identity = await this.request(
        registration ? "/groups" : "/auth/login",
        credentials,
      );
      this.connection = {
        ...this.connection,
        group: identity.group_id,
        ...identity,
      };
      this.session.setItem(connectionKey, JSON.stringify(this.connection));
      await this.refresh();
    } catch (error) {
      this.clear();
      throw error;
    }
  }
  async refresh() {
    if (!this.connection) return;
    const connection = this.connection;
    const sequence = ++this.refreshSequence;
    const data = await this.request(
      "/groups/" + encodeURIComponent(this.connection.group),
    );
    if (this.connection !== connection || sequence !== this.refreshSequence)
      return;
    this.snapshot = data;
    this.connection.account = data.account;
    this.updatedAt = new Date().toISOString();
    this.session.setItem(connectionKey, JSON.stringify(this.connection));
    this.write(this.prefix() + "snapshot", { data, at: this.updatedAt });
    return data;
  }
  async logout() {
    try {
      if (this.connection) await this.request("/auth/logout", {});
    } catch {
    } finally {
      this.clear();
    }
  }
  async mutate(path, body, method = "POST") {
    if (!this.connection) throw Error("Connexion requise.");
    body = validateMutation(path, body);
    const connection = this.connection;
    this.refreshWarning = null;
    let result;
    try {
      result = await this.request(
        "/groups/" + encodeURIComponent(this.connection.group) + path,
        body,
        method,
      );
    } catch (error) {
      if (error.status === 403 && this.connection === connection) {
        try {
          await this.refresh();
        } catch {}
      }
      throw error;
    }
    if (this.connection !== connection)
      throw Error("Le compte a changé pendant l’envoi.");
    try {
      await this.refresh();
    } catch (error) {
      if (error.status === 401) throw error;
      this.refreshWarning =
        "Modification enregistrée ; actualisation indisponible. Utilisez Actualiser pour relire les données.";
    }
    return result;
  }
  assertCurrentDocument(domain, reference, document) {
    const current = this.snapshot?.documents?.[domain + ":" + reference];
    if (
      !!current !== !!document ||
      (current &&
        (current.revision !== document.revision ||
          current.generation !== document.generation ||
          current.owner !== document.owner))
    )
      throw Error(
        "Ce brouillon repose sur une version périmée. Relisez la version publiée avant de poursuivre.",
      );
  }
  async send(domain, reference, payload, document, reason = "") {
    if (!capabilities(this.snapshot?.account)[domain])
      throw Error("Vous ne disposez pas du rôle requis.");
    if (this.busy) throw Error("Un envoi est déjà en cours.");
    this.assertCurrentDocument(domain, reference, document);
    if (
      document &&
      (document.owner !== this.connection.account.id ||
        document.candidates?.length)
    )
      throw Error("Un transfert ou un arbitrage est nécessaire.");
    const op = operation(domain, reference, payload, document, reason),
      pending = this.pending();
    if (
      pending.some((p) => p.domain === domain && p.occurrence_id === reference)
    )
      throw Error(
        "Un envoi existe déjà pour cette échéance. Réessayez-le avant une autre modification.",
      );
    this.write(this.prefix() + "pending", [...pending, op]);
    return this.dispatch(op);
  }
  async dispatch(op) {
    if (this.busy) throw Error("Un envoi est déjà en cours.");
    this.busy = true;
    const connection = this.connection;
    this.refreshWarning = null;
    try {
      const result = await this.request(
        "/groups/" + encodeURIComponent(this.connection.group) + "/sync",
        op,
      );
      if (this.connection !== connection)
        throw Error("Le compte a changé pendant l’envoi.");
      this.write(
        this.prefix() + "pending",
        this.pending().filter((p) => p.operation_id !== op.operation_id),
      );
      try {
        await this.refresh();
      } catch (error) {
        if (error.status === 401) throw error;
        this.refreshWarning = "Données envoyées ; actualisation à réessayer.";
      }
      return result;
    } catch (error) {
      if (
        [400, 403, 409, 422].includes(error.status) &&
        this.connection === connection
      )
        this.write(
          this.prefix() + "pending",
          this.pending().filter((p) => p.operation_id !== op.operation_id),
        );
      if (error.status === 403 && this.connection === connection) {
        try {
          await this.refresh();
        } catch {}
      }
      throw error;
    } finally {
      this.busy = false;
    }
  }
  async retryPending() {
    for (const op of this.pending()) {
      if (!capabilities(this.snapshot?.account)[op.domain])
        throw Error("Votre rôle ne permet plus cet envoi.");
      await this.dispatch(op);
    }
  }
}
