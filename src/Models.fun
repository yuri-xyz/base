@public
type alias Scope = {
  cwd: String,
  repoRoot: String,
  repoName: String,
  repoSource: String,
  projectKey: String,
  isGitRepo: Bool,
  storageRoot: String,
  projectsDir: String,
  projectDir: String,
  metaPath: String,
  tasksPath: String,
  roadmapPath: String,
  plansPath: String,
  docsDir: String
}

@public
type alias ProjectMeta = { version: Int, projectKey: String, repoName: String, repoRoot: String, repoSource: String, createdAt: String, updatedAt: String }

@public
type alias Task = { id: String, title: String, description: String, status: String, tags: List String, createdAt: String, updatedAt: String }

@public
type alias TaskPatch = { title: Option String, description: Option String, status: Option String, tags: Option (List String) }

@public
type alias DocSearchResult = { name: String, score: Int, excerpt: String }

@public
type alias RoadmapItem = { id: String, goal: String, description: String, status: String, order: Int, completedAt: Option String, createdAt: String, updatedAt: String }

@public
type alias RoadmapPatch = { goal: Option String, description: Option String, status: Option String }

@public
type alias Plan = {
  id: String,
  title: String,
  description: String,
  status: String,
  completedAt: Option String,
  items: List PlanItem,
  createdAt: String,
  updatedAt: String
}

@public
type alias PlanPatch = { title: Option String, description: Option String, status: Option String }

@public
type alias PlanItem = {
  id: String,
  title: String,
  description: String,
  status: String,
  order: Int,
  completedAt: Option String,
  createdAt: String,
  updatedAt: String
}

@public
type alias PlanItemPatch = { title: Option String, description: Option String, status: Option String }

@public
fun storeVersion(): Int {
  1
}
