from @std/Output import { line, errLine }
from @std/FS import { readFile }
from @std/Process import { userArgs, exit }
from @std/String import { parseIntOr, trim }
from "./DisplayCli" import { printDocList, printRoadmapItem, printRoadmapList, printTask, printTaskList }
from "./DocSearchCli" import { runDocSearchCommand }
from "./Docs" import { listDocs, showDoc, addDoc, updateDoc, removeDoc }
from "./HelpCli" import {
  failInvalidKbCommand,
  failInvalidDocsCommand,
  failInvalidRoadmapCommand,
  failInvalidTasksCommand,
  printDocsCommandHelp,
  printDocsHelp,
  printInitHelp,
  printKbHelp,
  printMainHelp,
  printRoadmapCommandHelp,
  printRoadmapHelp,
  printSearchHelp,
  printTaskCommandHelp,
  printTasksHelp
}
from "./Models" import { Scope, Task, TaskPatch, RoadmapItem, RoadmapPatch }
from "./PlanCli" import { runPlanCommand, planUsage }
from "./Roadmap" import {
  listRoadmap,
  addRoadmapItem,
  updateRoadmapItem,
  moveRoadmapItem,
  removeRoadmapItem
}
from "./Scope" import { resolveScope }
from "./SearchCli" import { runGlobalSearchCommand }
from "./StatusCli" import { normalizeStatusOption, normalizeRoadmapStatusOption }
from "./Store" import { isInitialized, initialize, requireInitialized }
from "./TagsCli" import { runTagsCommand, tagsUsage }
from "./Tasks" import { listTasks, addTask, updateTask, removeTask }
from "./Util" import {
  CliOptionSpec,
  findOptionValue,
  hasHelpFlag,
  hasFlag,
  isHelpRequest,
  validateOptions,
  stripToken,
  parseTagsCsv,
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
    | ["init"] -> runInit(scope)
    | ["init", "-h"] -> printInitHelp()
    | ["init", "--help"] -> printInitHelp()
    | ["tasks", ...rest] -> runTasks(scope, rest)
    | ["task", ...rest] -> runTasks(scope, rest)
    | ["tags", ...rest] -> runTags(scope, rest)
    | ["plan", ...rest] -> runPlan(scope, rest)
    | ["roadmap", ...rest] -> runRoadmap(scope, rest)
    | ["docs", ...rest] -> runDocs(scope, rest)
    | ["kb", ...rest] -> runKb(scope, rest)
    | ["search", ...rest] -> runSearchEntry(scope, rest)
    | ["help"] -> printMainHelp()
    | ["-h"] -> printMainHelp()
    | ["--help"] -> printMainHelp()
    | _ ->
        errLine("Error: unknown command");
        printMainHelp();
        exit(1)
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
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);

  match rest with:
    | [] -> runTaskList(scope, [])
    | ["help"] -> printTasksHelp()
    | ["-h"] -> printTasksHelp()
    | ["--help"] -> printTasksHelp()
    | ["help", command] -> printTaskCommandHelp(command)
    | [command, ...args] -> runTasksCommand(scope, command, args)
}

fun runTasksCommand(scope: Scope, command: String, args: List String): Unit effects { IO } {
  if hasHelpFlag(args):
    printTaskCommandHelp(command)
  else:
    match (command, args) with:
      | ("list", opts) -> runTaskList(scope, opts)
      | ("add", [title, ...opts]) -> runTaskAdd(scope, title, opts)
      | ("update", [taskId, ...opts]) -> runTaskUpdate(scope, taskId, opts)
      | ("set-status", [taskId, statusRaw]) -> runTaskUpdate(scope, taskId, ["--status", statusRaw])
      | ("remove", [taskId]) -> runTaskRemove(scope, taskId)
      | _ -> failInvalidTasksCommand()
}

fun runTaskList(scope: Scope, opts: List String): Unit effects { IO } {
  match validateOptions(opts, taskListOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  let includeDone = hasFlag(opts, "--all", "--all");

  match listTasks(scope, includeDone) with:
    | Result.Err e -> fail(e)
    | Result.Ok tasks ->
        let title = if includeDone: "All tasks" else: "Pending tasks";

        printTaskList(tasks, title)
}

fun runTaskAdd(scope: Scope, title: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, taskAddOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");
  let tagsRaw = getOrElse(findOptionValue(opts, "-t", "--tags"), "");
  let tags = parseTagsCsv(tagsRaw);
  let idKeyOpt = findOptionValue(opts, "--id", "--id");

  match addTask(scope, title, description, tags, idKeyOpt) with:
    | Result.Err e -> fail(e)
    | Result.Ok task ->
        line("Task created:");

        printTask(task)
}

fun runTaskUpdate(scope: Scope, taskId: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, taskUpdateOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

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

fun runTaskRemove(scope: Scope, taskId: String): Unit effects { IO } {
  match removeTask(scope, taskId) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> line(`Removed task ${taskId}`)
}

fun runPlan(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
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

fun runTags(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);
  match runTagsCommand(scope, rest) with:
    | Result.Err e -> if e == tagsUsage():
      errLine("Error: invalid tags command");
      line(tagsUsage());
      exit(1)
    else:
      fail(e)
    | Result.Ok _ -> ()
}

fun runRoadmap(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);

  match rest with:
    | [] -> runRoadmapList(scope, [])
    | ["help"] -> printRoadmapHelp()
    | ["-h"] -> printRoadmapHelp()
    | ["--help"] -> printRoadmapHelp()
    | ["help", command] -> printRoadmapCommandHelp(command)
    | [command, ...args] -> runRoadmapCommand(scope, command, args)
}

fun runRoadmapCommand(scope: Scope, command: String, args: List String): Unit effects { IO } {
  if hasHelpFlag(args):
    printRoadmapCommandHelp(command)
  else:
    match (command, args) with:
      | ("list", opts) -> runRoadmapList(scope, opts)
      | ("add", [goal, ...opts]) -> runRoadmapAdd(scope, goal, opts)
      | ("update", [itemId, ...opts]) -> runRoadmapUpdate(scope, itemId, opts)
      | ("set-status", [itemId, statusRaw]) -> runRoadmapUpdate(scope, itemId, ["--status", statusRaw])
      | ("move", [itemId, positionText]) -> runRoadmapMove(scope, itemId, positionText)
      | ("remove", [itemId]) -> runRoadmapRemove(scope, itemId)
      | _ -> failInvalidRoadmapCommand()
}

fun runRoadmapList(scope: Scope, opts: List String): Unit effects { IO } {
  match validateOptions(opts, []) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  match listRoadmap(scope) with:
    | Result.Err e -> fail(e)
    | Result.Ok items -> printRoadmapList(items, "Roadmap goals")
}

fun runRoadmapAdd(scope: Scope, goal: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, roadmapAddOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  let description = getOrElse(findOptionValue(opts, "-d", "--description"), "");
  let idKeyOpt = findOptionValue(opts, "--id", "--id");

  match addRoadmapItem(scope, goal, description, idKeyOpt) with:
    | Result.Err e -> fail(e)
    | Result.Ok item ->
        line("Roadmap goal created:");
        printRoadmapItem(item)
}

fun runRoadmapUpdate(scope: Scope, itemId: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, roadmapUpdateOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

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

fun runRoadmapRemove(scope: Scope, itemId: String): Unit effects { IO } {
  match removeRoadmapItem(scope, itemId) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> line(`Removed roadmap goal ${itemId}`)
}

fun runDocs(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);

  match rest with:
    | [] -> runDocList(scope, [])
    | ["help"] -> printDocsHelp()
    | ["-h"] -> printDocsHelp()
    | ["--help"] -> printDocsHelp()
    | ["help", command] -> printDocsCommandHelp(command)
    | [command, ...args] -> runDocsCommand(scope, command, args)
}

fun runDocsCommand(scope: Scope, command: String, args: List String): Unit effects { IO } {
  if hasHelpFlag(args):
    printDocsCommandHelp(command)
  else:
    match (command, args) with:
      | ("list", opts) -> runDocList(scope, opts)
      | ("show", [name]) -> runDocShow(scope, name)
      | ("add", [name, ...opts]) -> runDocAdd(scope, name, opts)
      | ("update", [name, ...opts]) -> runDocUpdate(scope, name, opts)
      | ("remove", [name]) -> runDocRemove(scope, name)
      | ("search", [query, ...opts]) -> runDocSearch(scope, query, opts)
      | _ -> failInvalidDocsCommand()
}

fun runDocList(scope: Scope, opts: List String): Unit effects { IO } {
  match validateOptions(opts, []) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

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
  match validateOptions(opts, docContentOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  match resolveDocContent(opts, false) with:
    | Result.Err e -> fail(e)
    | Result.Ok content -> match addDoc(scope, name, content) with:
      | Result.Err e -> fail(e)
      | Result.Ok savedAs -> line(`Created doc ${savedAs}`)
}

fun runDocUpdate(scope: Scope, name: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, docContentOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

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
  match validateOptions(opts, searchLimitOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  match runDocSearchCommand(scope, query, opts) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ()
}

fun runKb(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);

  match rest with:
    | [] -> printKbHelp()
    | ["help"] -> printKbHelp()
    | ["-h"] -> printKbHelp()
    | ["--help"] -> printKbHelp()
    | ["search"] -> printKbHelp()
    | ["search", ...args] -> if hasHelpFlag(args):
      printKbHelp()
    else:
      match args with:
        | [query, ...opts] -> runDocSearch(scope, query, opts)
        | _ -> failInvalidKbCommand()
    | _ -> failInvalidKbCommand()
}

fun runSearchEntry(scope: Scope, rest: List String): Unit effects { IO } {
  if isHelpRequest(rest):
    ()
  else:
    requireReady(scope);

  match rest with:
    | [] -> printSearchHelp()
    | ["help"] -> printSearchHelp()
    | ["-h"] -> printSearchHelp()
    | ["--help"] -> printSearchHelp()
    | [query, ...opts] -> if hasHelpFlag(rest):
      printSearchHelp()
    else:
      runSearch(scope, query, opts)
}

fun runSearch(scope: Scope, query: String, opts: List String): Unit effects { IO } {
  match validateOptions(opts, searchLimitOptionSpecs()) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ();

  match runGlobalSearchCommand(scope, query, opts) with:
    | Result.Err e -> fail(e)
    | Result.Ok _ -> ()
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

fun taskListOptionSpecs(): List CliOptionSpec {
  [{ flags: ["--all"], expectsValue: false }]
}

fun taskAddOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["-t", "--tags"], expectsValue: true },
    { flags: ["--id"], expectsValue: true },
  ]
}

fun taskUpdateOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["--title"], expectsValue: true },
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["--status"], expectsValue: true },
    { flags: ["-t", "--tags"], expectsValue: true },
  ]
}

fun roadmapAddOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["--id"], expectsValue: true },
  ]
}

fun roadmapUpdateOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["--goal"], expectsValue: true },
    { flags: ["-d", "--description"], expectsValue: true },
    { flags: ["--status"], expectsValue: true },
  ]
}

fun docContentOptionSpecs(): List CliOptionSpec {
  [
    { flags: ["-c", "--content"], expectsValue: true },
    { flags: ["-f", "--file"], expectsValue: true },
  ]
}

fun searchLimitOptionSpecs(): List CliOptionSpec {
  [{ flags: ["-l", "--limit"], expectsValue: true }]
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

fun max(a: Int, b: Int): Int {
  if a > b: a else: b
}
