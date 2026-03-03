from @std/Output import { line }
from "./Models" import { Scope }
from "./Tags" import { listGlobalTags, addGlobalTag, removeGlobalTag, renameGlobalTag }
from "./Util" import { hasHelpFlag }

@public
fun runTagsCommand(scope: Scope, rest: List String): Result String Unit effects { IO } {
  match rest with:
    | [] -> runTagsList(scope)
    | ["help"] -> showTagsHelp()
    | ["-h"] -> showTagsHelp()
    | ["--help"] -> showTagsHelp()
    | ["help", command] -> showTagsCommandHelp(command)
    | [command, ...args] -> runTagsCommandWithArgs(scope, command, args)
}

@public
fun tagsUsage(): String {
  "Usage: base tags <list|add|remove|rename> ..."
}

fun runTagsCommandWithArgs(
  scope: Scope,
  command: String,
  args: List String
): Result String Unit effects { IO } {
  if hasHelpFlag(args):
    showTagsCommandHelp(command)
  else:
    match (command, args) with:
      | ("list", []) -> runTagsList(scope)
      | ("add", [tag]) -> runTagsAdd(scope, tag)
      | ("remove", [tag]) -> runTagsRemove(scope, tag)
      | ("rename", [fromTag, toTag]) -> runTagsRename(scope, fromTag, toTag)
      | _ -> Result.Err(tagsUsage())
}

fun showTagsHelp(): Result String Unit effects { IO } {
  printTagsHelp();
  Result.Ok(())
}

fun showTagsCommandHelp(command: String): Result String Unit effects { IO } {
  printTagsCommandHelp(command);
  Result.Ok(())
}

fun printTagsHelp(): Unit effects { IO } {
  printLines([
    "Usage:",
    "  base tags list",
    "  base tags add <tag>",
    "  base tags remove <tag>",
    "  base tags rename <from> <to>",
  ])
}

fun printTagsCommandHelp(command: String): Unit effects { IO } {
  match command with:
    | "list" -> printLines([
      "Usage:",
      "  base tags list",
    ])
    | "add" -> printLines([
      "Usage:",
      "  base tags add <tag>",
    ])
    | "remove" -> printLines([
      "Usage:",
      "  base tags remove <tag>",
    ])
    | "rename" -> printLines([
      "Usage:",
      "  base tags rename <from> <to>",
    ])
    | _ -> printTagsHelp()
}

fun printLines(lines: List String): Unit effects { IO } {
  match lines with:
    | [] -> ()
    | [next, ...rest] -> {
        line(next);
        printLines(rest)
      }
}

fun runTagsList(scope: Scope): Result String Unit effects { IO } {
  match listGlobalTags(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tags -> {
      line("Tags");

      match tags with:
        | [] -> line("  (none)")
        | _ -> printTags(tags);

      Result.Ok(())
    }
}

fun printTags(tags: List String): Unit effects { IO } {
  match tags with:
    | [] -> ()
    | [tag, ...rest] -> {
      line(`  - ${tag}`);
      printTags(rest)
    }
}

fun runTagsAdd(scope: Scope, rawTag: String): Result String Unit effects { IO } {
  match addGlobalTag(scope, rawTag) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok tag -> {
      line(`Added tag ${tag}`);
      Result.Ok(())
    }
}

fun runTagsRemove(scope: Scope, rawTag: String): Result String Unit effects { IO } {
  match removeGlobalTag(scope, rawTag) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> {
      line(`Removed tag ${rawTag}`);
      Result.Ok(())
    }
}

fun runTagsRename(scope: Scope, fromRaw: String, toRaw: String): Result String Unit effects { IO } {
  match renameGlobalTag(scope, fromRaw, toRaw) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok normalized -> {
      line(`Renamed tag ${fromRaw} -> ${normalized}`);
      Result.Ok(())
    }
}
