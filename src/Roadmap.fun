from @std/Crypto import { randomUUID }
from @std/List import { sort, length }
from @std/String import { trim }
from @std/Time import { date }
from "./Models" import { Scope, RoadmapItem, RoadmapPatch }
from "./Store" import { loadRoadmap, saveRoadmap }

@public
fun listRoadmap(scope: Scope): Result String (List RoadmapItem) effects { IO } {
  match loadRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok items -> Result.Ok(sortByOrder(items))
}

@public
fun addRoadmapItem(
  scope: Scope,
  goalRaw: String,
  descriptionRaw: String
): Result String RoadmapItem effects { IO } {
  let goal = trim(goalRaw);
  let description = trim(descriptionRaw);

  if goal == "":
    Result.Err("Roadmap goal cannot be empty")
  else:
    match loadRoadmap(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok items -> addLoadedRoadmapItem(scope, items, goal, description)
}

fun addLoadedRoadmapItem(
  scope: Scope,
  items: List RoadmapItem,
  goal: String,
  description: String
): Result String RoadmapItem effects { IO } {
  let now = date();
  let next: RoadmapItem = {
    id: randomUUID(),
    goal,
    description,
    status: "planned",
    order: length(items) + 1,
    completedAt: Option.None,
    createdAt: now,
    updatedAt: now,
  };

  let saved = sortByOrder(items & [next]);

  match saveRoadmap(scope, saved) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(next)
}

@public
fun updateRoadmapItem(
  scope: Scope,
  itemId: String,
  patch: RoadmapPatch
): Result String RoadmapItem effects { IO } {
  match loadRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok items -> updateLoadedRoadmapItem(scope, items, itemId, patch)
}

fun updateLoadedRoadmapItem(
  scope: Scope,
  items: List RoadmapItem,
  itemId: String,
  patch: RoadmapPatch
): Result String RoadmapItem effects { IO } {
  match patchRoadmap(items, itemId, patch, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (updated, next) -> persistUpdatedRoadmap(scope, updated, next)
}

fun persistUpdatedRoadmap(
  scope: Scope,
  updated: RoadmapItem,
  items: List RoadmapItem
): Result String RoadmapItem effects { IO } {
  match saveRoadmap(scope, sortByOrder(items)) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(updated)
}

fun patchRoadmap(
  items: List RoadmapItem,
  itemId: String,
  patch: RoadmapPatch,
  acc: List RoadmapItem
): Result String (RoadmapItem, List RoadmapItem) {
  match items with:
    | [] -> Result.Err("Roadmap item not found: ${itemId}")
    | [item, ...rest] -> if item.id == itemId:
      let next = mergeRoadmapPatch(item, patch);
      Result.Ok((next, acc & [next] & rest))
    else:
      patchRoadmap(rest, itemId, patch, acc & [item])
}

fun mergeRoadmapPatch(item: RoadmapItem, patch: RoadmapPatch): RoadmapItem {
  let goal = getOrElse(patch.goal, item.goal);
  let description = getOrElse(patch.description, item.description);
  let rawStatus = getOrElse(patch.status, item.status);
  let normalizedStatus = if rawStatus == "done":
    "done"
  elif rawStatus == "active":
    "active"
  else:
    "planned";
  let completedAt = resolveCompletedAt(item.completedAt, normalizedStatus);
  let base = {
    ...item,
    goal,
    description,
    status: normalizedStatus,
    completedAt,
    updatedAt: date(),
  };

  base
}

fun resolveCompletedAt(current: Option String, status: String): Option String {
  if status == "done":
    match current with:
      | Option.Some at -> Option.Some(at)
      | Option.None -> Option.Some(date())
  else:
    Option.None
}

@public
fun moveRoadmapItem(
  scope: Scope,
  itemId: String,
  newPositionRaw: Int
): Result String (List RoadmapItem) effects { IO } {
  match loadRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok items -> moveLoadedRoadmapItem(scope, items, itemId, newPositionRaw)
}

fun moveLoadedRoadmapItem(
  scope: Scope,
  items: List RoadmapItem,
  itemId: String,
  newPositionRaw: Int
): Result String (List RoadmapItem) effects { IO } {
  let ordered = sortByOrder(items);

  match splitOutItem(ordered, itemId, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (target, remaining) -> {
      let maxPosition = length(remaining) + 1;
      let bounded = clampPosition(newPositionRaw, maxPosition);
      let inserted = insertAt(remaining, bounded - 1, target, []);
      let renumbered = renumber(inserted, 1, []);

      match saveRoadmap(scope, renumbered) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok _ -> Result.Ok(renumbered)
    }
}

fun splitOutItem(
  items: List RoadmapItem,
  itemId: String,
  acc: List RoadmapItem
): Result String (RoadmapItem, List RoadmapItem) {
  match items with:
    | [] -> Result.Err("Roadmap item not found: ${itemId}")
    | [item, ...rest] -> if item.id == itemId:
      Result.Ok((item, acc & rest))
    else:
      splitOutItem(rest, itemId, acc & [item])
}

fun insertAt(
  items: List RoadmapItem,
  index: Int,
  target: RoadmapItem,
  acc: List RoadmapItem
): List RoadmapItem {
  if index <= 0:
    acc & [target] & items
  else:
    match items with:
      | [] -> acc & [target]
      | [item, ...rest] -> insertAt(rest, index - 1, target, acc & [item])
}

fun renumber(
  items: List RoadmapItem,
  nextOrder: Int,
  acc: List RoadmapItem
): List RoadmapItem {
  match items with:
    | [] -> acc
    | [item, ...rest] ->
        let updated = { ...item, order: nextOrder, updatedAt: date() };
        renumber(rest, nextOrder + 1, acc & [updated])
}

@public
fun markRoadmapDone(scope: Scope, itemId: String): Result String RoadmapItem effects { IO } {
  let patch: RoadmapPatch = {
    goal: Option.None,
    description: Option.None,
    status: Option.Some("done"),
  };

  updateRoadmapItem(scope, itemId, patch)
}

@public
fun markRoadmapActive(scope: Scope, itemId: String): Result String RoadmapItem effects { IO } {
  let patch: RoadmapPatch = {
    goal: Option.None,
    description: Option.None,
    status: Option.Some("active"),
  };

  updateRoadmapItem(scope, itemId, patch)
}

@public
fun removeRoadmapItem(scope: Scope, itemId: String): Result String Unit effects { IO } {
  match loadRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok items -> removeLoadedRoadmapItem(scope, items, itemId)
}

fun removeLoadedRoadmapItem(
  scope: Scope,
  items: List RoadmapItem,
  itemId: String
): Result String Unit effects { IO } {
  match removeById(items, itemId, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok remaining -> {
      let renumbered = renumber(remaining, 1, []);

      saveRoadmap(scope, renumbered)
    }
}

fun removeById(
  items: List RoadmapItem,
  itemId: String,
  acc: List RoadmapItem
): Result String (List RoadmapItem) {
  match items with:
    | [] -> Result.Err("Roadmap item not found: ${itemId}")
    | [item, ...rest] -> if item.id == itemId:
      Result.Ok(acc & rest)
    else:
      removeById(rest, itemId, acc & [item])
}

fun clampPosition(position: Int, maxPosition: Int): Int {
  if position < 1:
    1
  elif position > maxPosition:
    maxPosition
  else:
    position
}

fun sortByOrder(items: List RoadmapItem): List RoadmapItem {
  sort(items, (left, right) => {
    if left.order < right.order:
      -1
    elif left.order > right.order:
      1
    elif left.updatedAt > right.updatedAt:
      -1
    elif left.updatedAt < right.updatedAt:
      1
    else:
      0
  })
}
