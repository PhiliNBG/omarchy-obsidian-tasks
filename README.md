# Tasks

Open [Obsidian Tasks](https://publish.obsidian.md/tasks/) checkboxes from a local
vault, in the Omarchy bar.

The bar shows a single icon, lit while anything is open and dimmed when nothing
is. Click it for the list — a count sits under the title — then click a task to
complete it, or type in the box at the bottom to add one. Nothing is cached: the
vault is the only state, so a task added on a phone shows up here as soon as the
next scan lands, and a task ticked here is a rewritten markdown line that sync
carries back out.

Works with anything that keeps the vault current — Obsidian Sync, Syncthing, git —
and with any app that reads the same format, including TaskForge on Android.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-tasks.git --enable
omarchy bar put avoby.tasks --section right
```

Requires `rg` (ripgrep) and `python3`, both standard on Omarchy.

## Settings

Set from the widget's entry in `~/.config/omarchy/shell.json`:

| Key | Default | What it does |
|---|---|---|
| `vaultPath` | `~/Notes` | Folder scanned for checkboxes |
| `inboxFile` | `Tasks/Inbox.md` | Where quick-add appends, relative to the vault |
| `countMode` | `all` | `all` lights the icon for any open task; `due` only for tasks dated today or earlier |
| `refreshIntervalSec` | `60` | Rescan interval; the popup also rescans on open |

`.obsidian`, `.trash`, `.git` and `Templates` are always skipped. Excluding
`Templates` matters more than it looks: a daily-note template containing `- [ ]`
placeholders otherwise inflates the count on every scan, and the phantom tasks
appear in no note you can find.

## Format

Standard Obsidian Tasks emoji syntax. Due dates (`📅`) and priorities
(`🔺⏫🔼🔽⏬`) are read; everything else is left alone and preserved on write.

```markdown
- [ ] Renew car insurance 📅 2026-08-30
- [ ] Reply to landlord ⏫
- [x] Book dentist ✅ 2026-08-25
```

Completing a task rewrites the line in place, appending `✅` and today's date.

## Keys

With the popup open: `j`/`k` or arrows move, `Enter` completes, `a` jumps to the
add box, `r` rescans, `Esc` closes.

## How it works

`Panel.qml` decides what to show. Every read and write goes through
`bin/omarchy-tasks`, a small Python helper — `scan` emits JSON, `complete` ticks a
task, `add` appends one.

Writes are compare-and-swap on the exact line text rather than on a line number,
because sync can rewrite a file between the scan that drew a row and the click
that completes it. If the line has moved, the write is a no-op rather than a
guess at which line was meant.
