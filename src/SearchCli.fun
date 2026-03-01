from @std/Output import { line }
from @std/List import { sort, take, length, filter }
from @std/String import { parseIntOr, trim, join }
from "./Docs" import { searchDocs }
from "./Models" import { Scope, Task, RoadmapItem, Plan, PlanItem, DocSearchResult }
from "./Plans" import { listPlans }
from "./Roadmap" import { listRoadmap }
from "./Tasks" import { listTasks }
from "./Util" import { findOptionValue, fuzzyDocScore, normalizedExcerpt }

type alias SearchHit = {
  kind: String,
  id: String,
  title: String,
  context: String,
  score: Int
}

@public
fun runGlobalSearchCommand(scope: Scope, queryRaw: String, opts: List String): Result String Unit effects { IO } {
  let query = trim(queryRaw);

  if query == "":
    Result.Err("Search query cannot be empty")
  else:
    let rawLimit = getOrElse(findOptionValue(opts, "-l", "--limit"), "12");
    let limit = max(1, parseIntOr(rawLimit, 12));
    let docLimit = max(25, limit * 3);

    match collectGlobalHits(scope, query, docLimit) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok allHits -> {
        let ranked = take(sortHits(allHits), limit);

        printSearchResults(query, ranked);

        Result.Ok(())
      }
}

fun collectGlobalHits(scope: Scope, query: String, docLimit: Int): Result String (List SearchHit) effects { IO } {
  match collectTaskHits(scope, query) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok taskHits -> collectGlobalHitsWithTasks(scope, query, docLimit, taskHits)
}

fun collectGlobalHitsWithTasks(
  scope: Scope,
  query: String,
  docLimit: Int,
  taskHits: List SearchHit
): Result String (List SearchHit) effects { IO } {
  match collectRoadmapHits(scope, query) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok roadmapHits -> collectGlobalHitsWithRoadmap(scope, query, docLimit, taskHits, roadmapHits)
}

fun collectGlobalHitsWithRoadmap(
  scope: Scope,
  query: String,
  docLimit: Int,
  taskHits: List SearchHit,
  roadmapHits: List SearchHit
): Result String (List SearchHit) effects { IO } {
  match collectPlanHits(scope, query) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok planHits -> collectGlobalHitsWithPlans(scope, query, docLimit, taskHits, roadmapHits, planHits)
}

fun collectGlobalHitsWithPlans(
  scope: Scope,
  query: String,
  docLimit: Int,
  taskHits: List SearchHit,
  roadmapHits: List SearchHit,
  planHits: List SearchHit
): Result String (List SearchHit) effects { IO } {
  match collectDocHits(scope, query, docLimit) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok docHits -> Result.Ok(taskHits & roadmapHits & planHits & docHits)
}

fun collectTaskHits(scope: Scope, query: String): Result String (List SearchHit) effects { IO } {
  match listTasks(scope, true) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks -> Result.Ok(scoreTasks(tasks, query, []))
}

fun scoreTasks(tasks: List Task, query: String, acc: List SearchHit): List SearchHit {
  match tasks with:
    | [] -> acc
    | [task, ...rest] ->
        let tagsText = if task.tags == []: "" else: join(task.tags, ", ");
        let combined = `${task.description} ${tagsText} ${task.status}`;
        let score = fuzzyDocScore(query, task.title, combined);
        let context = taskContext(task);
        let next = if score > 0:
          acc & [makeHit("task", task.id, task.title, context, score)]
        else:
          acc;

        scoreTasks(rest, query, next)
}

fun taskContext(task: Task): String {
  let note = normalizedExcerpt(task.description, 90);

  if note == "":
    `status: ${task.status}`
  else:
    `status: ${task.status}; note: ${note}`
}

fun collectRoadmapHits(scope: Scope, query: String): Result String (List SearchHit) effects { IO } {
  match listRoadmap(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok items -> Result.Ok(scoreRoadmap(items, query, []))
}

fun scoreRoadmap(items: List RoadmapItem, query: String, acc: List SearchHit): List SearchHit {
  match items with:
    | [] -> acc
    | [item, ...rest] ->
        let content = `${item.description} ${item.status}`;
        let score = fuzzyDocScore(query, item.goal, content);
        let orderText = show(item.order);
        let baseTitle = `${orderText}. ${item.goal}`;
        let context = roadmapContext(item);
        let next = if score > 0:
          acc & [makeHit("roadmap", item.id, baseTitle, context, score)]
        else:
          acc;

        scoreRoadmap(rest, query, next)
}

fun roadmapContext(item: RoadmapItem): String {
  let note = normalizedExcerpt(item.description, 90);

  if note == "":
    `status: ${item.status}`
  else:
    `status: ${item.status}; note: ${note}`
}

fun collectPlanHits(scope: Scope, query: String): Result String (List SearchHit) effects { IO } {
  match listPlans(scope, true) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok plans -> Result.Ok(scorePlans(plans, query, []))
}

fun scorePlans(plans: List Plan, query: String, acc: List SearchHit): List SearchHit {
  match plans with:
    | [] -> acc
    | [plan, ...rest] ->
        let scoredPlan = appendPlanHit(acc, query, plan);
        let scoredItems = scorePlanItems(scoredPlan, query, plan, plan.items);
        scorePlans(rest, query, scoredItems)
}

fun appendPlanHit(acc: List SearchHit, query: String, plan: Plan): List SearchHit {
  let content = `${plan.description} ${plan.status}`;
  let score = fuzzyDocScore(query, plan.title, content);
  let context = planContext(plan);

  if score > 0:
    acc & [makeHit("plan", plan.id, plan.title, context, score)]
  else:
    acc
}

fun planContext(plan: Plan): String {
  let note = normalizedExcerpt(plan.description, 90);

  if note == "":
    `status: ${plan.status}`
  else:
    `status: ${plan.status}; note: ${note}`
}

fun scorePlanItems(
  acc: List SearchHit,
  query: String,
  plan: Plan,
  items: List PlanItem
): List SearchHit {
  match items with:
    | [] -> acc
    | [item, ...rest] ->
        let content = `${item.description} ${item.status} ${plan.title}`;
        let score = fuzzyDocScore(query, item.title, content);
        let context = planItemContext(plan, item);
        let next = if score > 0:
          acc & [makeHit("plan_item", item.id, item.title, context, score)]
        else:
          acc;

        scorePlanItems(next, query, plan, rest)
}

fun planItemContext(plan: Plan, item: PlanItem): String {
  let note = normalizedExcerpt(item.description, 80);

  if note == "":
    `plan: ${plan.title}; status: ${item.status}`
  else:
    `plan: ${plan.title}; status: ${item.status}; note: ${note}`
}

fun collectDocHits(scope: Scope, query: String, limit: Int): Result String (List SearchHit) effects { IO } {
  match searchDocs(scope, query, limit) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok results -> Result.Ok(mapDocResults(results, []))
}

fun mapDocResults(results: List DocSearchResult, acc: List SearchHit): List SearchHit {
  match results with:
    | [] -> acc
    | [result, ...rest] ->
        let next = acc & [makeHit("doc", result.name, result.name, result.excerpt, result.score)];
        mapDocResults(rest, next)
}

fun makeHit(kind: String, id: String, title: String, context: String, score: Int): SearchHit {
  {
    kind,
    id,
    title,
    context,
    score,
  }
}

fun sortHits(hits: List SearchHit): List SearchHit {
  sort(hits, (left, right) => {
    if left.score > right.score:
      -1
    elif left.score < right.score:
      1
    elif left.kind < right.kind:
      -1
    elif left.kind > right.kind:
      1
    elif left.title < right.title:
      -1
    elif left.title > right.title:
      1
    else:
      0
  })
}

fun printSearchResults(query: String, results: List SearchHit): Unit effects { IO } {
  let countText = show(length(results));
  line(`Search results for "${query}" (${countText})`);

  match results with:
    | [] -> line("  (none)")
    | _ -> printGroupedSearchResults(results)
}

fun printGroupedSearchResults(results: List SearchHit): Unit effects { IO } {
  let tasks = filter(results, (hit) => { hit.kind == "task" });
  let plans = filter(results, (hit) => { hit.kind == "plan" });
  let planItems = filter(results, (hit) => { hit.kind == "plan_item" });
  let roadmap = filter(results, (hit) => { hit.kind == "roadmap" });
  let docs = filter(results, (hit) => { hit.kind == "doc" });

  printSearchGroup("Tasks", tasks);
  printSearchGroup("Plans", plans);
  printSearchGroup("Plan Items", planItems);
  printSearchGroup("Roadmap", roadmap);
  printSearchGroup("Docs", docs)
}

fun printSearchGroup(title: String, results: List SearchHit): Unit effects { IO } {
  match results with:
    | [] -> ()
    | _ -> {
      let countText = show(length(results));
      line("");
      line(`${title} (${countText})`);
      printSearchResultItems(results, 1)
    }
}

fun printSearchResultItems(results: List SearchHit, index: Int): Unit effects { IO } {
  match results with:
    | [] -> ()
    | [result, ...rest] -> {
      let rank = show(index);
      let scoreText = show(result.score);
      line(`${rank}. [${result.kind}] ${result.title} (score: ${scoreText})`);
      line(`   id: ${result.id}`);

      if result.context == "":
        ()
      else:
        line(`   ${result.context}`);

      printSearchResultItems(rest, index + 1)
    }
}

fun max(a: Int, b: Int): Int {
  if a > b: a else: b
}
