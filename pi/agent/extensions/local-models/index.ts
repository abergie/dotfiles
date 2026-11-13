import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const PROBE_TIMEOUT_MS = 800;

interface OpenAIModelRecord {
  id: string;
  owned_by?: string;
  context_length?: number;
  max_context_len?: number;
  max_input_tokens?: number;
  max_output_tokens?: number;
  max_tokens?: number;
  n_ctx?: number;
  capabilities?: {
    vision?: boolean;
    reasoning?: boolean;
  };
  architecture?: {
    input_modalities?: string[];
  };
}

interface LocalBackendConfig {
  id: string;
  name: string;
  baseUrl: string;
  apiKey: string;
  authHeader?: boolean;
  defaultContextWindow: number;
  defaultMaxTokens: number;
  skipRecord?: (record: OpenAIModelRecord) => boolean;
}

interface ProbeOutcome {
  id: string;
  name: string;
  baseUrl: string;
  reachable: boolean;
  models: ProviderModelConfig[];
}

function normalizeBaseUrl(raw: string): string {
  let url = raw.trim();
  if (!url) return "";
  if (!/^https?:\/\//i.test(url)) url = `http://${url}`;
  return url.replace(/\/+$/, "").replace(/\/v1$/i, "");
}

function readOmlxSettings(): {
  baseUrl?: string;
  apiKey?: string;
  contextWindow?: number;
  maxTokens?: number;
} {
  try {
    const raw = readFileSync(join(homedir(), ".omlx", "settings.json"), "utf8");
    const parsed = JSON.parse(raw) as {
      server?: { host?: string; port?: number };
      auth?: { api_key?: string };
      sampling?: { max_context_window?: number; max_tokens?: number };
    };
    const rawHost = parsed.server?.host?.trim() || "127.0.0.1";
    const host = rawHost === "0.0.0.0" || rawHost === "::" ? "127.0.0.1" : rawHost;
    const port = parsed.server?.port ?? 8000;
    return {
      baseUrl: `http://${host}:${port}`,
      apiKey: parsed.auth?.api_key?.trim() || undefined,
      contextWindow: parsed.sampling?.max_context_window,
      maxTokens: parsed.sampling?.max_tokens,
    };
  } catch {
    return {};
  }
}

function buildLocalBackends(): LocalBackendConfig[] {
  const omlx = readOmlxSettings();
  const omlxBaseUrl = normalizeBaseUrl(process.env.OMLX_BASE_URL ?? "") || omlx.baseUrl || "http://127.0.0.1:8000";
  const omlxApiKey = process.env.OMLX_API_KEY?.trim() || omlx.apiKey || "omlx";

  const ollamaBaseUrl = normalizeBaseUrl(process.env.OLLAMA_BASE_URL ?? "") || "http://127.0.0.1:11434";
  const ollamaApiKey = process.env.OLLAMA_API_KEY?.trim() || "ollama";

  const mlxBaseUrl = normalizeBaseUrl(process.env.MLX_LM_BASE_URL ?? "") || "http://127.0.0.1:8080";
  const mlxApiKey = process.env.MLX_LM_API_KEY?.trim() || "mlx-lm";

  const lmStudioBaseUrl = normalizeBaseUrl(process.env.LMSTUDIO_BASE_URL ?? "") || "http://127.0.0.1:1234";
  const lmStudioApiKey = process.env.LMSTUDIO_API_KEY?.trim() || "lmstudio";

  const llamaBaseUrl = normalizeBaseUrl(process.env.LLAMA_SERVER_BASE_URL ?? "") || "http://127.0.0.1:8080";
  const llamaApiKey = process.env.LLAMA_SERVER_API_KEY?.trim() || "llama-server";

  const isLlamaRecord = (record: OpenAIModelRecord) =>
    (record.owned_by ?? "").toLowerCase() === "llamacpp";

  return [
    {
      id: "omlx",
      name: "oMLX (local)",
      baseUrl: omlxBaseUrl,
      apiKey: omlxApiKey,
      authHeader: Boolean(process.env.OMLX_API_KEY?.trim() || omlx.apiKey),
      defaultContextWindow: omlx.contextWindow && omlx.contextWindow > 0 ? Math.max(omlx.contextWindow, 128000) : 128000,
      defaultMaxTokens: omlx.maxTokens && omlx.maxTokens > 0 ? omlx.maxTokens : 32768,
    },
    {
      id: "ollama",
      name: "Ollama (local)",
      baseUrl: ollamaBaseUrl,
      apiKey: ollamaApiKey,
      defaultContextWindow: 128000,
      defaultMaxTokens: 16384,
    },
    {
      id: "mlx-lm",
      name: "mlx-lm (local)",
      baseUrl: mlxBaseUrl,
      apiKey: mlxApiKey,
      defaultContextWindow: 128000,
      defaultMaxTokens: 16384,
      skipRecord: isLlamaRecord,
    },
    {
      id: "llama-server",
      name: "llama-server (local)",
      baseUrl: llamaBaseUrl,
      apiKey: llamaApiKey,
      defaultContextWindow: 128000,
      defaultMaxTokens: 16384,
      // Only claim the shared :8080 default port when the server identifies as llama.cpp
      skipRecord: (record) => !process.env.LLAMA_SERVER_BASE_URL && !isLlamaRecord(record),
    },
    {
      id: "lmstudio",
      name: "LM Studio (local)",
      baseUrl: lmStudioBaseUrl,
      apiKey: lmStudioApiKey,
      defaultContextWindow: 128000,
      defaultMaxTokens: 16384,
    },
  ];
}

function isNonChatModel(id: string): boolean {
  return /(?:^|[-_/:])(embed|embedding|rerank|bge-m3|nomic-embed)/i.test(id);
}

function toProviderModel(record: OpenAIModelRecord, backend: LocalBackendConfig): ProviderModelConfig {
  const contextWindow =
    record.context_length ??
    record.max_context_len ??
    record.max_input_tokens ??
    record.n_ctx ??
    backend.defaultContextWindow;
  const rawMaxTokens = record.max_output_tokens ?? record.max_tokens ?? backend.defaultMaxTokens;
  const maxTokens = Math.min(rawMaxTokens, contextWindow);
  const supportsVision =
    record.capabilities?.vision === true ||
    record.architecture?.input_modalities?.includes("image") === true ||
    /[-_]vl\b|vision|qwen3\.?8|gemma-?4|pixtral|llava/i.test(record.id);
  const reasoning =
    record.capabilities?.reasoning === true || /r1\b|deepseek-reasoner|qwq|thinking/i.test(record.id);

  return {
    type: "chat",
    id: record.id,
    name: record.id,
    reasoning,
    input: supportsVision ? ["text", "image"] : ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow,
    maxTokens,
  };
}

function combinedSignal(parentSignal?: AbortSignal): AbortSignal {
  const timeout = AbortSignal.timeout(PROBE_TIMEOUT_MS);
  if (!parentSignal) return timeout;
  return typeof AbortSignal.any === "function" ? AbortSignal.any([parentSignal, timeout]) : parentSignal;
}

async function probeBackend(backend: LocalBackendConfig, signal?: AbortSignal): Promise<ProbeOutcome> {
  const headers: Record<string, string> = { Accept: "application/json" };
  if (backend.authHeader && backend.apiKey) {
    headers["Authorization"] = `Bearer ${backend.apiKey}`;
  }

  try {
    const res = await fetch(`${backend.baseUrl}/v1/models`, {
      headers,
      signal: combinedSignal(signal),
    });
    if (!res.ok) {
      return { id: backend.id, name: backend.name, baseUrl: backend.baseUrl, reachable: false, models: [] };
    }
    const payload = (await res.json()) as { data?: OpenAIModelRecord[] };
    const records = Array.isArray(payload.data) ? payload.data : [];
    const models = records
      .filter((r) => Boolean(r?.id) && !isNonChatModel(r.id) && !(backend.skipRecord?.(r) ?? false))
      .map((r) => toProviderModel(r, backend));

    return {
      id: backend.id,
      name: backend.name,
      baseUrl: backend.baseUrl,
      reachable: true,
      models,
    };
  } catch {
    return { id: backend.id, name: backend.name, baseUrl: backend.baseUrl, reachable: false, models: [] };
  }
}

export default async function (pi: ExtensionAPI) {
  const backends = buildLocalBackends();
  const initialOutcomes = await Promise.all(backends.map((backend) => probeBackend(backend)));

  for (let i = 0; i < backends.length; i++) {
    const backend = backends[i]!;
    const initial = initialOutcomes[i]!;

    pi.registerProvider(backend.id, {
      name: backend.name,
      baseUrl: `${backend.baseUrl}/v1`,
      apiKey: backend.apiKey,
      ...(backend.authHeader ? { authHeader: true } : {}),
      api: "openai-completions",
      models: initial.models,
      refreshModels: async (context) => {
        const outcome = await probeBackend(backend, context.signal);
        return outcome.models;
      },
    });
  }

  pi.registerCommand("local-models", {
    description: "Refresh and display models discovered from running local servers",
    handler: async (_args, ctx) => {
      const result = await ctx.modelRegistry.refresh({
        providers: backends.map((b) => b.id),
        allowNetwork: true,
        signal: AbortSignal.timeout(3000),
      });

      const outcomes = await Promise.all(backends.map((b) => probeBackend(b)));
      const lines = outcomes.map((o) => {
        if (!o.reachable) return `${o.id} (${o.baseUrl}): offline`;
        return `${o.id} (${o.baseUrl}): ${o.models.length} model(s)`;
      });

      const errorCount = result.errors.size;
      const summary = lines.join(" · ") + (errorCount > 0 ? ` (${errorCount} refresh error(s))` : "");
      ctx.ui.notify(summary, "info");
    },
  });
}
