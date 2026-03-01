from @std/Crypto import { sha256 }
from @std/Path import { basename, join, resolve }
from @std/Process import { cwd, env, execArgsInDir }
from @std/String import { trim, take }
from "./Models" import { Scope }
from "./Util" import { slugify }

@public
fun resolveScope(useGlobal: Bool): Scope effects { IO } {
  let currentDir = cwd();
  let root = getOrElse(runGit(currentDir, ["rev-parse", "--show-toplevel"]), currentDir);
  let gitState = getOrElse(runGit(currentDir, ["rev-parse", "--is-inside-work-tree"]), "false");
  let isGitRepo = gitState == "true";
  let resolvedRoot = resolve(root);
  let repoName = basename(root);
  let repoSource = getOrElse(runGit(root, ["config", "--get", "remote.origin.url"]), resolvedRoot);
  let keyHash = hashPrefix12(repoSource);
  let safeRepoName = slugify(repoName);
  let projectKey = `${safeRepoName}-${keyHash}`;
  let storageRoot = resolveStorageRoot(currentDir, resolvedRoot, useGlobal);
  let projectsDir = resolveProjectsDir(storageRoot, useGlobal);
  let projectDir = resolveProjectDir(storageRoot, projectsDir, projectKey, useGlobal);

  {
    cwd: resolve(currentDir),
    repoRoot: resolvedRoot,
    repoName,
    repoSource,
    projectKey,
    isGitRepo,
    storageRoot,
    projectsDir,
    projectDir,
    metaPath: join(projectDir, "meta.json"),
    tasksPath: join(projectDir, "tasks.json"),
    roadmapPath: join(projectDir, "roadmap.json"),
    plansPath: join(projectDir, "plans.json"),
    docsDir: join(projectDir, "docs"),
  }
}

fun runGit(dir: String, args: List String): Option String effects { IO } {
  match execArgsInDir("git", args, dir) with:
    | Result.Err _ -> Option.None
    | Result.Ok output -> if output.exitCode == 0:
      let cleaned = trim(output.stdout);

      if cleaned == "": Option.None else: Option.Some(cleaned)
    else:
      Option.None
}

fun resolveStorageRoot(currentDir: String, repoRoot: String, useGlobal: Bool): String effects { IO } {
  let configured = trim(env("BASE_HOME"));

  if configured != "":
    configured
  elif useGlobal:
    let home = resolveHomeDir(currentDir);

    join(home, ".base")
  else:
    join(repoRoot, ".base")
}

fun resolveProjectsDir(storageRoot: String, useGlobal: Bool): String {
  if useGlobal:
    join(storageRoot, "projects")
  else:
    storageRoot
}

fun resolveProjectDir(storageRoot: String, projectsDir: String, projectKey: String, useGlobal: Bool): String {
  if useGlobal:
    join(projectsDir, projectKey)
  else:
    storageRoot
}

fun resolveHomeDir(currentDir: String): String effects { IO } {
  let home = trim(env("HOME"));

  if home != "":
    home
  else:
    let profile = trim(env("USERPROFILE"));

    if profile != "": profile else: currentDir
}

fun hashPrefix12(value: String): String {
  take(sha256(value), 12)
}
