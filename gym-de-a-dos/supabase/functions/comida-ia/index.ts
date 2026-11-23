// Gym de a Dos: calcula los macros de una comida a partir de una foto o de un texto, con Claude.
// Se instala en Supabase → Edge Functions → Deploy a new function → nombre «comida-ia» (ver Ajustes en la app).
// Necesita el secreto ANTHROPIC_API_KEY (Edge Functions → Secrets). Solo responde a usuarios con sesión iniciada:
// Supabase verifica el token de la app antes de llamar a esta función.
import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SISTEMA = `Sos nutricionista en Argentina. Te pasan la foto de una comida o la descripción de lo que alguien comió, y estimás los macros.
- Separá cada alimento o bebida por su cuenta (por ejemplo: pechuga, ensalada, pan, gaseosa).
- Usá porciones y productos habituales en Argentina. Si el texto da un peso, usalo; si dice que el peso es en crudo, calculá con valores en crudo.
- En la foto, estimá el tamaño por el plato, los cubiertos y la mano. Contá el aceite o los aderezos que se vean.
- "porcion" describe en pocas palabras la cantidad que estimaste (ej.: "≈ 200 g", "2 unidades", "1 vaso").
- p = proteína (g), k = calorías (kcal), c = carbohidratos (g), g = grasas (g), del total de esa porción.
- "nota": una frase corta con lo que no se puede saber (ej.: si tiene aceite, el tamaño real) o vacía. Si no hay comida, items vacío y explicalo en la nota.
Respondé en español rioplatense.`;

const ESQUEMA = {
  type: "object",
  additionalProperties: false,
  required: ["items", "nota"],
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["n", "porcion", "p", "k", "c", "g"],
        properties: {
          n: { type: "string" }, porcion: { type: "string" },
          p: { type: "number" }, k: { type: "number" }, c: { type: "number" }, g: { type: "number" },
        },
      },
    },
    nota: { type: "string" },
  },
};

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
  if (!Deno.env.get("ANTHROPIC_API_KEY")) return json({ error: "Falta el secreto ANTHROPIC_API_KEY en Supabase (Edge Functions → Secrets)." }, 500);

  let body: { imagen?: string; tipo?: string; texto?: string; comida?: string };
  try { body = await req.json(); } catch { return json({ error: "Pedido inválido" }, 400); }
  const imagen = typeof body.imagen === "string" ? body.imagen : "";
  const texto = typeof body.texto === "string" ? body.texto.slice(0, 2000) : "";
  if (!imagen && !texto.trim()) return json({ error: "Mandá una foto o un texto" }, 400);
  if (imagen.length > 6_000_000) return json({ error: "La foto es muy grande" }, 413);
  const tipo = ["image/jpeg", "image/png", "image/webp"].includes(body.tipo ?? "") ? body.tipo as "image/jpeg" | "image/png" | "image/webp" : "image/jpeg";

  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  if (imagen) content.push({ type: "image", source: { type: "base64", media_type: tipo, data: imagen } });
  content.push({
    type: "text",
    text: (imagen ? "Estimá los macros de lo que se ve en la foto." : "Estimá los macros de esto que comí:") +
      (texto ? `\n\n${texto}` : "") + (body.comida ? `\n\n(Comida del día: ${body.comida})` : ""),
  });

  try {
    const res = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 8000,
      system: SISTEMA,
      messages: [{ role: "user", content }],
      output_config: { effort: "low", format: { type: "json_schema", schema: ESQUEMA } },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
    } as Anthropic.Beta.MessageCreateParamsNonStreaming);
    if (res.stop_reason === "refusal") return json({ items: [], nota: "La IA no pudo analizar esto. Probá con otra foto o escribilo." });
    const txt = res.content.find((b) => b.type === "text");
    if (!txt || txt.type !== "text") return json({ error: "La IA no devolvió datos" }, 502);
    return json(JSON.parse(txt.text));
  } catch (e) {
    if (e instanceof Anthropic.AuthenticationError) return json({ error: "La clave de la API de Claude no es válida. Revisá ANTHROPIC_API_KEY en Supabase." }, 500);
    if (e instanceof Anthropic.RateLimitError) return json({ error: "Demasiados pedidos seguidos. Probá en un minuto." }, 429);
    if (e instanceof Anthropic.APIError) return json({ error: `La IA respondió con un error (${e.status ?? "sin código"}). Probá de nuevo.` }, 502);
    return json({ error: "No se pudo procesar la comida." }, 500);
  }
});
