from @std/Output import { line }
from @std/String import { parseIntOr }
from "./Docs" import { searchDocs }
from "./Models" import { Scope, DocSearchResult }
from "./Util" import { findOptionValue }

@public
fun runDocSearchCommand(scope: Scope, query: String, opts: List String): Result String Unit effects { IO } {
  let rawLimit = getOrElse(findOptionValue(opts, "-l", "--limit"), "5");
  let limit = max(1, parseIntOr(rawLimit, 5));

  match searchDocs(scope, query, limit) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok results ->
        printDocSearch(results);
        Result.Ok(())
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
