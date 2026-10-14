# bills: settle shared bills

`bills.ry` reads a CSV file of shared bills (who paid how much, for whom)
and prints what each person paid and owes, the transfers that settle every
balance, the totals per month, or all three as a Markdown report. It is
written in Renyi: the arithmetic is exact (`Decimal`, split in whole
cents), the algorithms are a pure module with an example on every
function, and the `needs` line of `main` is the whole of what the program
may touch.

| File | What it holds |
|------|---------------|
| `bills.ry` | `main`, loading the file, the text tables and the Markdown report, the tests |
| `split.ry` | pure: shares to the cent, balances, the settlement, the monthly totals |
| `rows.ry` | pure: the CSV rows checked and turned into bills, with the file and line of a bad row |
| `sample/bills.csv` | fifteen bills over three months among four people |
| `expected/` | the exact output of each command on the sample |
| `fixtures/report.json` | the recording the `replays` test answers from |

## The CSV format

```csv
date,payer,amount,description,participants
2026-07-01,alice,1200.00,July rent,
2026-07-08,carol,42.10,"pizza, salad and drinks",alice;bob;carol
```

- The header names the five columns (any order); a cell with a comma is
  quoted, as CSV quotes it.
- `date` is `YYYY-MM-DD`; its first seven characters are the month.
- `payer` is a name: a letter, then letters, digits, `_`, `-` or `.`.
  Names are case-sensitive (`Alice` and `alice` are two people).
- `amount` is a positive number with at most two decimal places.
- `description` is free text and may be empty.
- `participants` is a `;`-separated list of names (spaces around a name
  are dropped, a repeated name counts once). An empty cell means everyone
  who appears anywhere in the file, as a payer or as a participant. The
  payer need not be a participant: paying for others is allowed.

A bad row stops the program with exit status 1 and an error naming the
file and the line (the header is line 1):

```text
$ renyi run bills.ry balances bad.csv
bills.ry: main failed with bad.csv, line 3: amount is not a number: ten
```

The other refusals: `missing payer` (a blank required cell),
`date is not YYYY-MM-DD: ...`, `payer is not a name: "..."`,
`participant 2 is not a name: ""` (as in `alice;;bob`; a quoted
`"alice,bob"` gives `participant 1 is not a name`), `amount is not positive: 0`,
`amount has more than two decimal places: 1.005`, `the row has 4 cells,
the header 5`, `the header has no column description`, and
`bills.csv: no such file or directory`.

## The rules

**Splitting.** A bill of `amount` among `n` participants is split in whole
cents: each gets `amount_in_cents quotient n` cents, and the
`amount_in_cents remainder n` cents left over go one each to the first
participants in name order (alphabetical, as Renyi compares texts). The
shares always add up to the amount. 10.00 among carol, alice and bob gives
alice 3.34, bob 3.33 and carol 3.33; 0.05 among four gives the first in
name order 0.02 and the others 0.01.

**Balances.** A person's `paid` is the sum of the bills they paid, `owed`
the sum of their shares, `net` is `paid - owed`: positive means the others
owe them money. The nets always sum to zero.

**Settlement.** Greedy, debtor to creditor: while a balance is open, the
largest debtor (most negative net) pays the largest creditor (most
positive net) the smaller of the two amounts, which closes at least one of
the two balances. Ties go to the name first in alphabetical order. With
`p` people the settlement has at most `p - 1` transfers; it is not always
the fewest possible (that problem is NP-hard), but it is deterministic and
easy to check by hand. Debts of -30.00 and -10.00 against credits of
25.00 and 15.00 settle in three transfers: alice pays carol 25.00, bob
pays dave 10.00, alice pays dave 5.00.

**Monthly.** The bills of each month (the date's first seven characters),
balanced as above on their own: per person paid, owed and net, then the
month's total.

## The commands

Run from this directory, with the sample:

```text
$ renyi run bills.ry balances sample/bills.csv
person        paid      owed       net
alice      1225.00   1045.08    179.92
bob        1343.96   1082.55    261.41
carol      1415.43   1082.55    332.88
dave        304.28   1078.49   -774.21
total      4288.67   4288.67      0.00

$ renyi run bills.ry settle sample/bills.csv
dave pays carol 332.88
dave pays bob 261.41
dave pays alice 179.92

$ renyi run bills.ry monthly sample/bills.csv
month    person        paid      owed       net
2026-07  alice      1225.00    363.16    861.84
2026-07  bob          86.47    350.65   -264.18
2026-07  carol        42.10    350.65   -308.55
2026-07  dave         60.00    349.11   -289.11
2026-07  total      1413.57   1413.57      0.00
2026-08  alice         0.00    330.84   -330.84
2026-08  bob        1219.99    380.83    839.16
2026-08  carol       113.33    380.83   -267.50
2026-08  dave        150.00    390.82   -240.82
2026-08  total      1483.32   1483.32      0.00
2026-09  alice         0.00    351.08   -351.08
2026-09  bob          37.50    351.07   -313.57
2026-09  carol      1260.00    351.07    908.93
2026-09  dave         94.28    338.56   -244.28
2026-09  total      1391.78   1391.78      0.00

$ renyi run bills.ry report sample/bills.csv report.md
wrote report.md (38 lines)
```

The report holds the three sections as Markdown tables;
`expected/report.md` is the one the sample gives. CI compares each
command's output with `expected/`:

```sh
for command in balances settle monthly; do
  renyi run bills.ry $command sample/bills.csv | diff - expected/$command.txt
done
renyi run bills.ry report sample/bills.csv report.md && diff report.md expected/report.md
```

A wrong command line also fails with status 1 and the usage.

## The grant of `main`

```
public function main()
  or fails with BillError or UsageError
  needs console, environment, filesystem.read, filesystem.write
```

`console` prints, `environment` reads the arguments, `filesystem.read`
reads the bills file and `filesystem.write` writes the report (only the
`report` command calls it). The two filesystem capabilities carry no scope
because both paths come from the command line: a scope is a literal fixed
when the program is written (`filesystem.read("data")`), and the run-time
check refuses every path outside it. With `filesystem.read("sample")` the
program reads `sample/bills.csv` and `./sample/bills.csv` but refuses an
absolute path and anything outside `sample/`; `filesystem.read(".")`
refuses even `bills.csv` in the working directory. The checker accepts any
literal scope here, since the path is only known at run time; the scope is
the run's business.

Whoever runs the program narrows the grant on the command line, and the
library primitives enforce it:

```text
$ mkdir out
$ renyi run --allow-read sample --allow-write out bills.ry report sample/bills.csv out/report.md
wrote out/report.md (38 lines)
$ renyi run --allow-read data bills.ry balances sample/bills.csv
bills.ry: main failed with sample/bills.csv: outside the grant of this run
```

`renyi run --manifest bills.ry settle sample/bills.csv` prints the grant
with the run.

## Tests

```sh
renyi check --strict *.ry     # clean: no output, exit 0
renyi test bills.ry           # every example of the three modules and the three tests
```

`renyi test bills.ry` runs the examples of `bills.ry` and of the modules it
imports, a test of the invariants in `split.ry` (the nets sum to zero, the
settlement zeroes every balance in at most `p - 1` transfers), a test of
the table layout, and `"the sample report"`, which writes the report of
the sample and checks the same invariants on it. That test needs
`filesystem.read` and `filesystem.write` and replays
`fixtures/report.json`: `renyi test` answers its read of
`sample/bills.csv` and its write of `tmp/report.md` from the recording and
touches nothing on disk. It was recorded once, live:

```sh
mkdir tmp
renyi test --refresh "the sample report" bills.ry
rm -r tmp
```

Record it again the same way after changing the sample or the report.
