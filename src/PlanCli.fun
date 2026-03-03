from @std/Output import { line }
from @std/List import { length, filter }
from @std/String import { parseIntOr, trim }
from "./Models" import { Scope, Plan, PlanPatch, PlanItem, PlanItemPatch }
from "./Plans" import {
  listPlans,
  getPlan,
  createPlan,
  updatePlan,
  removePlan,
  addPlanItem,
  updatePlanItem,
  movePlanItem,
  removePlanItem
}
from "./Util" import {
  CliOptionSpec,
  findOptionValue,
  hasFlag,
  hasHelpFlag,
  normalizePlanStatus,
  normalizeStatus,
  validateOptions
}

@public
fun runPlanCommand(scope: Scope, rest: List String): Result String Unit effects { IO } {
  match rest with:
    | [] -> runPlanList(scope, [])
    | ["help"] -> showPlanHelp()
    | ["-h"] -> showPlanHelp()
    | ["--help"] -> showPlanHelp()
    | ["help", command] -> showPlanCommandHelp(command)
    | [command, ...args] -> runPlanCommandWithArgs(scope, command, args)
}

@public
fun planUsage(): String {
  "Usage: base plan <list|create|show|set-status|update|remove|add-item|update-item|set-item-status|move-item|remove-item> ..."
}

fun runPlanCommandWithArgs(
  scope: Scope,
  command: String,
  args: List String
): Result String Unit effects { IO } {
  if hasHelpFlag(args):
    showPlanCommandHelp(command)
  else:
    match (command, args) with:
      | ("list", opts) -> runPlanList(scope, opts)
      | ("create", [title, ...opts]) -> runPlanCreate(scope, title, opts)
      | ("show", [planId]) -> runPlanShow(scope, planId)
      | ("set-status", [planId, statusRaw]) -> runPlanSetStatus(scope, planId, statusRaw)
      | ("update", [planId, ...opts]) -> runPlanUpdate(scope, planId, opts)
      | ("remove", [planId]) -> runPlanRemove(scope, planId)
      | ("add-item", [planId, title, ...opts]) -> runPlanAddItem(scope, planId, title, opts)
      | ("update-item", [planId, itemId, ...opts]) -> runPlanUpdateItem(scope, planId, itemId, opts)
      | ("set-item-status", [planId, itemId, statusRaw]) -> runPlanSetItemStatus(scope, planId, itemId, statusRaw)
      | ("move-item", [planId, itemId, positionText]) -> runPlanMoveItem(scope, planId, itemId, positionText)
      | ("remove-item", [planId, itemId]) -> runPlanRemoveItem(scope, planId, itemId)
      | _ -> Result.Err(planUsage())
}

fun showPlanHelp(): Result String Unit effects { IO } {
  printPlanHelp();
  Result.Ok(())
}

fun showPlanCommandHelp(command: String): Result String Unit effects { IO } {
  printPlanCommandHelp(command);
  Result.Ok(())
}

fun printPlanHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base plan list [--all]",
    "  base plan create <title> [-d|--description <text>] [--id <key>]",
    "  base plan show <planId>",
    "  base plan set-status <planId> <planned|active|done>",
    "  base plan update <planId> [--title <text>] [-d|--description <text>] [--status <planned|active|done>]",
    "  base plan remove <planId>",
    "  base plan add-item <planId> <title> [-d|--description <text>] [--id <key>]",
    "  base plan update-item <planId> <itemId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>]",
    "  base plan set-item-status <planId> <itemId> <todo|in_progress|done>",
    "  base plan move-item <planId> <itemId> <position>",
    "  base plan remove-item <planId> <itemId>",
  ])
}

fun printPlanCommandHelp(command: String): Unit effects { IO } {
  match command with:
    | "list" -> printLines([
      "Usage:",
      "  base plan list [--all]",
    ])
    | "create" -> printLines([
      "Usage:",
      "  base plan create <title> [-d|--description <text>] [--id <key>]",
    ])
    | "show" -> printLines([
      "Usage:",
      "  base plan show <planId>",
    ])
    | "set-status" -> printLines([
      "Usage:",
      "  base plan set-status <planId> <planned|active|done>",
    ])
    | "update" -> printLines([
      "Usage:",
      "  base plan update <planId> [--title <text>] [-d|--description <text>] [--status <planned|active|done>]",
    ])
    | "remove" -> printLines([
      "Usage:",
      "  base plan remove <planId>",
    ])
    | "add-item" -> printLines([
      "Usage:",
      "  base plan add-item <planId> <title> [-d|--description <text>] [--id <key>]",
    ])
    | "update-item" -> printLines([
      "Usage:",
      "  base plan update-item <planId> <itemId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>]",
    ])
    | "set-item-status" -> printLines([
      "Usage:",
      "  base plan set-item-status <planId> <itemId> <todo|in_progress|done>",
    ])
    | "move-item" -> printLines([
      "Usage:",
      "  base plan move-item <planId> <itemId> <position>",
    ])
    | "remove-item" -> printLines([
      "Usage:",
      "  base plan remove-item <planId> <itemId>",
    ])
    | _ -> printPlanHelp()
}

fun printLines(lines: List String): Unit effects { IO } {
  match lines with:
    | [] -> ()
    | [next, ...rest] -> {
        line(next);
        printLines(rest)
      }
}

fun runPlanList(scope: Scope, opts: List String): Result String Unit effects { IO } {
  match validateOptions(opts, planListOptionSpecs()) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      let includeDone = hasFlag(opts, "--all", "--all");
      let title = if includeDone: "All plans" else: "Plans";

      match listPlans(scope, includeDone) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok plans ->
            printPlanList(plans, title);
            Result.Ok(())
    }
}

fun runPlanCreate(scope: Scope, title: String, opts: List String): Result String Unit effects { IO } {
  match validateOptions(opts, planCreateOptionSpecs()) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");
      let idKeyOpt = findOptionValue(opts, "--id", "--id");

      match createPlan(scope, title, description, idKeyOpt) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok plan ->
            line("Plan created:");
            printPlan(plan);
            Result.Ok(())
    }
}

fun runPlanShow(scope: Scope, planId: String): Result String Unit effects { IO } {
  match getPlan(scope, planId) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        printPlan(plan);
        Result.Ok(())
}

fun runPlanUpdate(scope: Scope, planId: String, opts: List String): Result String Unit effects { IO } {
  match validateOptions(opts, planUpdateOptionSpecs()) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      let titleOpt = mapOption(findOptionValue(opts, "--title", "--title"), trim);
      let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
      let statusRawOpt = findOptionValue(opts, "--status", "--status");
      let statusOptResult = normalizePlanStatusOption(statusRawOpt);

      runPlanUpdateValidated(scope, planId, titleOpt, descriptionOpt, statusOptResult)
    }
}

fun runPlanUpdateValidated(
  scope: Scope,
  planId: String,
  titleOpt: Option String,
  descriptionOpt: Option String,
  statusOptResult: Result String (Option String)
): Result String Unit effects { IO } {
  match statusOptResult with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt ->
        if isNone(titleOpt) and isNone(descriptionOpt) and isNone(statusOpt):
          Result.Err("No updates provided. Use --title/--description/--status")
        else:
          persistPlanUpdate(scope, planId, {
            title: titleOpt,
            description: descriptionOpt,
            status: statusOpt,
          })
}

fun persistPlanUpdate(scope: Scope, planId: String, patch: PlanPatch): Result String Unit effects { IO } {
  match updatePlan(scope, planId, patch) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plan ->
        line("Plan updated:");
        printPlan(plan);
        Result.Ok(())
}

fun runPlanSetStatus(scope: Scope, planId: String, statusRaw: String): Result String Unit effects { IO } {
  match normalizePlanStatusOption(Option.Some(statusRaw)) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt ->
        let patch: PlanPatch = {
          title: Option.None,
          description: Option.None,
          status: statusOpt,
        };

        match updatePlan(scope, planId, patch) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok plan ->
              line("Plan updated:");
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
  match validateOptions(opts, planCreateOptionSpecs()) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");
      let idKeyOpt = findOptionValue(opts, "--id", "--id");

      match addPlanItem(scope, planId, title, description, idKeyOpt) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok item ->
            line("Plan item created:");
            printPlanItem(item);
            Result.Ok(())
    }
}

fun runPlanUpdateItem(
  scope: Scope,
  planId: String,
  itemId: String,
  opts: List String
): Result String Unit effects { IO } {
  match validateOptions(opts, planUpdateOptionSpecs()) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      let titleOpt = mapOption(findOptionValue(opts, "--title", "--title"), trim);
      let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
      let statusRawOpt = findOptionValue(opts, "--status", "--status");
      let statusOptResult = normalizePlanItemStatusOption(statusRawOpt);

      runPlanUpdateItemValidated(scope, planId, itemId, titleOpt, descriptionOpt, statusOptResult)
    }
}

fun runPlanUpdateItemValidated(
  scope: Scope,
  planId: String,
  itemId: String,
  titleOpt: Option String,
  descriptionOpt: Option String,
  statusOptResult: Result String (Option String)
): Result String Unit effects { IO } {
  match statusOptResult with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt ->
        if isNone(titleOpt) and isNone(descriptionOpt) and isNone(statusOpt):
          Result.Err("No updates provided. Use --title/--description/--status")
        else:
          persistPlanItemUpdate(scope, planId, itemId, {
            title: titleOpt,
            description: descriptionOpt,
            status: statusOpt,
          })
}

fun persistPlanItemUpdate(
  scope: Scope,
  planId: String,
  itemId: String,
  patch: PlanItemPatch
): Result String Unit effects { IO } {
  match updatePlanItem(scope, planId, itemId, patch) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok item ->
        line("Plan item updated:");
        printPlanItem(item);
        Result.Ok(())
}

fun runPlanSetItemStatus(
  scope: Scope,
  planId: String,
  itemId: String,
  statusRaw: String
): Result String Unit effects { IO } {
  match normalizePlanItemStatusOption(Option.Some(statusRaw)) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok statusOpt ->
        let patch: PlanItemPatch = {
          title: Option.None,
          description: Option.None,
          status: statusOpt,
        };

        match updatePlanItem(scope, planId, itemId, patch) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok item ->
              line("Plan item updated:");
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

fun planListOptionSpecs(): List CliOptionSpec {
  [{ flags: ["--all"], expectsValue: false }]
}

fun planCreateOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["--id"], expectsValue: true },
  ]
}

fun planUpdateOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["--title"], expectsValue: true },
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["--status"], expectsValue: true },
  ]
}
