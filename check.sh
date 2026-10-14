#!/bin/sh
# The gate of every tool, run by CI and by hand: `sh check.sh [<renyi binary>]`.
# Each tool directory holds `<name>.ry` as its main file; it must check
# clean under `--strict`, be in canonical layout, pass its examples and
# tests (the recorded ones replaying without touching the disk), and its
# outputs on the sample data must equal the files under `expected/`.
set -e
RENYI="${1:-renyi}"
export RENYI_NO_CACHE=1
root=$(pwd)
work="$root/.check"
rm -rf "$work"
mkdir -p "$work"

for tool in sitegen todo bills; do
  echo "== $tool"
  (cd "$tool" && "$RENYI" check --strict ./*.ry && "$RENYI" format --check ./*.ry && "$RENYI" test "$tool.ry")
done

echo "== sitegen outputs"
(cd sitegen && "$RENYI" run sitegen.ry build sample "$work/site" > /dev/null)
diff -r --exclude=page.convert.html "$work/site" sitegen/expected
(cd sitegen && "$RENYI" run sitegen.ry convert sample/page.md) | diff - sitegen/expected/page.convert.html

echo "== todo outputs"
mkdir -p "$work/todo"
cp todo/sample/todo.json "$work/todo/todo.json"
(cd "$work/todo" && "$RENYI" run "$root/todo/todo.ry" list --all) | diff - todo/expected/list-all.txt
(cd "$work/todo" && TODO_TODAY=2026-10-14 "$RENYI" run "$root/todo/todo.ry" stats) | diff - todo/expected/stats.txt

echo "== bills outputs"
for command in balances settle monthly; do
  (cd bills && "$RENYI" run bills.ry "$command" sample/bills.csv) | diff - "bills/expected/$command.txt"
done
(cd bills && "$RENYI" run bills.ry report sample/bills.csv "$work/report.md" > /dev/null)
diff "$work/report.md" bills/expected/report.md

rm -rf "$work"
echo "every tool passes"
