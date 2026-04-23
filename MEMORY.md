# MEMORY.md - Long-Term Memory

## Current Project Anchor

- The active project in this workspace is the macOS WorkPod / 工作舱系统 project.
- The canonical code root is `WorkPod/`, not `projects/WorkPod/`.
- The canonical progress document is `projects/macOS-工作舱系统-进度文档.md`.
- The canonical requirements document is `projects/macOS-工作舱系统-需求文档.md`.
- The technical analysis document is `projects/macOS-工作舱系统-技术分析.md`.
- `projects/项目进度文档.md` and `projects/需求文档.md` are generic templates, not the source of truth for the active project.

## Execution Rules

- When asked to "continue modifying", first read the canonical progress doc, then the development plan, then inspect actual code under `WorkPod/`.
- Use small read batches. Default per-turn budget: 1 directory listing, up to 2 project-doc reads, and 1 source-file read.
- Use small execution batches too: one build/test command, one narrow fix, then summarize.
- For long coding tasks, emit a short progress summary after each build/test or after every two tool actions.
- Prefer reading the progress doc and one directly relevant source file before any broader document sweep.
- If more files are needed, summarize what was learned and continue in the next turn instead of loading everything at once.
- Do not rely on generic template docs when project-specific docs exist.
- Do not repeat the same file read if the intent was to switch to a different document.
- Do not emit fake shell commands, pseudo-execution transcripts, or invented code paths in place of real work.
- On tool failure, recover by switching to the closest verified supported tool or by re-listing the immediate parent path once. Do not spam the same failing tool call.
- If build or model transport errors appear (`Body Timeout Error`, `Headers Timeout Error`, provider timeout), stop same-turn retries after one retry and return a short recovery summary for the next turn.
- Treat `Body Timeout Error` and `Headers Timeout Error` as transient runtime faults, not as a reason to keep hammering the same long turn. End the bloated turn, keep the summary precise, and resume with one narrow retry in a fresh short turn.
- Use `memory/retry-state.json` to track transient runtime retry backoff. Default: the first two recovery attempts wait 2 minutes; if two consecutive recovery attempts still fail with transient runtime faults, increase the next cooldown to 5 minutes.
- If compaction starts, treat it as a signal to stop extending the turn. Summarize the exact current file, last real error, and next smallest step.
- If the next step is unclear, state the exact file path being used rather than ending on a transition sentence.
- Never finish a completed turn with empty content. Always emit a short non-empty status summary.
- The status summary should mention: files inspected, code changed or not changed, test status if any, and the next step or blocker.
- Preserve recent actionable context over distant background. If the conversation is large, prefer another short turn over another large read batch.
- Prefer compressing old turns into short textual memory over carrying long raw transcript history.
