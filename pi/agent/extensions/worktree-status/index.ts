import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { basename } from "node:path";

/** Return the linked-worktree name when cwd is inside one, else null. */
function getWorktreeName(cwd: string): string | null {
  try {
    const gitDir = execFileSync("git", ["rev-parse", "--git-dir"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const commonDir = execFileSync("git", ["rev-parse", "--git-common-dir"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    // In a linked worktree, git-dir (.git/worktrees/<name>) differs from common-dir.
    // For the main checkout they are equal -> null.
    if (gitDir === commonDir) return null;
    return basename(gitDir);
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const wt = getWorktreeName(ctx.sessionManager.getCwd());
    ctx.ui.setStatus(
      "worktree",
      wt ? ctx.ui.theme.fg("accent", `[wt ${wt}]`) : undefined,
    );
  });
}