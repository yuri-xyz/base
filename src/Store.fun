from @std/FS import { exists, ensureDir, writeFile, readFile }
from @std/Json import { stringifyPretty, parse }
from @std/Time import { date }
from "./Models" import { Scope, ProjectMeta, Task, RoadmapItem, Plan, storeVersion }

@public
fun isInitialized(scope: Scope): Bool effects { IO } {
  exists(scope.metaPath)
}

@public
fun initialize(scope: Scope): Result String Unit effects { IO } {
  match ensureDir(scope.storageRoot) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> initializeAfterStorage(scope)
}

fun initializeAfterStorage(scope: Scope): Result String Unit effects { IO } {
  match ensureDir(scope.projectsDir) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> initializeAfterProjects(scope)
}

fun initializeAfterProjects(scope: Scope): Result String Unit effects { IO } {
  match ensureDir(scope.projectDir) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> initializeAfterProjectDir(scope)
}

fun initializeAfterProjectDir(scope: Scope): Result String Unit effects { IO } {
  match ensureDir(scope.docsDir) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> writeInitialFiles(scope)
}

fun writeInitialFiles(scope: Scope): Result String Unit effects { IO } {
  let now = date();
  let emptyTasks: List Task = [];
  let emptyRoadmap: List RoadmapItem = [];
  let emptyPlans: List Plan = [];
  let meta: ProjectMeta = {
    version: storeVersion(),
    projectKey: scope.projectKey,
    repoName: scope.repoName,
    repoRoot: scope.repoRoot,
    repoSource: scope.repoSource,
    createdAt: now,
    updatedAt: now,
  };

  match writeJson(scope.metaPath, meta) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> writeInitialTasks(scope, emptyTasks, emptyRoadmap, emptyPlans)
}

fun writeInitialTasks(
  scope: Scope,
  emptyTasks: List Task,
  emptyRoadmap: List RoadmapItem,
  emptyPlans: List Plan
): Result String Unit effects { IO } {
  match writeJson(scope.tasksPath, emptyTasks) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> writeInitialRoadmap(scope, emptyRoadmap, emptyPlans)
}

fun writeInitialRoadmap(
  scope: Scope,
  emptyRoadmap: List RoadmapItem,
  emptyPlans: List Plan
): Result String Unit effects { IO } {
  match writeJson(scope.roadmapPath, emptyRoadmap) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> writeJson(scope.plansPath, emptyPlans)
}

@public
fun requireInitialized(scope: Scope): Result String Unit effects { IO } {
  if isInitialized(scope):
    Result.Ok(())
  else:
    Result.Err(`Project is not initialized for ${scope.repoName}. Run: base init`)
}

@public
fun loadMeta(scope: Scope): Result String ProjectMeta effects { IO } {
  match readFile(scope.metaPath) with:
    | Result.Err _ -> Result.Err("Missing project metadata. Run: base init")
    | Result.Ok raw ->
        let parsed: Result String ProjectMeta = parse(raw);

        parsed
}

@public
fun loadTasks(scope: Scope): Result String (List Task) effects { IO } {
  if !exists(scope.tasksPath):
    Result.Ok([])
  else:
    match readFile(scope.tasksPath) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok raw ->
          let parsed: Result String (List Task) = parse(raw);

          parsed
}

@public
fun loadRoadmap(scope: Scope): Result String (List RoadmapItem) effects { IO } {
  if !exists(scope.roadmapPath):
    Result.Ok([])
  else:
    match readFile(scope.roadmapPath) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok raw ->
          let parsed: Result String (List RoadmapItem) = parse(raw);

          parsed
}

@public
fun loadPlans(scope: Scope): Result String (List Plan) effects { IO } {
  if !exists(scope.plansPath):
    Result.Ok([])
  else:
    match readFile(scope.plansPath) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok raw ->
          let parsed: Result String (List Plan) = parse(raw);

          parsed
}

@public
fun saveTasks(scope: Scope, tasks: List Task): Result String Unit effects { IO } {
  match writeJson(scope.tasksPath, tasks) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> touchMeta(scope)
}

@public
fun saveRoadmap(scope: Scope, roadmap: List RoadmapItem): Result String Unit effects { IO } {
  match writeJson(scope.roadmapPath, roadmap) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> touchMeta(scope)
}

@public
fun savePlans(scope: Scope, plans: List Plan): Result String Unit effects { IO } {
  match writeJson(scope.plansPath, plans) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> touchMeta(scope)
}

@public
fun touchMeta(scope: Scope): Result String Unit effects { IO } {
  match loadMeta(scope) with:
    | Result.Err _ -> Result.Ok(())
    | Result.Ok meta ->
        let refreshed = { ...meta, updatedAt: date() };

        writeJson(scope.metaPath, refreshed)
}

fun<a> writeJson(path: String, value: a): Result String Unit effects { IO } {
  let serialized = stringifyPretty(value);

  writeFile(path, `${serialized}
`)
}
