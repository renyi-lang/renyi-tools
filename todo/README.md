# todo

A to-do list for the command line, written in Renyi. The list lives in
`todo.json` in the current directory; every command reads it, and the
commands that change it write it back.

```
$ renyi run todo.ry add buy bread #shop
added 1: buy bread  #shop
$ renyi run todo.ry add write the report #work #Urgent
added 2: write the report  #work #urgent
$ renyi run todo.ry list
  1 [ ] buy bread  #shop
  2 [ ] write the report  #work #urgent
2 open, 0 done
$ renyi run todo.ry done 1
done 1: buy bread  #shop
$ renyi run todo.ry stats
2 items: 1 open, 1 done
done this week (since 2026-10-12): 1
tags:
  #shop         0 open, 1 done
  #urgent       1 open, 0 done
  #work         1 open, 0 done
  untagged items: 0
$ renyi run todo.ry clear
cleared 1 done item
$ renyi run todo.ry done 9
todo: there is no item 9; `list --all` shows the ids
```

## Commands

| Command | What it does |
|---------|--------------|
| `add <title words...>` | adds an open item; every `#word` of the title is a tag (lower case) and is taken out of the title |
| `list` | the open items, oldest first, with their ids and tags, then the open and done counts |
| `list --all` | the done items too, each with the day it was done |
| `list --tag <tag>` | only the items with the tag (`home` or `#home`); combines with `--all` |
| `done <id>` | marks the item done today |
| `undo <id>` | opens a done item again |
| `edit <id> <new title...>` | replaces the item's title and tags; its dates are kept |
| `remove <id>` | deletes the item |
| `clear` | deletes every done item |
| `stats` | the totals, the items done since this week's Monday, the open and done counts per tag |
| `help`, or no command | the usage |

An unknown command, an unknown option, a missing or malformed id, an id
that is not in the store, `done` on a done item and `undo` on an open one
print one line starting with `todo:` on the standard error and exit with
status 1. A new item's id is one more than the largest id in the store.

The date of `add`, `done` and `stats` is today's in UTC from `std.time`;
when the variable `TODO_TODAY` holds a date (`2026-10-14`), that date is
used instead, which is how `expected/stats.txt` stays reproducible.

## The store

`todo.json` is a JSON list of items, written indented by
`json.render_indented`; a missing file is an empty list. One item:

```json
{
  "id": 4,
  "title": "fix the bike",
  "tags": ["home", "weekend"],
  "done": true,
  "added_on": "2026-10-08",
  "done_on": "2026-10-13"
}
```

`done_on` is `null` for an open item. The record type is `Item` in
`items.ry` (`can FromJson`, `can ToJson`; the field `labels` is written
as `"tags"`, since `tags` is a reserved word of Renyi).
`sample/todo.json` is a store of six items the tests and `expected/` use.

## The grant

```
public function main()
  needs console, environment, time, filesystem.read("todo.json"), filesystem.write("todo.json")
```

The reviewer reads in this line everything the program can do: print,
read its arguments and environment variables, read the clock, and read
and write the one file `todo.json` of the current directory. Any other
path is refused by the runtime with `PermissionDenied`, whatever the code
asks for; the checker refuses a body that would need more (a function
that took the store's path as a parameter and needed `filesystem.read`
without a scope would not be callable from this `main`, which is why the
file access is confined to `read_store` and `write_store`, whose needs
name the same literal path).

The modules split along the effects:

| File | Effects | Content |
|------|---------|---------|
| `items.ry` | none | `Item`, `TodoError`, `Stats`; tags, ids, add, done, undo, edit, remove, clear, the list filter, the week, the statistics |
| `render.ry` | none | the item line, the list, the statistics, the error messages, the usage |
| `todo.ry` | `perform` and `respond`: `environment("TODO_TODAY")`, `time`; `read_store`, `write_store` and `main`: the file | the command line, the dispatch, the store's text, `main` |

`respond(arguments, store)` parses a command line and carries it out on
a list of items, returning the lines to print, the new list and whether
it changed; `main` is `respond` between `read_store` and `write_store`.

## Tests

```
renyi test todo.ry
```

runs every `example:` line of the three modules (pure functions) and the
four `test` blocks of `todo.ry`, `add`, `list`, `done` and `stats`. Each
of these reads `sample/todo.json` through `sample_store()`, calls
`respond` with a command line and checks the lines it returns and the
store after it. Each head names its grant and its recording:

```
test "add" needs filesystem.read("sample"), environment, time replays "fixtures/add.json"
```

The recordings under `fixtures/` hold every effect of one live run: the
sample's text, the lookup of `TODO_TODAY` and today's date. `renyi test`
answers the calls from them, so the tests touch neither the disk nor the
clock: they pass in a copy of this directory without `sample/`, and on
any day (the recorded date is 2026-10-14). No test writes: the tests
check the new store `respond` returns, and only `main` writes.

To record a test again after changing it or the sample (from this
directory, with `TODO_TODAY` unset, and then adjust the dates the test
checks to the day of the recording):

```
renyi test --refresh "add" todo.ry
```

## Expected output

`expected/list-all.txt` and `expected/stats.txt` are the exact standard
output of the tool on the sample store. To reproduce them without
touching the sample, run it in a copy:

```
mkdir -p /tmp/todo-check && cp sample/todo.json /tmp/todo-check/
cd /tmp/todo-check
renyi run <this directory>/todo.ry list --all | diff - <this directory>/expected/list-all.txt
TODO_TODAY=2026-10-14 renyi run <this directory>/todo.ry stats | diff - <this directory>/expected/stats.txt
```
