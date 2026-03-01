from @std/Output import { line, errLine }
from @std/FS import { readFile }
from @std/Process import { userArgs, exit }
from @std/String import { parseIntOr, trim, join }
from "./Docs" import { listDocs, showDoc, addDoc, updateDoc, removeDoc, searchDocs }
from "./Models" import { Scope, Task, TaskPatch, DocSearchResult, RoadmapItem, RoadmapPatch }
from "./PlanCli" import { runPlanCommand, planUsage }
from "./Roadmap" import {
  listRoadmap,
  addRoadmapItem,
  updateRoadmapItem,
  moveRoadmapItem,
  markRoadmapActive,
  markRoadmapDone,
  removeRoadmapItem
}
from "./Scope" import { resolveScope }
from "./Store" import { isInitialized, initialize, requireInitialized }
from "./Tasks" import { listTasks, addTask, updateTask, markTaskDone, removeTask }
from "./Util" import {
  findOptionValue,
  hasFlag,
  stripToken,
  parseTagsCsv,
  normalizeStatus,
  normalizeRoadmapStatus,
  normalizeDocName
}

@main
fun main(): Unit effects { IO } {
  let rawArgs = userArgs();
  let useGlobal = hasFlag(rawArgs, "--global", "--global");
  let args = stripToken(rawArgs, "--global");
  let scope = resolveScope(useGlobal);

  match args with:
    | [] -> showOverview(scope)
    | ["init", ..._rest] -> runInit(scope)
    | ["tasks", ...rest] -> runTasks(scope, rest)
    | ["plan", ...rest] -> runPlan(scope, rest)
    | ["roadmap", ...rest] -> runRoadmap(scope, rest)
    | ["docs", ...rest] -> runDocs(scope, rest)
    | ["kb", "search", query, ...opts] -> runDocSearch(scope, query, opts)
    | ["kb", ..._rest] -> {
      line("Usage: base kb search <query> [--limit <n>]")
    }
    | ["help", ..._rest] -> printHelp()
    | ["--help", ..._rest] -> printHelp()
    | _ ->
        errLine("Error: unknown command");
        printHelp();

        exit(1)
}

fun printHelp(): Unit effects { IO } {
  line("base - Git-scoped project tasks and docs");
  line("");
  line("Storage mode:");
  line("  default: <repo-root>/.base");
  line("  add --global to use user-level storage (~/.base or BASE_HOME)");
  line("");
  line("Usage:");
  line("  base");
  line("  base init");
  line("  base tasks list [--all]");
  line("  base tasks add <title> [-d|--description <text>] [-t|--tags <csv>]");
  line(
    "  base tasks update <taskId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>] [-t|--tags <csv>]",
  );
  line("  base tasks done <taskId>");
  line("  base tasks remove <taskId>");
  line("  base plan list [--all]");
  line("  base plan create <title> [-d|--description <text>]");
  line("  base plan show <planId>");
  line(
    "  base plan update <planId> [--title <text>] [-d|--description <text>] [--status <planned|active|done>]",
  );
  line("  base plan active <planId>");
  line("  base plan done <planId>");
  line("  base plan remove <planId>");
  line("  base plan add-item <planId> <title> [-d|--description <text>]");
  line(
    "  base plan update-item <planId> <itemId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>]",
  );
  line("  base plan progress-item <planId> <itemId>");
  line("  base plan done-item <planId> <itemId>");
  line("  base plan move-item <planId> <itemId> <position>");
  line("  base plan remove-item <planId> <itemId>");
  line("  base roadmap list");
  line("  base roadmap add <goal> [-d|--description <text>]");
  line(
    "  base roadmap update <itemId> [--goal <text>] [-d|--description <text>] [--status <planned|active|done>]",
  );
  line("  base roadmap move <itemId> <position>");
  line("  base roadmap active <itemId>");
  line("  base roadmap done <itemId>");
  line("  base roadmap remove <itemId>");
  line("  base docs list");
  line("  base docs show <name>");
  line("  base docs add <name> [-c|--content <text>] [-f|--file <path>]");
  line("  base docs update <name> [-c|--content <text>] [-f|--file <path>]");
  line("  base docs remove <name>");
  line("  base docs search <query> [-l|--limit <n>]");

  line("  base kb search <query> [-l|--limit <n>]")
}

fun runInit(scope: Scope): Unit effects { IO } {
  if isInitialized(scope):
    line(`Already initialized for ${scope.repoName}`);

    printScopeSummary(scope)
  else:
    match initialize(scope) with:
      | Result.Err e -> fail(e)
      | Result.Ok _ ->
          line(`Initialized project store for ${scope.repoName}`);

          printScopeSummary(scope)
}

fun showOverview(scope: Scope): Unit effects { IO } {
  if !isInitialized(scope):
    printScopeSummary(scope);

    line("Project is not initialized yet. Run: base init")
  else:
    match loadOverview(scope) with:
      | Result.Err e -> fail(e)
      | Result.Ok (tasks, docs, roadmap) ->
          printScopeSummary(scope);
          line("");
          printTaskList(tasks, "Pending tasks");
          line("");
          printRoadmapList(roadmap, "Roadmap goals");
          line("");
          printDocList(docs)
}

fun loadOverview(scope: Scope): Result String (List Task, List String, List RoadmapItem) effects { IO } {
  match listTasks(scope, false) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks -> loadOverviewDocs(scope, tasks)
}

fun loadOverviewDocs(scope: Scope, tasks: List Task): Result String (List Task, List String, List RoadmapItem) effects { IO } {
  match listDocs(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok docs -> loadOverviewRoadmap(scope, tasks, docs)
}

fun loadOverviewRoadmap(
  scope: Scope,
  tasks: List Task,
  docs: List String
): Result String (List Task, List String, List RoadmapItem) effects { IO } {
  match listRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok roadmap -> Result.Ok((tasks, docs, roadmap))
}

fun runTasks(scope: Scope, rest: List String): Unit effects { IO } {
  requireReady(scope);

  match rest with:
    | [] -> runTaskList(scope, [])
    | ["list", ...opts] -> runTaskList(scope, opts)
    | ["add", title, ...opts] -> runTaskAdd(scope, title, opts)
    | ["update", taskId, ...opts] -> runTaskUpdate(scope, taskId, opts)
    | ["done", taskId, ..._opts] -> runTaskDone(scope, taskId)
    | ["remove", taskId, ..._opts] -> runTaskRemove(scope, taskId)
    | _ ->
        errLine("Error: invalid tasks command");
        line("Usage: base tasks <list|add|update|done|remove> ...");

        exit(1)
}

fun runTaskList(scope: Scope, opts: List String): Unit effects { IO } {
  let includeDone = hasFlag(opts, "--all", "--all");

  match listTasks(scope, includeDone) with:
    | Result.Err e -> fail(e)
    | Result.Ok tasks ->
        let title = if includeDone: "All tasks" else: "Pending tasks";

        printTaskList(tasks, title)
}

fun runTaskAdd(scope: Scope, title: String, opts: List String): Unit effects { IO } {
  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");
  let tagsRaw = getOrElse(findOptionValue(opts, "-t", "--tags"), "");
  let tags = parseTagsCsv(tagsRaw);

  match addTask(scope, title, description, tags) with:
    | Result.Err e -> fail(e)
    | Result.Ok task ->
        line("Task created:");

        printTask(task)
}

fun runTaskUpdate(scope: Scope, taskId: String, opts: List String): Unit effects { IO } {
  let titleOpt = mapOption(findOptionValue(opts, "--title", "--title"), trim);
  let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
  let tagsOpt = mapOption(findOptionValue(opts, "-t", "--tags"), parseTagsCsv);
  let statusRawOpt = findOptionValue(opts, "--status", "--status");
  let statusOpt = normalizeStatusOption(statusRawOpt);

  match statusOpt with:
    | Result.Err e -> fail(e)
    | Result.Ok normalizedStatus -> {
      if isNone(titleOpt) and isNone(descriptionOpt) and isNone(tagsOpt) and
        isNone(normalizedStatus):
        fail("No updates provided. Use --title/--description/--status/--tags")
      else:
        let patch: TaskPatch = {
          title: titleOpt,
          description: descriptionOpt,
          status: normalizedStatus,
          tags: tagsOpt,
        };

        match updateTask(scope, taskId, patch) with:
          | Result.Err e -> fail(e)
          | Result.Ok task ->
              line("Task updated:");

              printTask(task)
    }
}

fun normalizeStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizeStatus(raw) with:
      | Option.None -> Result.Err(`Invalid status: ${raw}. Use todo | in_progress | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}

fun runTaskDone(scope: Scope, taskId: String): Unit effects { IO } {
  match markTaskDone(scope, taskId) with:
    | Result.Err e -> fail(e)
    | Result.Ok task ->
        line("Task completed:");

        printTask(task)
}

fun runTaskRemove(scope: Scope, taskId: String): Unit effects { IO } {
  match removeTask(scope, taskId) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> line(`Removed task ${taskId}`)
}

fun runPlan(scope: Scope, rest: List String): Unit effects { IO } {
  requireReady(scope);
  match runPlanCommand(scope, rest) with:
    | Result.Err e -> if e == planUsage():
      errLine("Error: invalid plan command");
      line(planUsage());
      exit(1)
    else:
      fail(e)
    | Result.Ok _ -> ()
}

fun runRoadmap(scope: Scope, rest: List String): Unit effects { IO } {
  requireReady(scope);

  match rest with:
    | [] -> runRoadmapList(scope)
    | ["list", ..._opts] -> runRoadmapList(scope)
    | ["add", goal, ...opts] -> runRoadmapAdd(scope, goal, opts)
    | ["update", itemId, ...opts] -> runRoadmapUpdate(scope, itemId, opts)
    | ["move", itemId, positionText, ..._opts] -> runRoadmapMove(scope, itemId, positionText)
    | ["active", itemId, ..._opts] -> runRoadmapActive(scope, itemId)
    | ["done", itemId, ..._opts] -> runRoadmapDone(scope, itemId)
    | ["remove", itemId, ..._opts] -> runRoadmapRemove(scope, itemId)
    | _ ->
        errLine("Error: invalid roadmap command");
        line("Usage: base roadmap <list|add|update|move|active|done|remove> ...");

        exit(1)
}

fun runRoadmapList(scope: Scope): Unit effects { IO } {
  match listRoadmap(scope) with:
    | Result.Err e -> fail(e)
    | Result.Ok items -> printRoadmapList(items, "Roadmap goals")
}

fun runRoadmapAdd(scope: Scope, goal: String, opts: List String): Unit effects { IO } {
  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");

  match addRoadmapItem(scope, goal, description) with:
    | Result.Err e -> fail(e)
    | Result.Ok item ->
        line("Roadmap goal created:");
        printRoadmapItem(item)
}

fun runRoadmapUpdate(scope: Scope, itemId: String, opts: List String): Unit effects { IO } {
  let goalOpt = mapOption(findOptionValue(opts, "--goal", "--goal"), trim);
  let descriptionOpt = mapOption(findOptionValue(opts, "-d", "--description"), trim);
  let statusRawOpt = findOptionValue(opts, "--status", "--status");
  let statusOptResult = normalizeRoadmapStatusOption(statusRawOpt);

  match statusOptResult with:
    | Result.Err e -> fail(e)
    | Result.Ok statusOpt -> {
      if isNone(goalOpt) and isNone(descriptionOpt) and isNone(statusOpt):
        fail("No updates provided. Use --goal/--description/--status")
      else:
        let patch: RoadmapPatch = {
          goal: goalOpt,
          description: descriptionOpt,
          status: statusOpt,
        };

        match updateRoadmapItem(scope, itemId, patch) with:
          | Result.Err e -> fail(e)
          | Result.Ok item ->
              line("Roadmap goal updated:");
              printRoadmapItem(item)
    }
}

fun runRoadmapMove(scope: Scope, itemId: String, positionText: String): Unit effects { IO } {
  let position = max(1, parseIntOr(positionText, 1));
  let positionDisplay = show(position);

  match moveRoadmapItem(scope, itemId, position) with:
    | Result.Err e -> fail(e)
    | Result.Ok items ->
        line(`Moved roadmap goal ${itemId} to position ${positionDisplay}`);
        printRoadmapList(items, "Roadmap goals")
}

fun runRoadmapActive(scope: Scope, itemId: String): Unit effects { IO } {
  match markRoadmapActive(scope, itemId) with:
    | Result.Err e -> fail(e)
    | Result.Ok item ->
        line("Roadmap goal marked active:");
        printRoadmapItem(item)
}

fun runRoadmapDone(scope: Scope, itemId: String): Unit effects { IO } {
  match markRoadmapDone(scope, itemId) with:
    | Result.Err e -> fail(e)
    | Result.Ok item ->
        line("Roadmap goal completed:");
        printRoadmapItem(item)
}

fun runRoadmapRemove(scope: Scope, itemId: String): Unit effects { IO } {
  match removeRoadmapItem(scope, itemId) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> line(`Removed roadmap goal ${itemId}`)
}

fun normalizeRoadmapStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizeRoadmapStatus(raw) with:
      | Option.None -> Result.Err(`Invalid roadmap status: ${raw}. Use planned | active | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}

fun runDocs(scope: Scope, rest: List String): Unit effects { IO } {
  requireReady(scope);

  match rest with:
    | [] -> runDocList(scope)
    | ["list", ..._opts] -> runDocList(scope)
    | ["show", name, ..._opts] -> runDocShow(scope, name)
    | ["add", name, ...opts] -> runDocAdd(scope, name, opts)
    | ["update", name, ...opts] -> runDocUpdate(scope, name, opts)
    | ["remove", name, ..._opts] -> runDocRemove(scope, name)
    | ["search", query, ...opts] -> runDocSearch(scope, query, opts)
    | _ ->
        errLine("Error: invalid docs command");
        line("Usage: base docs <list|show|add|update|remove|search> ...");

        exit(1)
}

fun runDocList(scope: Scope): Unit effects { IO } {
  match listDocs(scope) with:
    | Result.Err e -> fail(e)
    | Result.Ok docs -> printDocList(docs)
}

fun runDocShow(scope: Scope, name: String): Unit effects { IO } {
  match showDoc(scope, name) with:
    | Result.Err e -> fail(e)
    | Result.Ok content ->
        let normalized = normalizeDocName(name);

        line(`# ${normalized}`);

        line(content)
}

fun runDocAdd(scope: Scope, name: String, opts: List String): Unit effects { IO } {
  match resolveDocContent(opts, false) with:
    | Result.Err e -> fail(e)
    | Result.Ok content -> match addDoc(scope, name, content) with:
      | Result.Err e -> fail(e)
      | Result.Ok savedAs -> line(`Created doc ${savedAs}`)
}

fun runDocUpdate(scope: Scope, name: String, opts: List String): Unit effects { IO } {
  match resolveDocContent(opts, true) with:
    | Result.Err e -> fail(e)
    | Result.Ok content -> match updateDoc(scope, name, content) with:
      | Result.Err e -> fail(e)
      | Result.Ok savedAs -> line(`Updated doc ${savedAs}`)
}

fun runDocRemove(scope: Scope, name: String): Unit effects { IO } {
  match removeDoc(scope, name) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ ->
        let normalized = normalizeDocName(name);

        line(`Removed doc ${normalized}`)
}

fun runDocSearch(scope: Scope, query: String, opts: List String): Unit effects { IO } {
  requireReady(scope);

  let rawLimit = getOrElse(findOptionValue(opts, "-l", "--limit"), "5");
  let limit = max(1, parseIntOr(rawLimit, 5));

  match searchDocs(scope, query, limit) with:
    | Result.Err e -> fail(e)
    | Result.Ok results -> printDocSearch(results)
}

fun resolveDocContent(opts: List String, required: Bool): Result String String effects { IO } {
  let inline = findOptionValue(opts, "-c", "--content");
  let filePath = findOptionValue(opts, "-f", "--file");

  match (inline, filePath) with:
    | (Option.Some _text, Option.Some _path) -> Result.Err(
      "Provide either --content or --file, not both",
    )
    | (Option.Some text, Option.None) -> Result.Ok(text)
    | (Option.None, Option.Some path) -> readFile(path)
    | (Option.None, Option.None) -> if required:
      Result.Err("You must provide doc content using --content or --file")
    else:
      Result.Ok("")
}

fun requireReady(scope: Scope): Unit effects { IO } {
  match requireInitialized(scope) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ()
}

fun fail(message: String): Unit effects { IO } {
  errLine(`Error: ${message}`);

  exit(1)
}

fun printScopeSummary(scope: Scope): Unit effects { IO } {
  line(`Project: ${scope.repoName}`);
  line(`Repo root: ${scope.repoRoot}`);

  line(`Store: ${scope.projectDir}`)
}

fun printTask(task: Task): Unit effects { IO } {
  line(`[${task.id}] ${task.title}`);
  line(`  status: ${task.status}`);

  if task.tags == []:
    ()
  else:
    let tagsText = join(task.tags, ", ");

    line(`  tags: ${tagsText}`);

  if task.description == "":
    ()
  else:
    line(`  note: ${task.description}`)
}

fun printTaskList(tasks: List Task, title: String): Unit effects { IO } {
  line(title);

  match tasks with:
    | [] -> line("  (none)")
    | _ -> printTaskListItems(tasks, false)
}

fun printTaskListItems(tasks: List Task, started: Bool): Unit effects { IO } {
  match tasks with:
    | [] -> ()
    | [task, ...rest] -> {
        if started:
          line("------------------------------------------------------------")
        else:
          ();

        printTask(task);

        printTaskListItems(rest, true)
	      }
}

fun printRoadmapList(items: List RoadmapItem, title: String): Unit effects { IO } {
  line(title);

  match items with:
    | [] -> line("  (none)")
    | _ -> printRoadmapListItems(items)
}

fun printRoadmapListItems(items: List RoadmapItem): Unit effects { IO } {
  match items with:
    | [] -> ()
    | [item, ...rest] -> {
        printRoadmapItem(item);
        printRoadmapListItems(rest)
      }
}

fun printRoadmapItem(item: RoadmapItem): Unit effects { IO } {
  let orderText = show(item.order);
  line(`${orderText}. [${item.status}] ${item.goal}`);
  line(`   id: ${item.id}`);

  if item.description == "":
    ()
  else:
    line(`   note: ${item.description}`);

  if item.status == "done":
    let completed = completedText(item.completedAt);
    line(`   completed: ${completed}`)
  else:
    ()
}

fun completedText(completedAt: Option String): String {
  match completedAt with:
    | Option.None -> "unknown"
    | Option.Some at -> at
}

fun printDocList(docs: List String): Unit effects { IO } {
  line("Docs");

  match docs with:
    | [] -> line("  (none)")
    | _ -> printDocListItems(docs)
}

fun printDocListItems(docs: List String): Unit effects { IO } {
  match docs with:
    | [] -> ()
    | [doc, ...rest] -> {
        line(`  - ${doc}`);

        printDocListItems(rest)
      }
}

fun printDocSearch(results: List DocSearchResult): Unit effects { IO } {
  match results with:
    | [] -> line("No docs matched your query.")
    | _ -> printDocSearchItems(results, 1)
}

fun printDocSearchItems(results: List DocSearchResult, index: Int): Unit effects { IO } {
  match results with:
    | [] -> ()
    | [result, ...rest] -> {
        let rank = show(index);
        let scoreText = show(result.score);

        line(`${rank}. ${result.name} (score: ${scoreText})`);
        line(`   ${result.excerpt}`);

        printDocSearchItems(rest, index + 1)
      }
}

fun max(a: Int, b: Int): Int {
  if a > b: a else: b
}
