# Demo 00: project tour and cost contract

## Audience outcome

Attendees understand the project, know which models they will edit, start the development-schema build immediately, and agree on what counts as credible cost-optimization evidence.

## Timing and interaction

- **Current planning budget:** 12 minutes; validate during the dry run.
- **Mode:** facilitator walkthrough while the opening build runs.
- **Attendee artifact:** a fully built starter project in each developer schema and a recorded opening runtime.

## Setup and prerequisites

- Every attendee can access the dbt project and a personal development schema.
- Trainer-managed Snowflake source relations are available.
- `dbt parse --no-partial-parse` has passed in trainer preflight.
- The attendee exclusion has been verified:

```text
dbt ls --select path:models/answer_key --exclude tag:optimized
```

- A completed trainer schema is available as a fallback if an attendee build is delayed.

## Workshop contract

State these expectations before introducing individual models:

1. Attendees edit the starter models in `models/intermediate/` and `models/marts/`.
2. `models/answer_key/` is a trainer reference and take-home resource. It is not inspected or built during the live labs.
3. The room runs exactly two full builds: one now and one during Demo 06.
4. Every intermediate validation uses a targeted build or focal-model full refresh.
5. No source ingestion runs live.
6. Only one representative consumption query runs before/after for each of the clustering and dimension-persistence demos.
7. Only the dbt State/model-reuse job is triggered live.
8. Cleaner SQL is not proof of lower cost; every module needs execution evidence.

## Facilitator flow

### 1. Start the opening build immediately — 2 minutes

Have attendees confirm their target and developer schema, then run:

```text
dbt build --exclude tag:optimized
```

Ask them to record the final elapsed time when it completes. Do not pause the orientation while builds run.

Call out that the exclusion is required because optimized trainer/take-home models are enabled in the repository for stable benchmark generation.

### 2. Tour the project — 4 minutes

Show the project at a high level:

- `models/staging/`: shared source cleanup and typing;
- `models/intermediate/`: reusable transformations and the exploding-join exercise;
- `models/marts/`: the attendee workshop models;
- `analyses/`: workload generators used to build query history;
- `training_assets/`: trainer scripts and facilitator plans; and
- `models/answer_key/`: after-workshop reference only.

Explain the shared-source/personal-schema model: everyone reads the same raw data while building isolated development relations.

### 3. Introduce the cost framework — 4 minutes

Use the same sequence in every module:

1. symptom;
2. diagnosis;
3. fix; and
4. prevention.

Name the evidence surfaces attendees will see:

- build elapsed time;
- bytes scanned;
- rows entering and leaving joins;
- partitions scanned and pruning;
- rows written or merged;
- repeated-query frequency; and
- warehouse credits where available.

Explain that optimizations can shift cost between producers and consumers. A table or clustered relation may cost more to write while reducing cost across many reads.

### 4. Preview the complexity ramp — 2 minutes

- Clustering: trainer-led diagnosis and follow-along config.
- Persistence: quick materialization change.
- Incremental: individual config work based on ingestion evidence.
- Join health: independent SQL fix.
- Refactor: open-ended Jira-style lab.
- Jobs: follow-along dbt State demo and wrap-up.

## Decision checkpoint

Ask:

> If total project runtime goes down, is that enough evidence that the optimization paid off?

Expected answer: no. Whole-project runtime must be paired with focal-model, consumption-query, frequency, and credit evidence.

## Evidence to capture

- attendee opening-build elapsed time;
- selected node and test counts if useful;
- warehouse size and thread count; and
- any schemas that need fallback support.

The current trainer benchmark is 3:13 for the starter build and 2:46 for the optimized benchmark: a 27-second or 14.0% reduction. Keep this as context for the closing discussion, not as the sole workshop ROI claim.

## Common failures and recovery

- **Wrong schema or target:** stop the attendee before relations are created in a shared schema; correct the target and restart.
- **Answer-key models appear:** confirm the command includes `--exclude tag:optimized`.
- **Build runs long:** continue the walkthrough and pair the attendee with the completed trainer schema for Demo 01.
- **Source relation missing:** move the attendee to the trainer fallback relation or schema rather than reseeding during the session.

## Transition

Move directly into a visible, low-code win:

> We have the baseline building. Let’s start with a physical-design change that comes from observed workload, not intuition.
