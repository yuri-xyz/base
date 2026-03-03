from @std/Output import { line, errLine }
from @std/Process import { exit }

@public
fun printMainHelp(): Unit effects { IO } {
  line("base - Git-scoped project tasks and docs");
  line("");
  line("Storage mode:");
  line("  default: <repo-root>/.base");
  line("  add --global to use user-level storage (~/.base or BASE_HOME)");
  line("");
  line("Usage:");
  line("  base");
  line("  base init");
  line("  base task ... (alias for base tasks ...)");
  line("  base tasks list [--all]");
  line("  base tasks add <title> [-d|--description <text>] [-t|--tags <csv>] [--id <key>]");
  line(
    "  base tasks update <taskId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>] [-t|--tags <csv>]",
  );
  line("  base tasks set-status <taskId> <todo|in_progress|done>");
  line("  base tasks remove <taskId>");
  line("  base tags list");
  line("  base tags add <tag>");
  line("  base tags remove <tag>");
  line("  base tags rename <from> <to>");
  line("  base plan list [--all]");
  line("  base plan create <title> [-d|--description <text>] [--id <key>]");
  line("  base plan show <planId>");
  line("  base plan set-status <planId> <planned|active|done>");
  line(
    "  base plan update <planId> [--title <text>] [-d|--description <text>] [--status <planned|active|done>]",
  );
  line("  base plan remove <planId>");
  line("  base plan add-item <planId> <title> [-d|--description <text>] [--id <key>]");
  line(
    "  base plan update-item <planId> <itemId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>]",
  );
  line("  base plan set-item-status <planId> <itemId> <todo|in_progress|done>");
  line("  base plan move-item <planId> <itemId> <position>");
  line("  base plan remove-item <planId> <itemId>");
  line("  base roadmap list");
  line("  base roadmap add <goal> [-d|--description <text>] [--id <key>]");
  line(
    "  base roadmap update <itemId> [--goal <text>] [-d|--description <text>] [--status <planned|active|done>]",
  );
  line("  base roadmap set-status <itemId> <planned|active|done>");
  line("  base roadmap move <itemId> <position>");
  line("  base roadmap remove <itemId>");
  line("  base docs list");
  line("  base docs show <name>");
  line("  base docs add <name> [-c|--content <text>] [-f|--file <path>]");
  line("  base docs update <name> [-c|--content <text>] [-f|--file <path>]");
  line("  base docs remove <name>");
  line("  base docs search <query> [-l|--limit <n>]");
  line("  base kb search <query> [-l|--limit <n>]");
  line("  base search <query> [-l|--limit <n>]");
}

@public
fun printInitHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base init",
  ])
}

@public
fun printTasksHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base tasks list [--all]",
    "  base tasks add <title> [-d|--description <text>] [-t|--tags <csv>] [--id <key>]",
    "  base tasks update <taskId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>] [-t|--tags <csv>]",
    "  base tasks set-status <taskId> <todo|in_progress|done>",
    "  base tasks remove <taskId>",
    "  base task ... (alias for base tasks ...)",
  ])
}

@public
fun printTaskCommandHelp(command: String): Unit effects { IO } {
  match command with:
    | "list" -> printLines([
      "Usage:",
      "  base tasks list [--all]",
    ])
    | "add" -> printLines([
      "Usage:",
      "  base tasks add <title> [-d|--description <text>] [-t|--tags <csv>] [--id <key>]",
    ])
    | "update" -> printLines([
      "Usage:",
      "  base tasks update <taskId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>] [-t|--tags <csv>]",
    ])
    | "set-status" -> printLines([
      "Usage:",
      "  base tasks set-status <taskId> <todo|in_progress|done>",
    ])
    | "remove" -> printLines([
      "Usage:",
      "  base tasks remove <taskId>",
    ])
    | _ -> printTasksHelp()
}

@public
fun failInvalidTasksCommand(): Unit effects { IO } {
  errLine("Error: invalid tasks command");
  printTasksHelp();
  exit(1)
}

@public
fun printRoadmapHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base roadmap list",
    "  base roadmap add <goal> [-d|--description <text>] [--id <key>]",
    "  base roadmap update <itemId> [--goal <text>] [-d|--description <text>] [--status <planned|active|done>]",
    "  base roadmap set-status <itemId> <planned|active|done>",
    "  base roadmap move <itemId> <position>",
    "  base roadmap remove <itemId>",
  ])
}

@public
fun printRoadmapCommandHelp(command: String): Unit effects { IO } {
  match command with:
    | "list" -> printLines([
      "Usage:",
      "  base roadmap list",
    ])
    | "add" -> printLines([
      "Usage:",
      "  base roadmap add <goal> [-d|--description <text>] [--id <key>]",
    ])
    | "update" -> printLines([
      "Usage:",
      "  base roadmap update <itemId> [--goal <text>] [-d|--description <text>] [--status <planned|active|done>]",
    ])
    | "set-status" -> printLines([
      "Usage:",
      "  base roadmap set-status <itemId> <planned|active|done>",
    ])
    | "move" -> printLines([
      "Usage:",
      "  base roadmap move <itemId> <position>",
    ])
    | "remove" -> printLines([
      "Usage:",
      "  base roadmap remove <itemId>",
    ])
    | _ -> printRoadmapHelp()
}

@public
fun failInvalidRoadmapCommand(): Unit effects { IO } {
  errLine("Error: invalid roadmap command");
  printRoadmapHelp();
  exit(1)
}

@public
fun printDocsHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base docs list",
    "  base docs show <name>",
    "  base docs add <name> [-c|--content <text>] [-f|--file <path>]",
    "  base docs update <name> [-c|--content <text>] [-f|--file <path>]",
    "  base docs remove <name>",
    "  base docs search <query> [-l|--limit <n>]",
  ])
}

@public
fun printDocsCommandHelp(command: String): Unit effects { IO } {
  match command with:
    | "list" -> printLines([
      "Usage:",
      "  base docs list",
    ])
    | "show" -> printLines([
      "Usage:",
      "  base docs show <name>",
    ])
    | "add" -> printLines([
      "Usage:",
      "  base docs add <name> [-c|--content <text>] [-f|--file <path>]",
    ])
    | "update" -> printLines([
      "Usage:",
      "  base docs update <name> [-c|--content <text>] [-f|--file <path>]",
    ])
    | "remove" -> printLines([
      "Usage:",
      "  base docs remove <name>",
    ])
    | "search" -> printLines([
      "Usage:",
      "  base docs search <query> [-l|--limit <n>]",
    ])
    | _ -> printDocsHelp()
}

@public
fun failInvalidDocsCommand(): Unit effects { IO } {
  errLine("Error: invalid docs command");
  printDocsHelp();
  exit(1)
}

@public
fun printSearchHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base search <query> [-l|--limit <n>]",
  ])
}

@public
fun printKbHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base kb search <query> [-l|--limit <n>]",
  ])
}

@public
fun failInvalidKbCommand(): Unit effects { IO } {
  errLine("Error: invalid kb command");
  printKbHelp();
  exit(1)
}

fun printLines(lines: List String): Unit effects { IO } {
  match lines with:
    | [] -> ()
    | [next, ...rest] -> {
        line(next);
        printLines(rest)
      }
}
