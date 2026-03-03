from @std/Output import { line }
from @std/String import { join }
from "./Models" import { Task, RoadmapItem }

@public
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

@public
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

@public
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

@public
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

@public
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
