import {
  validate,
  preparationSchema,
  preparedNamesSchema,
} from "./validation.mjs";
import { parseMemberNames } from "./domain.mjs";
const key = "statoo-registration-draft";
export class RegistrationDraft {
  constructor(storage) {
    this.storage = storage;
  }
  load() {
    try {
      const raw = this.storage.getItem(key);
      if (!raw) return null;
      const value = JSON.parse(raw);
      if (
        value.version !== 1 ||
        typeof value.name !== "string" ||
        typeof value.roster !== "string" ||
        !value.operation_id ||
        !Array.isArray(value.members) ||
        value.members.some((m) => !m.id || typeof m.name !== "string") ||
        (value.pending && !value.api)
      )
        throw Error();
      return value;
    } catch {
      throw Error(
        "La préparation locale est illisible ou inaccessible. Ne l’effacez qu’après avoir vérifié vos informations.",
      );
    }
  }
  write(value) {
    try {
      this.storage.setItem(key, JSON.stringify(value));
    } catch {
      throw Error(
        "Impossible d’enregistrer sur cet appareil. Vérifiez le stockage disponible.",
      );
    }
    return value;
  }
  save({ name, roster, short_name = "" }) {
    const old = this.load();
    if (old?.pending)
      throw Error(
        "Publication à vérifier : reprenez la tentative avec les mêmes accès avant de modifier le groupe.",
      );
    ({ name, roster, short_name } = validate(preparationSchema, {
      name,
      roster,
      short_name,
    }));
    const names = validate(preparedNamesSchema, parseMemberNames(roster));
    if (!name.trim()) throw Error("Renseignez le nom du groupe.");
    if (!names.length) throw Error("Ajoutez au moins un membre.");
    if (name.trim().length > 100 || names.length > 1000)
      throw Error("Nom trop long ou plus de 1 000 membres.");
    if (
      old?.name === name.trim() &&
      old.roster === roster &&
      (old.short_name || "") === short_name
    )
      return old;
    return this.write({
      version: 1,
      name: name.trim(),
      short_name,
      roster,
      members: names.map((name) => ({
        id: crypto.randomUUID(),
        name,
        is_active: 1,
      })),
      operation_id: crypto.randomUUID(),
      pending: false,
    });
  }
  prepare(api) {
    const value = this.load();
    if (!value) throw Error("Enregistrez d’abord la préparation.");
    if (value.pending && value.api !== api)
      throw Error(
        "Cette publication doit être reprise sur son serveur d’origine.",
      );
    return this.write({ ...value, api, pending: true });
  }
  clear() {
    try {
      this.storage.removeItem(key);
    } catch {
      throw Error("Impossible d’effacer la préparation locale.");
    }
  }
}
