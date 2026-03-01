from @std/List import { filterMap, uniq, sort, length }
from @std/Time import { date }
from "./Models" import { Scope, Task }
from "./Store" import { loadTags, saveTags, loadTasks, saveTasks }
from "./Util" import { normalizeTagName }

@public
fun listGlobalTags(scope: Scope): Result String (List String) effects { IO } {
  match loadTags(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tags -> Result.Ok(sortTags(normalizeTagList(tags)))
}

@public
fun ensureGlobalTags(scope: Scope, rawTags: List String): Result String (List String) effects { IO } {
  let normalized = normalizeTagList(rawTags);

  if normalized == []:
    Result.Ok([])
  else:
    match loadTags(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok current -> {
        let merged = mergeTagSets(current, normalized);

        match saveTags(scope, merged) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok _ -> Result.Ok(normalized)
      }
}

@public
fun addGlobalTag(scope: Scope, rawTag: String): Result String String effects { IO } {
  match normalizeTagName(rawTag) with:
    | Option.None -> Result.Err("Tag cannot be empty")
    | Option.Some normalized ->
        match ensureGlobalTags(scope, [normalized]) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok _ -> Result.Ok(normalized)
}

@public
fun removeGlobalTag(scope: Scope, rawTag: String): Result String Unit effects { IO } {
  match normalizeTagName(rawTag) with:
    | Option.None -> Result.Err("Tag cannot be empty")
    | Option.Some normalized -> removeGlobalTagNormalized(scope, normalized)
}

fun removeGlobalTagNormalized(scope: Scope, tag: String): Result String Unit effects { IO } {
  match loadTags(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tags -> {
      let normalizedTags = normalizeTagList(tags);

      if !containsTag(normalizedTags, tag):
        Result.Err(`Tag not found: ${tag}`)
      else:
        let nextTags = removeTagFromList(normalizedTags, tag, []);

        match removeTagFromTasks(scope, tag) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok _ -> saveTags(scope, nextTags)
    }
}

@public
fun renameGlobalTag(scope: Scope, fromRaw: String, toRaw: String): Result String String effects { IO } {
  match normalizeTagName(fromRaw) with:
    | Option.None -> Result.Err("Source tag cannot be empty")
    | Option.Some fromTag -> match normalizeTagName(toRaw) with:
      | Option.None -> Result.Err("Target tag cannot be empty")
      | Option.Some toTag -> renameGlobalTagNormalized(scope, fromTag, toTag)
}

fun renameGlobalTagNormalized(scope: Scope, fromTag: String, toTag: String): Result String String effects { IO } {
  if fromTag == toTag:
    Result.Ok(toTag)
  else:
    match loadTags(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok tags -> {
        let normalizedTags = normalizeTagList(tags);

        if !containsTag(normalizedTags, fromTag):
          Result.Err(`Tag not found: ${fromTag}`)
        else:
          let removed = removeTagFromList(normalizedTags, fromTag, []);
          let nextTags = mergeTagSets(removed, [toTag]);

          match renameTagInTasks(scope, fromTag, toTag) with:
            | Result.Err e -> Result.Err(e)
            | Result.Ok _ -> persistRenamedTag(scope, nextTags, toTag)
      }
}

fun persistRenamedTag(scope: Scope, nextTags: List String, toTag: String): Result String String effects { IO } {
  match saveTags(scope, nextTags) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(toTag)
}

fun removeTagFromTasks(scope: Scope, tag: String): Result String Unit effects { IO } {
  match loadTasks(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks -> {
      let (updatedTasks, changed) = removeTagFromTaskList(tasks, tag, [], false);

      if changed:
        saveTasks(scope, updatedTasks)
      else:
        Result.Ok(())
    }
}

fun removeTagFromTaskList(
  tasks: List Task,
  tag: String,
  acc: List Task,
  changed: Bool
): (List Task, Bool) {
  match tasks with:
    | [] -> (acc, changed)
    | [task, ...rest] -> {
      let current = normalizeTagList(task.tags);
      let nextTags = removeTagFromList(current, tag, []);
      let taskChanged = length(nextTags) != length(current);
      let nextTask = if taskChanged:
        { ...task, tags: nextTags, updatedAt: date() }
      else:
        { ...task, tags: current };

      removeTagFromTaskList(rest, tag, acc & [nextTask], changed or taskChanged)
    }
}

fun renameTagInTasks(scope: Scope, fromTag: String, toTag: String): Result String Unit effects { IO } {
  match loadTasks(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks -> {
      let (updatedTasks, changed) = renameTagInTaskList(tasks, fromTag, toTag, [], false);

      if changed:
        saveTasks(scope, updatedTasks)
      else:
        Result.Ok(())
    }
}

fun renameTagInTaskList(
  tasks: List Task,
  fromTag: String,
  toTag: String,
  acc: List Task,
  changed: Bool
): (List Task, Bool) {
  match tasks with:
    | [] -> (acc, changed)
    | [task, ...rest] -> {
      let current = normalizeTagList(task.tags);
      let renamed = uniq(replaceTag(current, fromTag, toTag, []));
      let taskChanged = !sameTags(current, renamed);
      let nextTask = if taskChanged:
        { ...task, tags: renamed, updatedAt: date() }
      else:
        { ...task, tags: current };

      renameTagInTaskList(rest, fromTag, toTag, acc & [nextTask], changed or taskChanged)
    }
}

fun replaceTag(tags: List String, fromTag: String, toTag: String, acc: List String): List String {
  match tags with:
    | [] -> acc
    | [tag, ...rest] ->
        let next = if tag == fromTag: toTag else: tag;
        replaceTag(rest, fromTag, toTag, acc & [next])
}

fun sameTags(left: List String, right: List String): Bool {
  match (left, right) with:
    | ([], []) -> true
    | ([l, ...lrest], [r, ...rrest]) -> l == r and sameTags(lrest, rrest)
    | _ -> false
}

fun removeTagFromList(tags: List String, tag: String, acc: List String): List String {
  match tags with:
    | [] -> acc
    | [current, ...rest] ->
        let nextAcc = if current == tag: acc else: acc & [current];
        removeTagFromList(rest, tag, nextAcc)
}

fun containsTag(tags: List String, tag: String): Bool {
  match tags with:
    | [] -> false
    | [current, ...rest] -> if current == tag: true else: containsTag(rest, tag)
}

fun normalizeTagList(tags: List String): List String {
  uniq(filterMap(tags, normalizeTagName))
}

fun mergeTagSets(left: List String, right: List String): List String {
  sortTags(uniq(normalizeTagList(left) & normalizeTagList(right)))
}

fun sortTags(tags: List String): List String {
  sort(tags, (left, right) => {
    if left < right:
      -1
    elif left > right:
      1
    else:
      0
  })
}
