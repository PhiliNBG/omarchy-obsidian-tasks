# Tasks

Open [Obsidian Tasks](https://publish.obsidian.md/tasks/) checkboxes from a local
vault, in the Omarchy bar.

The bar shows a single icon, lit while anything is open and dimmed when nothing
is. Click it for the list — a count sits under the title. Tick a task's box to
complete it, click its text to rename it in place, or type in the box at the
bottom to add one.

A ticked task stays on screen struck through for a moment before it goes, and
clicking its box again in that window puts it back. Nothing is cached: the
vault is the only state, so a task added on a phone shows up here as soon as the
next scan lands, and a task ticked here is a rewritten markdown line that sync
carries back out.

Works with anything that keeps the vault current — Obsidian Sync, Syncthing, git —
and with any app that reads the same format, including TaskForge on Android.

## Install

```bash
omarchy plugin add https://github.com/mjke87/obsidian-tasks.git --enable
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

## Dates

A trailing date phrase in the add box becomes a due date, and is taken out of the
task text:

```
pay rent friday        →  - [ ] pay rent 📅 2026-08-28
review pr in 3 days    →  - [ ] review pr 📅 2026-08-29
ship it next week      →  - [ ] ship it 📅 2026-09-02
call bank 2026-09-01   →  - [ ] call bank 📅 2026-09-01
```

Understood: `today`, `tomorrow`, `next week`, a weekday name, `in N days`,
`in N weeks`, and an explicit `YYYY-MM-DD`. Naming today's weekday means the next
one, not today.

Only a *trailing* phrase counts. `friday night drinks` keeps its wording,
because stripping mid-sentence would quietly rewrite what the task says. Renaming
a task reads dates the same way.

## Keys

With the popup open: `j`/`k` or arrows move, `Enter` ticks or unticks, `e` edits
the task under the cursor, `a` jumps to the add box, `r` rescans, `Esc` closes.

## How it works

`Panel.qml` decides what to show. Every read and write goes through
`bin/omarchy-tasks`, a small Python helper — `scan` emits JSON; `complete`,
`uncomplete` and `rename` each rewrite one line; `add` appends one.

The three rewrites share a single primitive that splits a task into description
and metadata at the first Obsidian Tasks signifier, so an edit changes only what
it means to and leaves `📅`, `⏫` and anything else it doesn't understand intact.

Writes are compare-and-swap on the exact line text rather than on a line number,
because sync can rewrite a file between the scan that drew a row and the click
that completes it. If the line has moved, the write is a no-op rather than a
guess at which line was meant.
