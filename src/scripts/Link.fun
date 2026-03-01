from @std/Output import { line, errLine }
from @std/FS import { ensureDir, writeFile }
from @std/Path import { join }
from @std/Process import { cwd, env, execArgs, execArgsInDir, exit }
from @std/String import { trim, contains }

@main
fun main(): Unit effects { IO } {
  let startDir = cwd();
  let root = resolveProjectRoot(startDir);
  installGlobalLauncher(root)
}

fun resolveProjectRoot(startDir: String): String effects { IO } {
  match execArgsInDir("git", ["rev-parse", "--show-toplevel"], startDir) with:
    | Result.Err _ -> startDir
    | Result.Ok result -> if result.exitCode == 0: {
      let resolved = trim(result.stdout);
      if resolved == "": startDir else: resolved
    }
    else: {
      (startDir)
    }
}

fun installGlobalLauncher(root: String): Unit effects { IO } {
  let binDir = resolveGlobalBinDir(root);

  match ensureDir(binDir) with:
    | Result.Err e -> fail("Could not create global bin directory ${binDir}: ${e}")
    | Result.Ok _ -> writeLauncher(root, binDir)
}

fun writeLauncher(root: String, binDir: String): Unit effects { IO } {
  let launcherPath = join(binDir, "base");
  let launcherBody = launcherScriptBody(root);

  match writeFile(launcherPath, launcherBody) with:
    | Result.Err e -> fail("Could not write launcher ${launcherPath}: ${e}")
    | Result.Ok _ -> makeExecutable(binDir, launcherPath)
}

fun makeExecutable(binDir: String, launcherPath: String): Unit effects { IO } {
  match execArgs("chmod", ["+x", launcherPath]) with:
    | Result.Err e -> fail("Failed to run chmod for ${launcherPath}: ${e}")
    | Result.Ok result -> if result.exitCode != 0: {
      fail("chmod failed for ${launcherPath}: ${result.stderr}")
    }
    else: {
      line("Global launcher installed: ${launcherPath}");
      printPathHint(binDir)
    }
}

fun printPathHint(binDir: String): Unit effects { IO } {
  let pathValue = env("PATH");
  let visible = contains(pathValue, binDir);

  if visible: {
    line("`base` is available globally")
  }
  else: {
    line("Add ${binDir} to PATH to use `base` globally")
  }
}

fun resolveGlobalBinDir(root: String): String effects { IO } {
  let configured = trim(env("BASE_BIN_DIR"));

  if configured != "": {
    (configured)
  }
  else: {
    let home = trim(env("HOME"));

    if home != "": {
      let localDir = join(home, ".local");
      join(localDir, "bin")
    }
    else: {
      join(root, "bin")
    }
  }
}

fun launcherScriptBody(root: String): String {
  let target = join(root, "src/main.fun");

  "#!/usr/bin/env bash\nset -euo pipefail\nexec funk run \"${target}\" -- \"$@\"\n"
}

fun fail(message: String): Unit effects { IO } {
  errLine("Error: ${message}");
  exit(1)
}
