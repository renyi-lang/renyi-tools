# sitegen

A static site generator written in Renyi: a Markdown-to-HTML converter and a
command that turns a directory of Markdown files into a small website.

| File | What it holds |
|------|---------------|
| `markdown.ry` | the converter, pure: a line scanner for the blocks and a character scanner for the inline markup; every function carries `example:` lines |
| `site.ry` | the site, pure: a page's title, the page template with its inline stylesheet, the navigation, `index.html` |
| `sitegen.ry` | the tool: reading the source directory, writing the output directory, `main`, and the recorded test of `build` |
| `sample/` | four Markdown pages that use every construct (`index.md`, `guide.md`, `notes.md`, `page.md`) |
| `expected/` | what `build sample <dir>` writes, file for file, and `page.convert.html`, what `convert sample/page.md` prints |
| `fixtures/build.json` | the recording the test of `build` replays |

## The Markdown subset

- ATX headings `#`, `##` and `###`, followed by a space.
- Paragraphs: consecutive lines of text; their line breaks are kept inside `<p>`.
- `**bold**`, `*italic*`, `` `inline code` `` and links `[text](url)`; bold, italic
  and link texts may nest the other inline constructs, code spans are literal.
- Fenced code blocks between two lines starting with ```` ``` ````; the word after the
  opening fence becomes `class="language-<word>"`; the lines are kept as they are.
- Unordered lists (`- item`) and ordered lists (`1. item`, any number); one level.
- A blank line ends a block; so does a heading, a fence or a line of another kind of list.
- `<`, `>` and `&` in text are written `&lt;`, `&gt;` and `&amp;`; in a link's `href` the
  double quote is escaped too.

Anything else is text. A delimiter without its closing partner is kept as written.

## The commands

```
renyi run sitegen.ry convert <file.md>
renyi run sitegen.ry build <source directory> <output directory>
```

`convert` prints the HTML of one file, without a page around it.

`build` turns every `.md` file of the source directory (not its subdirectories)
into `<name>.html` in the output directory, which it creates if needed. Each page
gets the title of its first heading (or its file name without one), a navigation
bar listing every page, and the same small stylesheet inline. `index.html` lists
the pages; when the source has an `index.md`, its content comes first and the list
follows it, otherwise the page is titled "Index". `index.html` is written first, then the pages in name order,
and the output depends only on the sources, so `expected/` can be compared byte
for byte:

```
renyi run sitegen.ry build sample /tmp/site
diff -r --exclude=page.convert.html /tmp/site expected
renyi run sitegen.ry convert sample/page.md | diff - expected/page.convert.html
```

A failure ends the run with exit status 1 and names its cause:
`UsageError(...)` for a command line it does not understand, or the
`FileError` of the file (`NotFound(path: "...")`, `PermissionDenied(path: "...")`).

## The grant of `main`

```
public function main()
  or fails with UsageError or FileError
  needs console, environment, filesystem.read, filesystem.write
```

This line is everything the program can do outside its own memory: print
(`console`), read its command line (`environment`), read files and write files.
Nothing else: no network, no other programs, no clock, no randomness. A reviewer
reads it from the signature without reading the body, and the checker has
verified that no function the program calls needs more.

The two file capabilities are unscoped, and that is a deliberate choice. A scope
in `needs` is a text literal, a path prefix fixed when the program is written
(`filesystem.read("sample")`), so a scoped grant cannot follow a directory given
on the command line. The current directory as a prefix does not help either: with
release 0.2.0 a scope of `"."`, `"./"` or `""` refused the relative path `sample`
with `PermissionDenied`, so only the unscoped capability lets the tool take its
directories as arguments. `build` and `convert` declare the same unscoped
capabilities, since they take their paths as parameters; the pure modules,
`markdown.ry` and `site.ry`, declare nothing and the checker holds them to it.

What the program may touch is narrowed when it is run, and only narrowed: the
command line can tighten the grant, never widen it.

```
# convert may read only under sample/
renyi run --allow-read sample sitegen.ry convert sample/page.md

# build may read sample/ and site/ and write only site/
renyi run --sandbox grant.json sitegen.ry build sample site
```

with `grant.json`:

```json
{
  "grant": "console, environment, filesystem.read(\"sample\"), filesystem.read(\"site\"), filesystem.write(\"site\")"
}
```

`build` reads the output directory too (it asks whether it exists before creating
it). Two `--allow-read` flags intersect, so two read prefixes need `--sandbox`.
Under such a grant, `build sample elsewhere` stops before it writes anything,
naming the path the grant does not allow.

## The tests

`renyi test sitegen.ry` runs every `example:` of `markdown.ry` and `site.ry` and
the test `"the sample site builds"`, which calls `build(source: Path("sample"),
output: Path("test_out"))`. That test has effects, so it is tested through a
recording:

```
test "the sample site builds" needs filesystem.read, filesystem.write replays "fixtures/build.json"
```

It was recorded once, live, with

```
renyi test --refresh "the sample site builds" sitegen.ry
rm -r test_out
```

which ran the body under its `needs` and wrote every file call it made (the
listing of `sample/`, the four reads, the existence check, the directory created
and the four writes with their full content) to `fixtures/build.json`. From then
on `renyi test sitegen.ry` answers those calls from the recording and touches
nothing on disk. A call is answered only when the recording holds the same call
with the same arguments, so a change to the converter or the template that alters
a written page fails the test with the call it could not find; after an intended
change, record it again and compare the new pages with `expected/`.
