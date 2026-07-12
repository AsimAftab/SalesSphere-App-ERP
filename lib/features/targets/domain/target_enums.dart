/// Enums for the Targets feature. Wire values are SCREAMING_SNAKE
/// (`ORDER_COUNT`, `DAILY`, `IN_PROGRESS`, `DAY`); the codecs that translate
/// them live in the data layer next to the repository, so the domain stays
/// wire-agnostic.
library;

/// What a target counts. The server sends this so the drill-down can be keyed
/// on it — never on the `rule` label, which the platform may rename.
enum TargetMetric {
  orderCount,
  orderValue,
  collectionCount,
  collectionValue,
  visitCount,
  newParty,
  newProspect,
  newSite,
}

enum TargetInterval { daily, monthly }

/// Per-period achievement, not the assignment's lifecycle — a target that
/// hasn't started or has expired simply isn't returned by the server.
enum TargetStatus { active, completed }

/// Whether the scored period still contains today. While `inProgress`, zero
/// progress is not a failure yet and must not render red.
enum TargetPeriodStatus { inProgress, closed }

/// How much of a drill-down record's `date` is real.
///
/// Orders and collections store a calendar **day** parked at UTC midnight —
/// formatting one with a clock prints the org's UTC offset, not a moment.
/// Visits and directory entries are genuine instants.
enum DatePrecision { day, instant }
