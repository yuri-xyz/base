from @std/Args import { contains as argsContains, findFlagValueOpt, removeBoolFlag }
from @std/List import { map, filter, filterMap, uniq }
from @std/Option import { orElseOption }
from @std/String import {
  trim,
  toLowerCase,
  toChars,
  join,
  isEmpty,
  endsWith,
  startsWith,
  contains,
  replaceAll,
  length,
  take,
  split,
  sliceFrom as stringDropFrom
}

@public
fun normalizeStatus(raw: String): Option String {
  let lowered = toLowerCase(trim(raw));

  if lowered == "todo":
    Option.Some("todo")
  elif lowered == "in_progress" or lowered == "in-progress" or lowered == "doing":
    Option.Some("in_progress")
  elif lowered == "done" or lowered == "complete" or lowered == "completed":
    Option.Some("done")
  else:
    Option.None
}

@public
fun normalizeRoadmapStatus(raw: String): Option String {
  let lowered = toLowerCase(trim(raw));

  if lowered == "planned" or lowered == "plan":
    Option.Some("planned")
  elif lowered == "active" or lowered == "in_progress" or lowered == "in-progress":
    Option.Some("active")
  elif lowered == "done" or lowered == "complete" or lowered == "completed":
    Option.Some("done")
  else:
    Option.None
}

@public
fun normalizePlanStatus(raw: String): Option String {
  normalizeRoadmapStatus(raw)
}

@public
fun parseTagsCsv(raw: String): List String {
  let pieces = splitCsv(raw);

  uniq(filterMap(pieces, normalizeTagName))
}

fun splitCsv(raw: String): List String {
  split(raw, ",")
}

@public
fun normalizeTagName(raw: String): Option String {
  let normalized = toLowerCase(trim(raw));

  if normalized == "":
    Option.None
  else:
    Option.Some(normalized)
}

@public
fun slugify(raw: String): String {
  let lower = toLowerCase(trim(raw));
  let chars = toChars(lower);
  let compact = collapseDashes(chars, false, []);
  let candidate = trimDashes(join(compact, ""));

  if candidate == "": "project" else: candidate
}

fun collapseDashes(chars: List String, lastWasDash: Bool, acc: List String): List String {
  match chars with:
    | [] -> acc
    | [ch, ...rest] ->
        let normalized = if isSlugChar(ch): ch else: "-";

        if normalized == "-" and lastWasDash:
          collapseDashes(rest, true, acc)
        else:
          collapseDashes(rest, normalized == "-", acc & [normalized])
}

fun isSlugChar(ch: String): Bool {
  ch >= "a" and ch <= "z" or ch >= "0" and ch <= "9" or ch == "-"
}

fun trimDashes(value: String): String {
  trimDashesRight(trimDashesLeft(value))
}

fun trimDashesLeft(value: String): String {
  if startsWith(value, "-"):
    trimDashesLeft(sliceFrom(value, 1))
  else:
    value
}

fun trimDashesRight(value: String): String {
  if endsWith(value, "-"):
    trimDashesRight(take(value, length(value) - 1))
  else:
    value
}

fun sliceFrom(value: String, start: Int): String {
  stringDropFrom(value, start)
}

@public
fun normalizeDocName(rawName: String): String {
  let lower = toLowerCase(trim(rawName));
  let chars = toChars(lower);
  let safeChars = map(chars, normalizeDocChar);
  let noEdgeDash = trimDashes(join(safeChars, ""));

  let base = if noEdgeDash == "": "untitled" else: noEdgeDash;

  if endsWith(base, ".md"):
    base
  else:
    `${base}.md`
}

fun normalizeDocChar(ch: String): String {
  if ch >= "a" and ch <= "z" or ch >= "0" and ch <= "9" or ch == "." or ch == "_" or ch == "-":
    ch
  else:
    "-"
}

@public
fun normalizedExcerpt(text: String, maxLen: Int): String {
  let collapsed = collapseWhitespace(text);

  if length(collapsed) <= maxLen:
    collapsed
  else:
    let prefix = take(collapsed, maxLen - 3);

    `${prefix}...`
}

fun collapseWhitespace(text: String): String {
  let normalized = replaceAll(replaceAll(replaceAll(text, "\r", " "), "\n", " "), "\t", " ");

  trim(collapseDoubleSpaces(normalized))
}

fun collapseDoubleSpaces(text: String): String {
  if contains(text, "  "):
    collapseDoubleSpaces(replaceAll(text, "  ", " "))
  else:
    text
}

@public
fun isSubsequence(needleRaw: String, hayRaw: String): Bool {
  let needle = toChars(toLowerCase(trim(needleRaw)));
  let hay = toChars(toLowerCase(hayRaw));

  isSubsequenceChars(needle, hay)
}

fun isSubsequenceChars(needle: List String, hay: List String): Bool {
  match needle with:
    | [] -> true
    | [n, ...nrest] -> match hay with:
      | [] -> false
      | [h, ...hrest] -> if n == h:
        isSubsequenceChars(nrest, hrest)
      else:
        isSubsequenceChars(needle, hrest)
}

@public
fun fuzzyDocScore(queryRaw: String, nameRaw: String, contentRaw: String): Int {
  let query = toLowerCase(trim(queryRaw));
  let name = toLowerCase(nameRaw);
  let content = toLowerCase(contentRaw);

  if isEmpty(query):
    0
  else:
    let nameScore = if name == query:
      500
    elif startsWith(name, query):
      340
    elif contains(name, query):
      220
    elif isSubsequence(query, name):
      110
    else:
      0;

    let contentScore = if contains(content, query):
      70
    elif isSubsequence(query, content):
      20
    else:
      0;

    nameScore + contentScore
}

@public
fun hasFlag(tokens: List String, shortFlag: String, longFlag: String): Bool {
  argsContains(tokens, shortFlag) or argsContains(tokens, longFlag)
}

@public
fun findOptionValue(tokens: List String, shortFlag: String, longFlag: String): Option String {
  let shortValue = findFlagValueOpt(tokens, shortFlag);
  let longValue = findFlagValueOpt(tokens, longFlag);

  orElseOption(shortValue, longValue)
}

@public
fun stripToken(tokens: List String, token: String): List String {
  removeBoolFlag(tokens, token)
}
