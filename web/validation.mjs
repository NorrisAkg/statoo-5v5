import * as z from "./vendor/zod.mjs";

const text = (label, max = 100) =>
  z
    .string({ error: label + " requis." })
    .trim()
    .min(1, { error: label + " requis." })
    .max(max, { error: label + " : " + max + " caractères maximum." });
const password = z
  .string({ error: "Mot de passe requis." })
  .min(8, { error: "Mot de passe : au moins 8 caractères." })
  .max(200, { error: "Mot de passe : 200 caractères maximum." });
const id = text("Identifiant");
const amount = z
  .number({ error: "Montant entier requis." })
  .int({ error: "Montant entier requis." })
  .min(0, { error: "Montant positif ou nul requis." })
  .max(1e12, { error: "Montant trop élevé." });
const revision = z
  .number({ error: "Révision entière requise." })
  .int({ error: "Révision entière requise." })
  .min(0, { error: "Révision positive ou nulle requise." });
const reason = text("Motif", 300);
export const correctionReasonSchema = reason;
const roles = [
  "ADMIN",
  "PDT",
  "VP",
  "TR",
  "TGA",
  "SG",
  "SGA",
  "CENSOR",
  "MEMBER",
];
const role = z.enumeration(roles, { error: "Responsabilité inconnue." });
const roleList = z.array(role, { error: "Sélectionnez les responsabilités." });

export class ClientValidationError extends Error {
  constructor(issues) {
    const safe = issues.map((issue) => ({
      ...issue,
      message: /^(Invalid|Too |Unrecognized|Expected)/.test(issue.message)
        ? "Valeur invalide. Vérifiez ce champ."
        : issue.message,
    }));
    super([...new Set(safe.map((issue) => issue.message))].join(" "));
    this.name = "ClientValidationError";
    this.issues = safe;
  }
}
export function validate(schema, value) {
  const result = schema.safeParse(value);
  if (!result.success) throw new ClientValidationError(result.error.issues);
  return result.data;
}
export function parseInteger(value, label = "Nombre", signed = false) {
  const message =
    label + " : entier " + (signed ? "" : "positif ou nul ") + "requis.";
  let schema = z
    .number({ error: message })
    .int({ error: message })
    .min(signed ? -1e12 : 0, { error: message })
    .max(1e12, { error: message });
  schema = z.preprocess(
    (v) => (typeof v === "string" && v.trim() !== "" ? Number(v) : v),
    schema,
  );
  return validate(schema, value);
}
function isCalendarDate(value) {
  if (
    !/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})?)?$/.test(
      value,
    )
  )
    return false;
  const day = value.slice(0, 10),
    parsed = new Date(day + "T00:00:00Z");
  return (
    Number.isFinite(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === day &&
    Number.isFinite(Date.parse(value))
  );
}
export const dateSchema = z
  .string({ error: "Date invalide." })
  .refine(isCalendarDate, { error: "Date invalide." });
export function parseDate(value) {
  return validate(dateSchema, value);
}
export const memberSchema = z
  .object(
    {
      id,
      name: text("Nom du membre"),
      nickname: z.string().optional(),
      is_active: z.union([z.literal(0), z.literal(1), z.boolean()]).optional(),
    },
    { error: "Membre invalide." },
  )
  .passthrough();
const memberList = z
  .array(memberSchema, { error: "Liste des membres requise." })
  .max(1000, { error: "Maximum 1 000 membres." })
  .refine((v) => new Set(v.map((m) => m.id)).size === v.length, {
    error: "Identifiants de membres en double.",
  });
export const credentialsSchema = z.object({
  group_id: text("Identifiant du groupe"),
  username: text("Identifiant de connexion"),
  password,
});
export const registrationSchema = z
  .object({
    name: text("Nom du groupe"),
    username: text("Identifiant Admin"),
    password,
    shared_username: text("Identifiant collectif"),
    shared_password: password,
    members: memberList.min(1, { error: "Ajoutez au moins un membre." }),
    operation_id: id.optional(),
    group_id: z.string().max(100).optional(),
  })
  .passthrough();
export const preparationSchema = z.object({
  name: text("Nom du groupe"),
  roster: z.string({ error: "Liste des membres requise." }),
});
export const preparedNamesSchema = z
  .array(text("Nom du membre"))
  .min(1, { error: "Ajoutez au moins un membre." })
  .max(1000, { error: "Maximum 1 000 membres." });

const participant = z
  .object(
    {
      player_id: id,
      session_id: id,
      team: z.enumeration(["A", "B", "C"], {
        error: "Équipe du participant invalide.",
      }),
    },
    { error: "Participant invalide." },
  )
  .passthrough();
export const sportInputSchema = z
  .object(
    {
      session: z
        .object(
          {
            id,
            played_at: dateSchema,
            session_type: z
              .enumeration(["CLASSIC_2", "TOURNAMENT_3"], {
                error: "Format de séance invalide.",
              })
              .optional(),
          },
          { error: "Séance invalide." },
        )
        .passthrough(),
      participations: z
        .array(participant, { error: "Liste des participants requise." })
        .max(1000, { error: "Trop de participants." }),
    },
    { error: "Séance et participants requis." },
  )
  .passthrough();
const movement = z
  .object(
    { id, label: text("Libellé du mouvement", 300), amount: z.unknown() },
    { error: "Mouvement financier invalide." },
  )
  .passthrough();
export const financeInputSchema = z
  .object(
    {
      played_at: dateSchema,
      rate: z.unknown(),
      lines: z.array(z.object({ member_id: id }).passthrough(), {
        error: "Lignes de cotisation requises.",
      }),
      expenses: z.array(movement, { error: "Liste des dépenses requise." }),
      donations: z.array(movement, { error: "Liste des dons requise." }),
    },
    { error: "Point financier invalide." },
  )
  .passthrough();
const balance = z.object({
  contribution_balance: z
    .number({ error: "Avance ou dette entière requise." })
    .int()
    .min(-1e12)
    .max(1e12),
  penalty_debt: amount,
});
export const openingSchema = z.object(
  {
    cash: amount,
    start_date: dateSchema.nullable().optional(),
    members: z.record(z.string(), balance),
  },
  { error: "Soldes initiaux invalides." },
);
export const financialSettingsSchema = z.object({
  contribution: amount,
  late_penalty: amount,
});
export const sportSettingsSchema = z.object({
  min_players_per_session: z
    .number({ error: "Minimum de joueurs : entier de 2 à 30 requis." })
    .int({ error: "Minimum de joueurs : entier de 2 à 30 requis." })
    .min(2, { error: "Minimum de joueurs : au moins 2." })
    .max(30, { error: "Minimum de joueurs : 30 maximum." }),
});
export const accountSchema = z.object({
  username: text("Identifiant personnel"),
  password,
  member_id: id,
  roles: roleList.refine((v) => v.some((r) => r !== "MEMBER"), {
    error: "Sélectionnez au moins une responsabilité.",
  }),
});
export const roleChangeSchema = z.object({
  roles: roleList,
  transfer: z.boolean().optional(),
  reason,
});
export const decisionSchema = z.object({
  revision,
  candidate_id: text("Version retenue"),
  reason,
});
export const transferSchema = z.object({
  revision,
  account_id: text("Nouveau responsable"),
  reason,
});
export const operationSchema = z.object({
  operation_id: id,
  occurrence_id: text("Référence", 150).refine((v) => !v.includes("/"), {
    error: "Référence invalide.",
  }),
  domain: z.enumeration(["sport", "finance"]),
  base_revision: revision,
  generation: revision,
  payload: z.unknown(),
  reason: z
    .string()
    .trim()
    .max(300, { error: "Motif : 300 caractères maximum." }),
});
export function validateMutation(path, body) {
  const schema =
    path === "/members"
      ? memberList
      : path === "/accounts"
        ? accountSchema
        : /^\/accounts\/[^/]+\/roles$/.test(path)
          ? roleChangeSchema
          : path === "/shared-access"
            ? credentialsSchema
            : path === "/financial-settings"
              ? financialSettingsSchema
              : path === "/sport-settings"
                ? sportSettingsSchema
                : path === "/opening"
                  ? openingSchema
                  : path === "/opening/approve"
                    ? z.object({ proposal: openingSchema })
                    : /\/resolve$/.test(path)
                      ? decisionSchema
                      : /\/transfer$/.test(path)
                        ? transferSchema
                        : null;
  return schema ? validate(schema, body) : body;
}
