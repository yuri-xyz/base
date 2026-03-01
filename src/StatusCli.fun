from "./Util" import { normalizeStatus, normalizeRoadmapStatus }

@public
fun normalizeStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizeStatus(raw) with:
      | Option.None -> Result.Err(`Invalid status: ${raw}. Use todo | in_progress | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}

@public
fun normalizeRoadmapStatusOption(statusRawOpt: Option String): Result String (Option String) {
  match statusRawOpt with:
    | Option.None -> Result.Ok(Option.None)
    | Option.Some raw -> match normalizeRoadmapStatus(raw) with:
      | Option.None -> Result.Err(`Invalid roadmap status: ${raw}. Use planned | active | done`)
      | Option.Some status -> Result.Ok(Option.Some(status))
}
