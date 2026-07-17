import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";

function readLiteLLMBaseUrl(): string {
  const envUrl = process.env.LITELLM_BASE_URL?.trim();
  if (envUrl) return envUrl;

  try {
    return execFileSync(
      "op",
      ["read", "--account", "graderainc.1password.com", "op://Employee/litellm-ab-gradera/url"],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      },
    ).trim();
  } catch {
    return "http://localhost:4000";
  }
}

// Prefer the environment variable; otherwise read the key from 1Password at startup.
function readLiteLLMApiKey(): string {
  const envKey = process.env.LITELLM_API_KEY?.trim();
  if (envKey) return envKey;

  try {
    return execFileSync(
      "op",
      ["read", "--account", "graderainc.1password.com", "op://Employee/litellm-ab-gradera/key"],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      },
    ).trim();
  } catch {
    return "";
  }
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
        ...(isReasoning && {
          compat: {
            thinkingFormat: "deepseek" as const,
            maxTokensField: "max_tokens" as const,
          },
        }),
      };
    }),
  });
}
