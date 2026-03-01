from @std/FS import { exists, readDir, isFile, readFile, writeFile, remove, ensureDir }
from @std/List import { sort, take }
from @std/Path import { join }
from @std/String import { endsWith, toLowerCase, trimEnd }
from "./Models" import { Scope, DocSearchResult }
from "./Store" import { touchMeta }
from "./Util" import { normalizeDocName, normalizedExcerpt, fuzzyDocScore }

@public
fun listDocs(scope: Scope): Result String (List String) effects { IO } {
  if !exists(scope.docsDir):
    Result.Ok([])
  else:
    match readDir(scope.docsDir) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok names -> match keepMarkdownFiles(scope.docsDir, names, []) with:
        | Result.Err e -> Result.Err(e)
        | Result.Ok docs -> Result.Ok(sortDocNames(docs))
}

fun keepMarkdownFiles(
  docsDir: String,
  names: List String,
  acc: List String
): Result String (List String) effects { IO } {
  match names with:
    | [] -> Result.Ok(acc)
    | [name, ...rest] ->
        let nextPath = join(docsDir, name);
        let shouldInclude = endsWith(toLowerCase(name), ".md") and isFile(nextPath);

        let nextAcc = if shouldInclude:
          acc & [name]
        else:
          acc;

        keepMarkdownFiles(docsDir, rest, nextAcc)
}

fun sortDocNames(names: List String): List String {
  sort(names, (left, right) => {
    if left < right:
      -1
    elif left > right:
      1
    else:
      0
  })
}

@public
fun showDoc(scope: Scope, rawName: String): Result String String effects { IO } {
  let name = normalizeDocName(rawName);
  let docPath = join(scope.docsDir, name);

  if !exists(docPath):
    Result.Err(`Document not found: ${name}`)
  else:
    readFile(docPath)
}

@public
fun addDoc(scope: Scope, rawName: String, content: String): Result String String effects { IO } {
  let name = normalizeDocName(rawName);
  let docPath = join(scope.docsDir, name);

  if exists(docPath):
    Result.Err(`Document already exists: ${name}`)
  else:
    match ensureDir(scope.docsDir) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok _ -> writeNewDoc(scope, name, docPath, content)
}

@public
fun updateDoc(scope: Scope, rawName: String, content: String): Result String String effects { IO } {
  let name = normalizeDocName(rawName);
  let docPath = join(scope.docsDir, name);

  if !exists(docPath):
    Result.Err(`Document not found: ${name}`)
  else:
    writeUpdatedDoc(scope, name, docPath, content)
}

@public
fun removeDoc(scope: Scope, rawName: String): Result String Unit effects { IO } {
  let name = normalizeDocName(rawName);
  let docPath = join(scope.docsDir, name);

  if !exists(docPath):
    Result.Err(`Document not found: ${name}`)
  else:
    match remove(docPath) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok _ -> touchMeta(scope)
}

fun writeNewDoc(
  scope: Scope,
  name: String,
  path: String,
  content: String
): Result String String effects { IO } {
  match writeFile(path, ensureTrailingNewline(content)) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> finishDocWrite(scope, name)
}

fun writeUpdatedDoc(
  scope: Scope,
  name: String,
  path: String,
  content: String
): Result String String effects { IO } {
  match writeFile(path, ensureTrailingNewline(content)) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> finishDocWrite(scope, name)
}

fun finishDocWrite(scope: Scope, name: String): Result String String effects { IO } {
  match touchMeta(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok _ -> Result.Ok(name)
}

@public
fun searchDocs(
  scope: Scope,
  query: String,
  limit: Int
): Result String (List DocSearchResult) effects { IO } {
  match listDocs(scope) with:
    | Result.Err e -> Result.Err(e)
    | Result.Ok names -> match scoreDocs(scope, names, query, []) with:
      | Result.Err e -> Result.Err(e)
      | Result.Ok scored ->
          let ordered = sortResults(scored);

          Result.Ok(takeLimit(ordered, limit))
}

fun scoreDocs(
  scope: Scope,
  names: List String,
  query: String,
  acc: List DocSearchResult
): Result String (List DocSearchResult) effects { IO } {
  match names with:
    | [] -> Result.Ok(acc)
    | [name, ...rest] ->
        let path = join(scope.docsDir, name);

        match readFile(path) with:
          | Result.Err e -> Result.Err(e)
          | Result.Ok content ->
              let score = fuzzyDocScore(query, name, content);
              let excerpt = normalizedExcerpt(content, 140);

              let nextAcc = if score > 0:
                acc & [{ name, score, excerpt }]
              else:
                acc;

              scoreDocs(scope, rest, query, nextAcc)
}

fun sortResults(results: List DocSearchResult): List DocSearchResult {
  sort(results, (left, right) => {
    if left.score > right.score:
      -1
    elif left.score < right.score:
      1
    elif left.name < right.name:
      -1
    elif left.name > right.name:
      1
    else:
      0
  })
}

fun takeLimit(results: List DocSearchResult, limit: Int): List DocSearchResult {
  if limit <= 0:
    []
  else:
    take(results, limit)
}

fun ensureTrailingNewline(content: String): String {
  let trimmed = trimEnd(content);

  `${trimmed}
`
}
