from @std/Crypto import { randomUUID }
from @std/List import { filter, sort, length }
from @std/String import { trim }
from @std/Time import { date }
from "./Models" import { Scope, Plan, PlanPatch, PlanItem, PlanItemPatch }
from "./Store" import { loadPlans, savePlans }

@public
fun listPlans(scope: Scope, includeDone: Bool): Result String (List Plan) effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans ->
        let visible = if includeDone: plans else: filter(plans, (plan) => { plan.status != "done" });

        Result.Ok(sortPlansByRecent(visible))
}

@public
fun getPlan(scope: Scope, planId: String): Result String Plan effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> findPlan(plans, planId)
}

fun findPlan(plans: List Plan, planId: String): Result String Plan {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId:
      Result.Ok(plan)
    else:
      findPlan(rest, planId)
}

@public
fun createPlan(scope: Scope, titleRaw: String, descriptionRaw: String): Result String Plan effects { IO } {
  let title = trim(titleRaw);
  let description = trim(descriptionRaw);

  if title == "":
    Result.Err("Plan title cannot be empty")
  else:
    match loadPlans(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok plans -> createLoadedPlan(scope, plans, title, description)
}

fun createLoadedPlan(
  scope: Scope,
  plans: List Plan,
  title: String,
  description: String
): Result String Plan effects { IO } {
  let now = date();
  let next: Plan = {
    id: randomUUID(),
    title,
    description,
    status: "planned",
    completedAt: Option.None,
    items: [],
    createdAt: now,
    updatedAt: now,
  };

  match savePlans(scope, plans & [next]) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(next)
}

@public
fun updatePlan(scope: Scope, planId: String, patch: PlanPatch): Result String Plan effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> updateLoadedPlan(scope, plans, planId, patch)
}

fun updateLoadedPlan(
  scope: Scope,
  plans: List Plan,
  planId: String,
  patch: PlanPatch
): Result String Plan effects { IO } {
  match patchPlan(plans, planId, patch, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (updated, nextPlans) ->
        match savePlans(scope, nextPlans) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok _ -> Result.Ok(updated)
}

fun patchPlan(
  plans: List Plan,
  planId: String,
  patch: PlanPatch,
  acc: List Plan
): Result String (Plan, List Plan) {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId:
      let next = mergePlanPatch(plan, patch);
      Result.Ok((next, acc & [next] & rest))
    else:
      patchPlan(rest, planId, patch, acc & [plan])
}

fun mergePlanPatch(plan: Plan, patch: PlanPatch): Plan {
  let nextTitle = getOrElse(patch.title, plan.title);
  let nextDescription = getOrElse(patch.description, plan.description);
  let rawStatus = getOrElse(patch.status, plan.status);
  let nextStatus = if rawStatus == "done":
    "done"
  elif rawStatus == "active":
    "active"
  else:
    "planned";
  let nextCompletedAt = resolvePlanCompletedAt(plan.completedAt, nextStatus);

  {
    ...plan,
    title: nextTitle,
    description: nextDescription,
    status: nextStatus,
    completedAt: nextCompletedAt,
    updatedAt: date(),
  }
}

fun resolvePlanCompletedAt(current: Option String, status: String): Option String {
  if status == "done":
    match current with:
      | Option.Some at -> Option.Some(at)
      | Option.None -> Option.Some(date())
  else:
    Option.None
}

@public
fun markPlanActive(scope: Scope, planId: String): Result String Plan effects { IO } {
  let patch: PlanPatch = {
    title: Option.None,
    description: Option.None,
    status: Option.Some("active"),
  };

  updatePlan(scope, planId, patch)
}

@public
fun markPlanDone(scope: Scope, planId: String): Result String Plan effects { IO } {
  let patch: PlanPatch = {
    title: Option.None,
    description: Option.None,
    status: Option.Some("done"),
  };

  updatePlan(scope, planId, patch)
}

@public
fun removePlan(scope: Scope, planId: String): Result String Unit effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans ->
        let remaining = filter(plans, (plan) => { plan.id != planId });

        if length(remaining) == length(plans):
          Result.Err(`Plan not found: ${planId}`)
        else:
          savePlans(scope, remaining)
}

@public
fun addPlanItem(
  scope: Scope,
  planId: String,
  titleRaw: String,
  descriptionRaw: String
): Result String PlanItem effects { IO } {
  let title = trim(titleRaw);
  let description = trim(descriptionRaw);

  if title == "":
    Result.Err("Plan item title cannot be empty")
  else:
    match loadPlans(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok plans -> addPlanItemInPlans(scope, plans, planId, title, description, [])
}

fun addPlanItemInPlans(
  scope: Scope,
  plans: List Plan,
  planId: String,
  title: String,
  description: String,
  acc: List Plan
): Result String PlanItem effects { IO } {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId: {
      let orderedItems = sortPlanItemsByOrder(plan.items);
      let now = date();
      let nextItem: PlanItem = {
        id: randomUUID(),
        title,
        description,
        status: "todo",
        order: length(orderedItems) + 1,
        completedAt: Option.None,
        createdAt: now,
        updatedAt: now,
      };
      let nextPlan = {
        ...plan,
        items: orderedItems & [nextItem],
        updatedAt: now,
      };
      let nextPlans = acc & [nextPlan] & rest;

      match savePlans(scope, nextPlans) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok _ -> Result.Ok(nextItem)
    }
    else:
      addPlanItemInPlans(scope, rest, planId, title, description, acc & [plan])
}

@public
fun updatePlanItem(
  scope: Scope,
  planId: String,
  itemId: String,
  patch: PlanItemPatch
): Result String PlanItem effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> updatePlanItemInPlans(scope, plans, planId, itemId, patch, [])
}

fun updatePlanItemInPlans(
  scope: Scope,
  plans: List Plan,
  planId: String,
  itemId: String,
  patch: PlanItemPatch,
  acc: List Plan
): Result String PlanItem effects { IO } {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId:
      updatePlanItemInPlan(scope, plan, rest, itemId, patch, acc)
    else:
      updatePlanItemInPlans(scope, rest, planId, itemId, patch, acc & [plan])
}

fun updatePlanItemInPlan(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  itemId: String,
  patch: PlanItemPatch,
  acc: List Plan
): Result String PlanItem effects { IO } {
  match patchPlanItem(plan.items, itemId, patch, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (updatedItem, nextItems) ->
        persistUpdatedPlanItem(scope, plan, rest, acc, updatedItem, nextItems)
}

fun persistUpdatedPlanItem(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  acc: List Plan,
  updatedItem: PlanItem,
  nextItems: List PlanItem
): Result String PlanItem effects { IO } {
  let nextPlan = {
    ...plan,
    items: sortPlanItemsByOrder(nextItems),
    updatedAt: date(),
  };
  let nextPlans = acc & [nextPlan] & rest;

  match savePlans(scope, nextPlans) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(updatedItem)
}

fun patchPlanItem(
  items: List PlanItem,
  itemId: String,
  patch: PlanItemPatch,
  acc: List PlanItem
): Result String (PlanItem, List PlanItem) {
  match items with:
    | [] -> Result.Err(`Plan item not found: ${itemId}`)
    | [item, ...rest] -> if item.id == itemId:
      let nextItem = mergePlanItemPatch(item, patch);
      Result.Ok((nextItem, acc & [nextItem] & rest))
    else:
      patchPlanItem(rest, itemId, patch, acc & [item])
}

fun mergePlanItemPatch(item: PlanItem, patch: PlanItemPatch): PlanItem {
  let nextTitle = getOrElse(patch.title, item.title);
  let nextDescription = getOrElse(patch.description, item.description);
  let rawStatus = getOrElse(patch.status, item.status);
  let nextStatus = if rawStatus == "done":
    "done"
  elif rawStatus == "in_progress":
    "in_progress"
  else:
    "todo";
  let nextCompletedAt = resolvePlanItemCompletedAt(item.completedAt, nextStatus);

  {
    ...item,
    title: nextTitle,
    description: nextDescription,
    status: nextStatus,
    completedAt: nextCompletedAt,
    updatedAt: date(),
  }
}

fun resolvePlanItemCompletedAt(current: Option String, status: String): Option String {
  if status == "done":
    match current with:
      | Option.Some at -> Option.Some(at)
      | Option.None -> Option.Some(date())
  else:
    Option.None
}

@public
fun markPlanItemDone(scope: Scope, planId: String, itemId: String): Result String PlanItem effects { IO } {
  let patch: PlanItemPatch = {
    title: Option.None,
    description: Option.None,
    status: Option.Some("done"),
  };

  updatePlanItem(scope, planId, itemId, patch)
}

@public
fun markPlanItemInProgress(
  scope: Scope,
  planId: String,
  itemId: String
): Result String PlanItem effects { IO } {
  let patch: PlanItemPatch = {
    title: Option.None,
    description: Option.None,
    status: Option.Some("in_progress"),
  };

  updatePlanItem(scope, planId, itemId, patch)
}

@public
fun movePlanItem(
  scope: Scope,
  planId: String,
  itemId: String,
  newPositionRaw: Int
): Result String Plan effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> movePlanItemInPlans(scope, plans, planId, itemId, newPositionRaw, [])
}

fun movePlanItemInPlans(
  scope: Scope,
  plans: List Plan,
  planId: String,
  itemId: String,
  newPositionRaw: Int,
  acc: List Plan
): Result String Plan effects { IO } {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId:
      movePlanItemInPlan(scope, plan, rest, itemId, newPositionRaw, acc)
    else:
      movePlanItemInPlans(scope, rest, planId, itemId, newPositionRaw, acc & [plan])
}

fun movePlanItemInPlan(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  itemId: String,
  newPositionRaw: Int,
  acc: List Plan
): Result String Plan effects { IO } {
  match splitOutPlanItem(sortPlanItemsByOrder(plan.items), itemId, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (target, remaining) ->
        persistMovedPlanItem(scope, plan, rest, acc, (target, remaining), newPositionRaw)
}

fun persistMovedPlanItem(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  acc: List Plan,
  split: (PlanItem, List PlanItem),
  newPositionRaw: Int
): Result String Plan effects { IO } {
  let (target, remaining) = split;
  let maxPosition = length(remaining) + 1;
  let bounded = clampPosition(newPositionRaw, maxPosition);
  let inserted = insertPlanItemAt(remaining, bounded - 1, target, []);
  let renumbered = renumberPlanItems(inserted, 1, []);
  let nextPlan = {
    ...plan,
    items: renumbered,
    updatedAt: date(),
  };
  let nextPlans = acc & [nextPlan] & rest;

  match savePlans(scope, nextPlans) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(nextPlan)
}

fun splitOutPlanItem(
  items: List PlanItem,
  itemId: String,
  acc: List PlanItem
): Result String (PlanItem, List PlanItem) {
  match items with:
    | [] -> Result.Err(`Plan item not found: ${itemId}`)
    | [item, ...rest] -> if item.id == itemId:
      Result.Ok((item, acc & rest))
    else:
      splitOutPlanItem(rest, itemId, acc & [item])
}

fun insertPlanItemAt(
  items: List PlanItem,
  index: Int,
  target: PlanItem,
  acc: List PlanItem
): List PlanItem {
  if index <= 0:
    acc & [target] & items
  else:
    match items with:
      | [] -> acc & [target]
      | [item, ...rest] -> insertPlanItemAt(rest, index - 1, target, acc & [item])
}

fun renumberPlanItems(items: List PlanItem, nextOrder: Int, acc: List PlanItem): List PlanItem {
  match items with:
    | [] -> acc
    | [item, ...rest] ->
        let updated = { ...item, order: nextOrder, updatedAt: date() };
        renumberPlanItems(rest, nextOrder + 1, acc & [updated])
}

@public
fun removePlanItem(scope: Scope, planId: String, itemId: String): Result String Plan effects { IO } {
  match loadPlans(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> removePlanItemInPlans(scope, plans, planId, itemId, [])
}

fun removePlanItemInPlans(
  scope: Scope,
  plans: List Plan,
  planId: String,
  itemId: String,
  acc: List Plan
): Result String Plan effects { IO } {
  match plans with:
    | [] -> Result.Err(`Plan not found: ${planId}`)
    | [plan, ...rest] -> if plan.id == planId:
      removePlanItemInPlan(scope, plan, rest, itemId, acc)
    else:
      removePlanItemInPlans(scope, rest, planId, itemId, acc & [plan])
}

fun removePlanItemInPlan(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  itemId: String,
  acc: List Plan
): Result String Plan effects { IO } {
  match removePlanItemById(sortPlanItemsByOrder(plan.items), itemId, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok remaining -> persistRemovedPlanItem(scope, plan, rest, acc, remaining)
}

fun persistRemovedPlanItem(
  scope: Scope,
  plan: Plan,
  rest: List Plan,
  acc: List Plan,
  remaining: List PlanItem
): Result String Plan effects { IO } {
  let nextPlan = {
    ...plan,
    items: renumberPlanItems(remaining, 1, []),
    updatedAt: date(),
  };
  let nextPlans = acc & [nextPlan] & rest;

  match savePlans(scope, nextPlans) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(nextPlan)
}

fun removePlanItemById(
  items: List PlanItem,
  itemId: String,
  acc: List PlanItem
): Result String (List PlanItem) {
  match items with:
    | [] -> Result.Err(`Plan item not found: ${itemId}`)
    | [item, ...rest] -> if item.id == itemId:
      Result.Ok(acc & rest)
    else:
      removePlanItemById(rest, itemId, acc & [item])
}

fun clampPosition(position: Int, maxPosition: Int): Int {
  if position < 1:
    1
  elif position > maxPosition:
    maxPosition
  else:
    position
}

fun sortPlansByRecent(plans: List Plan): List Plan {
  sort(plans, (left, right) => {
    if left.updatedAt > right.updatedAt:
      -1
    elif left.updatedAt < right.updatedAt:
      1
    else:
      0
  })
}

fun sortPlanItemsByOrder(items: List PlanItem): List PlanItem {
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
