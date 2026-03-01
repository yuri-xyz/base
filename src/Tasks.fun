from @std/Crypto import { randomUUID }
from @std/List import { filter, sort, length }
from @std/String import { trim }
from @std/Time import { date }
from "./Models" import { Scope, Task, TaskPatch }
from "./Store" import { loadTasks, saveTasks }
from "./Tags" import { ensureGlobalTags }

@public
fun listTasks(scope: Scope, includeDone: Bool): Result String (List Task) effects { IO } {
  match loadTasks(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks ->
        let visible = if includeDone: tasks else: filter(tasks, (task) => { task.status != "done" });

        Result.Ok(sortByRecent(visible))
}

fun sortByRecent(tasks: List Task): List Task {
  sort(tasks, (left, right) => {
    if left.updatedAt > right.updatedAt:
      -1
    elif left.updatedAt < right.updatedAt:
      1
    else:
      0
  })
}

@public
fun addTask(
  scope: Scope,
  titleRaw: String,
  descriptionRaw: String,
  tags: List String
): Result String Task effects { IO } {
  let title = trim(titleRaw);

  if title == "":
    Result.Err("Task title cannot be empty")
  else:
    match ensureGlobalTags(scope, tags) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok normalizedTags -> addTaskWithTags(scope, title, trim(descriptionRaw), normalizedTags)
}

fun addTaskWithTags(
  scope: Scope,
  title: String,
  description: String,
  tags: List String
): Result String Task effects { IO } {
  match loadTasks(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks -> addTaskWithLoadedTasks(scope, tasks, title, description, tags)
}

fun addTaskWithLoadedTasks(
  scope: Scope,
  tasks: List Task,
  title: String,
  description: String,
  tags: List String
): Result String Task effects { IO } {
  let now = date();
  let nextTask: Task = {
    id: randomUUID(),
    title,
    description,
    status: "todo",
    tags,
    createdAt: now,
    updatedAt: now,
  };
  let nextTasks = tasks & [nextTask];

  match saveTasks(scope, nextTasks) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(nextTask)
}

@public
fun updateTask(scope: Scope, taskId: String, patch: TaskPatch): Result String Task effects { IO } {
  match resolveTaskPatch(scope, patch) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok resolvedPatch -> match loadTasks(scope) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok tasks -> updateWithTasks(scope, tasks, taskId, resolvedPatch)
}

fun resolveTaskPatch(scope: Scope, patch: TaskPatch): Result String TaskPatch effects { IO } {
  match patch.tags with:
    | Option.None -> Result.Ok(patch)
    | Option.Some nextTags -> match ensureGlobalTags(scope, nextTags) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok normalizedTags ->
          let resolved: TaskPatch = {
            ...patch,
            tags: Option.Some(normalizedTags),
          };

          Result.Ok(resolved)
}

fun updateWithTasks(
  scope: Scope,
  tasks: List Task,
  taskId: String,
  patch: TaskPatch
): Result String Task effects { IO } {
  match applyTaskPatch(tasks, taskId, patch, []) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok (updated, nextTasks) -> persistUpdatedTask(scope, updated, nextTasks)
}

fun persistUpdatedTask(
  scope: Scope,
  updated: Task,
  tasks: List Task
): Result String Task effects { IO } {
  match saveTasks(scope, tasks) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(updated)
}

fun applyTaskPatch(
  tasks: List Task,
  taskId: String,
  patch: TaskPatch,
  acc: List Task
): Result String (Task, List Task) {
  match tasks with:
    | [] -> Result.Err(`Task not found: ${taskId}`)
    | [task, ...rest] -> if task.id == taskId:
      let nextTask = mergePatch(task, patch);
      let ordered = acc & [nextTask] & rest;

      Result.Ok((nextTask, ordered))
    else:
      applyTaskPatch(rest, taskId, patch, acc & [task])
}

fun mergePatch(task: Task, patch: TaskPatch): Task {
  let nextTitle = getOrElse(patch.title, task.title);
  let nextDescription = getOrElse(patch.description, task.description);
  let nextStatus = getOrElse(patch.status, task.status);
  let nextTags = getOrElse(patch.tags, task.tags);

  {
    ...task,
    title: nextTitle,
    description: nextDescription,
    status: nextStatus,
    tags: nextTags,
    updatedAt: date(),
  }
}

@public
fun markTaskDone(scope: Scope, taskId: String): Result String Task effects { IO } {
  let patch: TaskPatch = {
    title: Option.None,
    description: Option.None,
    status: Option.Some("done"),
    tags: Option.None,
  };

  updateTask(scope, taskId, patch)
}

@public
fun removeTask(scope: Scope, taskId: String): Result String Unit effects { IO } {
  match loadTasks(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tasks ->
        let remaining = filter(tasks, (task) => { task.id != taskId });

        if length(remaining) == length(tasks):
          Result.Err(`Task not found: ${taskId}`)
        else:
          saveTasks(scope, remaining)
}
