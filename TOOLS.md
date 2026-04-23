# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## WorkPod Paths

- Active code root: `/Users/lemanli/work/my/ai/workpod/WorkPod`
- Secondary historical copy: `/Users/lemanli/work/my/ai/workpod/projects/WorkPod` (read only when explicitly needed; do not prefer it)
- Main entry file: `/Users/lemanli/work/my/ai/workpod/WorkPod/Sources/WorkPod/main.swift`
- Project docs dir: `/Users/lemanli/work/my/ai/workpod/projects`
- Canonical progress doc: `/Users/lemanli/work/my/ai/workpod/projects/macOS-工作舱系统-进度文档.md`
- Canonical requirements doc: `/Users/lemanli/work/my/ai/workpod/projects/macOS-工作舱系统-需求文档.md`
- Technical analysis doc: `/Users/lemanli/work/my/ai/workpod/projects/macOS-工作舱系统-技术分析.md`
- Development plan doc: `/Users/lemanli/work/my/ai/workpod/projects/开发计划.md`

## Document Selection Rule

- If both a generic doc and a project-specific doc exist, always choose the project-specific one first.
- Default per-turn read budget: 1 listing, up to 2 project-doc reads, and 1 source-file read.
- Start with the progress doc and one directly relevant source file. Expand to requirements or plan docs only when needed by the current task.
- Default execution budget: one build/test command, one targeted edit batch, then summarize before continuing.
- Long tasks must send periodic progress updates: after each build/test or after every two tool actions.

## Response Completion Rule

- For this workspace, a completed turn must always include a non-empty text summary.
- Minimum summary content: inspected files, whether any file was modified, whether tests were run, and the next action or blocker.
- Never use fake shell blocks or pseudo-command transcripts as a substitute for actual tool execution.
- If you mention a code path, prefer `WorkPod/Sources/WorkPod/...`; do not invent `Sources/App/...` paths.
- If prompt/context usage is growing, stop reading more files and return a short summary so the next turn can continue with a fresh budget.
- On tool failures, prefer these recoveries:
  - `read_file` -> `read`
  - missing path -> `ls` parent + verified retry
  - failed `edit` exact match -> `read` file again + smaller edit
- On build/provider timeout failures (`Body Timeout Error`, `Headers Timeout Error`, provider timeout), do not repeat long commands in the same turn more than once. Summarize exact failure + next retry step and continue next turn.
- Treat provider timeout failures as transient faults that should trigger a fresh short retry turn after a brief cooldown, not a long same-turn retry loop.
- Retry backoff state file: `/Users/lemanli/work/my/ai/workpod/memory/retry-state.json`
- Backoff policy for transient provider/runtime failures: attempt 1 and 2 use 2 minutes; after 2 consecutive transient-failure recovery attempts, use 5 minutes until a successful narrow retry resets the counter.
- If compaction starts, stop increasing scope in that turn. Summarize current file, last successful command, last failure, and the next single recovery action.
