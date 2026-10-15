# Renyi tools

Three command-line tools that do real work, written in
[Renyi](https://renyi-lang.org), the scripting language of AI agents.
Each is a few hundred lines whose `main` signature says, to the path,
what the tool can touch; the checker refuses a body that does more, and
the VM refuses it again at run time.

| Tool | Directory | What it does | The grant of `main` |
|------|-----------|--------------|---------------------|
| sitegen | [`sitegen/`](sitegen/) | a static site generator with a Markdown-to-HTML converter (`convert <file.md>`, `build <source> <output>`) | `console, environment, filesystem.read("."), filesystem.write(".")` |
| todo | [`todo/`](todo/) | a to-do list in a JSON file of the current directory (`add`, `list`, `done`, `undo`, `remove`, `edit`, `clear`, `stats`) | `console, environment, time, filesystem.read("todo.json"), filesystem.write("todo.json")` |
| bills | [`bills/`](bills/) | shared bills from a CSV: `balances`, `settle` (who pays whom), `monthly`, `report <out.md>` | `console, environment, filesystem.read("."), filesystem.write(".")` |

The to-do tool's grant names the one file it may read and write. The
other two take their paths from the command line, so their `main`
declares the current directory, `"."`: every relative path that does not
climb out of it, and no absolute one (release 0.2.1; at 0.2.0 that scope
refused every relative path). The person running them can narrow the
grant further from outside: `renyi run bills.ry report sample/bills.csv
out.md --allow-read sample --allow-write out.md`, or a `--sandbox` grant
file; each README shows it.

Every tool follows the starter pack of the main repository: the logic in
pure modules with an `example:` on every function, the effects in a few
functions, and every function with effects tested through a recording
(`replays "fixtures/<name>.json"`, made once with `renyi test --refresh`),
so that `renyi test` passes without touching the disk, the clock or the
environment. Each directory's README gives the commands, the data
formats and the rules.

## The gate

`sh check.sh [<renyi binary>]` runs what CI runs on every push: every
tool checks clean under `renyi check --strict`, is in the formatter's
canonical layout, passes `renyi test`, and its outputs on the sample data
equal the files under its `expected/`. CI installs the released
toolchain through the main repository's `install.sh`.

The tools were written by Claude Code subagents from the language's
skill file, the cheat sheet and the starter workflows, and reviewed in
sessions with the owner; see the main repository's
`docs/design/01-decisions.md`, decision AW45, for the record.

## License

Apache 2.0, as the main repository.
