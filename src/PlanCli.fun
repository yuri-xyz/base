from @std/Output import { line }
from @std/List import { length, filter }
from @std/String import { parseIntOr, trim }
from "./Models" import { Scope, Plan, PlanPatch, PlanItem, PlanItemPatch }
from "./Plans" import {
  listPlans,
  getPlan,
  createPlan,
  updatePlan,
  markPlanActive,
  markPlanDone,
  removePlan,
  addPlanItem,
  updatePlanItem,
  markPlanItemDone,
  markPlanItemInProgress,
  movePlanItem,
  removePlanItem
}
from "./Util" import { findOptionValue, hasFlag, normalizePlanStatus, normalizeStatus }

@public
fun runPlanCommand(scope: Scope, rest: List String): Result String Unit effects { IO } {
  match rest with:
    | [] -> runPlanList(scope, [])
    | ["list", ...opts] -> runPlanList(scope, opts)
    | ["create", title, ...opts] -> runPlanCreate(scope, title, opts)
    | ["show", planId, ..._opts] -> runPlanShow(scope, planId)
    | ["update", planId, ...opts] -> runPlanUpdate(scope, planId, opts)
    | ["active", planId, ..._opts] -> runPlanActive(scope, planId)
    | ["done", planId, ..._opts] -> runPlanDone(scope, planId)
    | ["remove", planId, ..._opts] -> runPlanRemove(scope, planId)
    | ["add-item", planId, title, ...opts] -> runPlanAddItem(scope, planId, title, opts)
    | ["update-item", planId, itemId, ...opts] -> runPlanUpdateItem(scope, planId, itemId, opts)
    | ["progress-item", planId, itemId, ..._opts] -> runPlanProgressItem(scope, planId, itemId)
    | ["done-item", planId, itemId, ..._opts] -> runPlanDoneItem(scope, planId, itemId)
    | ["move-item", planId, itemId, positionText, ..._opts] -> runPlanMoveItem(scope, planId, itemId, positionText)
    | ["remove-item", planId, itemId, ..._opts] -> runPlanRemoveItem(scope, planId, itemId)
    | _ -> Result.Err(planUsage())
}

@public
fun planUsage(): String {
  "Usage: base plan <list|create|show|update|active|done|remove|add-item|update-item|progress-item|done-item|move-item|remove-item> ..."
}

fun runPlanList(scope: Scope, opts: List String): Result String Unit effects { IO } {
  let includeDone = hasFlag(opts, "--all", "--all");
  let title = if includeDone: "All plans" else: "Plans";

  match listPlans(scope, includeDone) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans ->
        printPlanList(plans, title);
        Result.Ok(())
}

fun runPlanCreate(scope: Scope, title: String, opts: List String): Result String Unit effects { IO } {
  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");

  match createPlan(scope, title, description) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line("Plan created:");
        printPlan(plan);
        Result.Ok(())
}

fun runPlanShow(scope: Scope, planId: String): Result String Unit effects { IO } {
  match getPlan(scope, planId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        printPlan(plan);
        Result.Ok(())
}

fun runPlanUpdate(scope: Scope, planId: String, opts: List String): Result String Unit effects { IO } {
  let titleOpt = mapOption(findOptionValue(opts, "--title", "--title"), trim);
  let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
  let statusRawOpt = findOptionValue(opts, "--status", "--status");
  let statusOptResult = normalizePlanStatusOption(statusRawOpt);

  match statusOptResult with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt -> if isNone(titleOpt) and isNone(descriptionOpt) and isNone(statusOpt):
      Result.Err("No updates provided. Use --title/--description/--status")
    else:
      let patch: PlanPatch = {
        title: titleOpt,
        description: descriptionOpt,
        status: statusOpt,
      };

      match updatePlan(scope, planId, patch) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok plan ->
            line("Plan updated:");
            printPlan(plan);
            Result.Ok(())
}

fun runPlanActive(scope: Scope, planId: String): Result String Unit effects { IO } {
  match markPlanActive(scope, planId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line("Plan marked active:");
        printPlan(plan);
        Result.Ok(())
}

fun runPlanDone(scope: Scope, planId: String): Result String Unit effects { IO } {
  match markPlanDone(scope, planId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line("Plan completed:");
        printPlan(plan);
        Result.Ok(())
}

fun runPlanRemove(scope: Scope, planId: String): Result String Unit effects { IO } {
  match removePlan(scope, planId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ ->
        line(`Removed plan ${planId}`);
        Result.Ok(())
}

fun runPlanAddItem(
  scope: Scope,
  planId: String,
  title: String,
  opts: List String
): Result String Unit effects { IO } {
  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");

  match addPlanItem(scope, planId, title, description) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok item ->
        line("Plan item created:");
        printPlanItem(item);
        Result.Ok(())
}

fun runPlanUpdateItem(
  scope: Scope,
  planId: String,
  itemId: String,
  opts: List String
): Result String Unit effects { IO } {
  let titleOpt = mapOption(findOptionValue(opts, "--title", "--title"), trim);
  let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
  let statusRawOpt = findOptionValue(opts, "--status", "--status");
  let statusOptResult = normalizePlanItemStatusOption(statusRawOpt);

  match statusOptResult with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt -> if isNone(titleOpt) and isNone(descriptionOpt) and isNone(statusOpt):
      Result.Err("No updates provided. Use --title/--description/--status")
    else:
      let patch: PlanItemPatch = {
        title: titleOpt,
        description: descriptionOpt,
        status: statusOpt,
      };

      match updatePlanItem(scope, planId, itemId, patch) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok item ->
            line("Plan item updated:");
            printPlanItem(item);
            Result.Ok(())
}

fun runPlanProgressItem(scope: Scope, planId: String, itemId: String): Result String Unit effects { IO } {
  match markPlanItemInProgress(scope, planId, itemId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok item ->
        line("Plan item marked in progress:");
        printPlanItem(item);
        Result.Ok(())
}

fun runPlanDoneItem(scope: Scope, planId: String, itemId: String): Result String Unit effects { IO } {
  match markPlanItemDone(scope, planId, itemId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok item ->
        line("Plan item completed:");
        printPlanItem(item);
        Result.Ok(())
}

fun runPlanMoveItem(
  scope: Scope,
  planId: String,
  itemId: String,
  positionText: String
): Result String Unit effects { IO } {
  let position = max(1, parseIntOr(positionText, 1));
  let positionDisplay = show(position);

  match movePlanItem(scope, planId, itemId, position) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line(`Moved plan item ${itemId} to position ${positionDisplay}`);
        printPlan(plan);
        Result.Ok(())
}

fun runPlanRemoveItem(scope: Scope, planId: String, itemId: String): Result String Unit effects { IO } {
  match removePlanItem(scope, planId, itemId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line(`Removed plan item ${itemId}`);
        printPlan(plan);
        Result.Ok(())
}

fun normalizePlanStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizePlanStatus(raw) with:
      | Option.None -> Result.Err(`Invalid plan status: ${raw}. Use planned | active | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}

fun normalizePlanItemStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizeStatus(raw) with:
      | Option.None -> Result.Err(`Invalid plan item status: ${raw}. Use todo | in_progress | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}

fun printPlanList(plans: List Plan, title: String): Unit effects { IO } {
  line(title);

  match plans with:
    | [] -> line("  (none)")
    | _ -> printPlanListItems(plans)
}

fun printPlanListItems(plans: List Plan): Unit effects { IO } {
  match plans with:
    | [] -> ()
    | [plan, ...rest] -> {
        printPlanSummary(plan);
        printPlanListItems(rest)
      }
}

fun printPlanSummary(plan: Plan): Unit effects { IO } {
  let doneCount = length(filter(plan.items, (item) => { item.status == "done" }));
  let totalCount = length(plan.items);
  let doneCountText = show(doneCount);
  let totalCountText = show(totalCount);

  line(`[${plan.id}] [${plan.status}] ${plan.title}`);
  line(`   items: ${doneCountText}/${totalCountText} done`)
}

fun printPlan(plan: Plan): Unit effects { IO } {
  line(`[${plan.id}] [${plan.status}] ${plan.title}`);

  if plan.description == "":
    ()
  else:
    line(`  note: ${plan.description}`);

  if plan.status == "done":
    let completed = completedText(plan.completedAt);
    line(`  completed: ${completed}`)
  else:
    ();

  line("  items");

  match plan.items with:
    | [] -> line("    (none)")
    | _ -> printPlanItems(plan.items)
}

fun printPlanItems(items: List PlanItem): Unit effects { IO } {
  match items with:
    | [] -> ()
    | [item, ...rest] -> {
        printPlanItem(item);
        printPlanItems(rest)
      }
}

fun printPlanItem(item: PlanItem): Unit effects { IO } {
  let orderText = show(item.order);
  line(`    ${orderText}. [${item.status}] ${item.title}`);
  line(`       id: ${item.id}`);

  if item.description == "":
    ()
  else:
    line(`       note: ${item.description}`);

  if item.status == "done":
    let completed = completedText(item.completedAt);
    line(`       completed: ${completed}`)
  else:
    ()
}

fun completedText(completedAt: Option String): String {
  match completedAt with:
    | Option.None -> "unknown"
    | Option.Some at -> at
}

fun max(a: Int, b: Int): Int {
  if a > b: a else: b
}
