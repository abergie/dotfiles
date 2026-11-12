import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";

function normalizeBaseUrl(raw: string): string {
  let url = raw.trim();
  if (!url) return "";
  if (!/^https?:\/\//i.test(url)) url = `https://${url}`;
  return url.replace(/\/+$/, "").replace(/\/v1$/i, "");
}

function listOpAccounts(): string[] {
  const explicit = process.env.OP_ACCOUNT?.trim();
  if (explicit) return [explicit];

  try {
    const raw = execFileSync("op", ["account", "list", "--format", "json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
    const accounts = JSON.parse(raw) as Array<{ account_uuid?: string; url?: string }>;
    const ids = accounts.map((a) => a.account_uuid || a.url || "").filter(Boolean);
    return ids.length > 0 ? ["" , ...ids] : [""];
  } catch {
    return [""];
  }
}

function readOpEnvironmentField(envName: string, field: string, accounts: string[]): string {
  for (const account of accounts) {
    for (const reveal of [false, true]) {
      try {
        const args = ["environment", "secret", "list", envName, "--format=json"];
        if (reveal) args.push("--reveal");
        if (account) args.push("--account", account);
        const raw = execFileSync("op", args, {
          encoding: "utf8",
          stdio: ["ignore", "pipe", "ignore"],
        });
        const parsed = JSON.parse(raw) as
          | Array<{ name?: string; value?: string; is_concealed?: boolean; concealed?: boolean; masked?: boolean }>
          | { secrets?: Array<{ name?: string; value?: string; is_concealed?: boolean; concealed?: boolean; masked?: boolean }> };
        const entries = Array.isArray(parsed) ? parsed : (parsed.secrets ?? []);
        const match = entries.find((e) => e.name === field);
        if (!match) break; // Environment found on this account, field absent
        const concealed = Boolean(match.is_concealed || match.concealed || match.masked);
        const val = (match.value ?? "").trim();
        if (val && !val.startsWith("REPLACE_ME") && val !== "<concealed by 1Password>" && (!concealed || reveal)) {
          return val;
        }
        if (!concealed) break;
      } catch {
        break; // Environment not found on this account; try next account
      }
    }
  }
  return "";
}

function readOpField(field: string): string {
  const accounts = listOpAccounts();
  const envRaw = process.env.PI_OP_ENVS?.trim() || process.env.PI_OP_ENV?.trim() || process.env.OP_ENV?.trim() || "openshell-pi-dev";
  const envNames = envRaw
    .split(/[\s,]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  // Later environments override earlier ones when multiple are configured
  for (let i = envNames.length - 1; i >= 0; i--) {
    const val = readOpEnvironmentField(envNames[i], field, accounts);
    if (val) return val;
  }

  // Fallback to legacy vault item when no Environment held the field
  const vault = process.env.OP_VAULT?.trim() || "Employee";
  const item = process.env.OP_ITEM?.trim() || "nono-pi-dev";
  const ref = `op://${vault}/${item}/${field}`;

  for (const account of accounts) {
    try {
      const args = account ? ["read", "--account", account, ref] : ["read", ref];
      const value = execFileSync("op", args, {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      }).trim();
      if (value && !value.startsWith("REPLACE_ME")) {
        return value;
      }
    } catch {
      // Try next signed-in 1Password account
    }
  }
  return "";
}

function readLiteLLMBaseUrl(): string {
  const envUrl = normalizeBaseUrl(process.env.LITELLM_BASE_URL ?? "");
  if (envUrl) return envUrl;

  return normalizeBaseUrl(readOpField("LITELLM_BASE_URL")) || "http://localhost:4000";
}

// Prefer the environment variable; otherwise read the key from 1Password at startup.
function readLiteLLMApiKey(): string {
  const envKey = process.env.LITELLM_API_KEY?.trim();
  if (envKey) return envKey;

  return readOpField("LITELLM_API_KEY");
}

export default async function (pi: ExtensionAPI) {
  const LITELLM_BASE_URL = readLiteLLMBaseUrl();
  const apiKey = readLiteLLMApiKey();
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;

  let models: any[] = [];

  try {
    const res = await fetch(`${LITELLM_BASE_URL}/v1/models`, { headers });
    if (res.ok) {
      const payload = (await res.json()) as { data: any[] };
      models = payload.data ?? [];
    } else {
      const body = await res.text().catch(() => "");
      console.warn(
        `[litellm] GET ${LITELLM_BASE_URL}/v1/models failed: ${res.status} ${res.statusText}${body ? ` - ${body}` : ""}`,
      );
    }
  } catch (err) {
    console.warn(`[litellm] GET ${LITELLM_BASE_URL}/v1/models failed: ${String(err)}`);
  }

  pi.registerProvider("litellm", {
    name: "LiteLLM",
    baseUrl: `${LITELLM_BASE_URL}/v1`,
    ...(apiKey ? { apiKey } : {}),
    api: "openai-completions",
    models: models.map((m) => {
      const isReasoning = /r1|deepseek-reasoner|qwq/i.test(m.id);
      return {
        id: m.id,
        name: m.id,
        reasoning: isReasoning,
        input: ["text"] as ("text" | "image")[],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: m.max_input_tokens ?? 128000,
        maxTokens: m.max_output_tokens ?? 4096,
        compat: {
          // Sends x-session-id (sessionAffinityFormat: "openrouter") with pi's
          // real per-session UUID on every request so LiteLLM's session_id_hook
          // callback groups Langfuse traces per conversation rather than falling
          // back to a long-lived derived principal+client hash.
          sendSessionAffinityHeaders: true,
          sessionAffinityFormat: "openrouter" as const,
          ...(isReasoning && {
            thinkingFormat: "deepseek" as const,
            maxTokensField: "max_tokens" as const,
          }),
        },
      };
    }),
  });
}
