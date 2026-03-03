from @std/Args import { contains as argsContains, findFlagValueOpt, removeBoolFlag }
from @std/List import { map, filter, filterMap, uniq }
from @std/Option import { orElseOption }
from @std/String import {
  trim,
  toLowerCase,
  toChars,
  join,
  parseIntOr,
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
type alias CliOptionSpec = {
  flags: List String,
  expectsValue: Bool
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

@public
fun nextGeneratedId(existingIds: List String, keyRaw: String): String {
  let nextNumber = maxSeenSequence(existingIds, 0) + 1;
  let slug = slugify(keyRaw);
  let numberText = show(nextNumber);

  `#${numberText}-${slug}`
}

@public
fun resolveIdKey(idKeyRawOpt: Option String, fallback: String): String {
  match idKeyRawOpt with:
    | Option.None -> fallback
    | Option.Some rawKey ->
        let normalized = trim(rawKey);

        if normalized == "":
          fallback
        else:
          normalized
}

@public
fun resolveEntityIdReference(
  existingIds: List String,
  providedIdRaw: String,
  entityName: String
): Result String String {
  let providedId = trim(providedIdRaw);

  if hasExactId(existingIds, providedId):
    Result.Ok(providedId)
  else:
    match parseShortSequence(providedId) with:
      | Option.None -> Result.Err(`${entityName} not found: ${providedIdRaw}`)
      | Option.Some seq -> match collectBySequence(existingIds, seq, []) with:
        | [] -> Result.Err(`${entityName} not found: ${providedIdRaw}`)
        | [resolved] -> Result.Ok(resolved)
        | matches ->
            let label = toLowerCase(entityName);
            let options = join(matches, ", ");

            Result.Err(`Ambiguous ${label} id: ${providedId}. Matches: ${options}`)
}

fun maxSeenSequence(ids: List String, currentMax: Int): Int {
  match ids with:
    | [] -> currentMax
    | [currentId, ...rest] -> match parseAnySequence(currentId) with:
      | Option.None -> maxSeenSequence(rest, currentMax)
      | Option.Some seq ->
          let nextMax = if seq > currentMax: seq else: currentMax;

          maxSeenSequence(rest, nextMax)
}

fun parseAnySequence(rawId: String): Option Int {
  let value = trim(rawId);

  if !startsWith(value, "#"):
    Option.None
  else:
    let withoutHash = sliceFrom(value, 1);

    match split(withoutHash, "-") with:
      | [] -> Option.None
      | [head, ..._tail] -> parseDigitsToInt(head)
}

fun parseShortSequence(rawId: String): Option Int {
  let value = trim(rawId);

  if !startsWith(value, "#") or contains(value, "-"):
    Option.None
  else:
    parseDigitsToInt(sliceFrom(value, 1))
}

fun parseDigitsToInt(rawDigits: String): Option Int {
  let digits = trim(rawDigits);

  if isDigits(digits):
    Option.Some(parseIntOr(digits, 0))
  else:
    Option.None
}

fun isDigits(value: String): Bool {
  value != "" and areAllDigits(toChars(value))
}

fun areAllDigits(chars: List String): Bool {
  match chars with:
    | [] -> true
    | [ch, ...rest] -> if ch >= "0" and ch <= "9":
      areAllDigits(rest)
    else:
      false
}

fun hasExactId(ids: List String, candidate: String): Bool {
  match ids with:
    | [] -> false
    | [currentId, ...rest] -> if currentId == candidate:
      true
    else:
      hasExactId(rest, candidate)
}

fun collectBySequence(ids: List String, seq: Int, acc: List String): List String {
  match ids with:
    | [] -> acc
    | [currentId, ...rest] -> match parseAnySequence(currentId) with:
      | Option.None -> collectBySequence(rest, seq, acc)
      | Option.Some current -> if current == seq:
        collectBySequence(rest, seq, acc & [currentId])
      else:
        collectBySequence(rest, seq, acc)
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
fun hasHelpFlag(tokens: List String): Bool {
  hasFlag(tokens, "-h", "--help")
}

@public
fun isHelpRequest(tokens: List String): Bool {
  match tokens with:
    | ["help", ..._rest] -> true
    | _ -> hasHelpFlag(tokens)
}

@public
fun validateOptions(tokens: List String, specs: List CliOptionSpec): Result String Unit {
  match tokens with:
    | [] -> Result.Ok(())
    | [token, ...rest] -> if startsWith(token, "-"):
      match findMatchingOptionSpec(specs, token) with:
        | Option.None -> Result.Err(`Unknown option: ${token}`)
        | Option.Some spec -> validateMatchedOption(rest, specs, token, spec.expectsValue)
    else:
      Result.Err(`Unexpected argument: ${token}`)
}

fun validateMatchedOption(
  rest: List String,
  specs: List CliOptionSpec,
  token: String,
  expectsValue: Bool
): Result String Unit {
  if expectsValue:
    validateOptionValue(rest, specs, token)
  else:
    validateOptions(rest, specs)
}

fun validateOptionValue(rest: List String, specs: List CliOptionSpec, token: String): Result String Unit {
  match rest with:
    | [] -> Result.Err(`Missing value for option: ${token}`)
    | [_value, ...tail] -> validateOptions(tail, specs)
}

fun findMatchingOptionSpec(specs: List CliOptionSpec, token: String): Option CliOptionSpec {
  match specs with:
    | [] -> Option.None
    | [spec, ...rest] -> if optionSpecContains(spec.flags, token):
      Option.Some(spec)
    else:
      findMatchingOptionSpec(rest, token)
}

fun optionSpecContains(flags: List String, token: String): Bool {
  match flags with:
    | [] -> false
    | [flag, ...rest] -> if flag == token:
      true
    else:
      optionSpecContains(rest, token)
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
