from @std/Output import { line }
from "./Models" import { Scope }
from "./Tags" import { listGlobalTags, addGlobalTag, removeGlobalTag, renameGlobalTag }

@public
fun runTagsCommand(scope: Scope, rest: List String): Result String Unit effects { IO } {
  match rest with:
    | [] -> runTagsList(scope)
    | ["list"] -> runTagsList(scope)
    | ["add", tag] -> runTagsAdd(scope, tag)
    | ["remove", tag] -> runTagsRemove(scope, tag)
    | ["rename", fromTag, toTag] -> runTagsRename(scope, fromTag, toTag)
    | _ -> Result.Err(tagsUsage())
}

@public
fun tagsUsage(): String {
  "Usage: base tags <list|add|remove|rename> ..."
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
