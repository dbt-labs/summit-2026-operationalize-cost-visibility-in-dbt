# Workshop delivery plan and remaining work

This file tracks the current seven-demo plan. Earlier sequence and live-ingestion assumptions have been retired.

## Current projected demo sequence

These values are current-state planning budgets. They are not actual delivery times or commitments. Measure each segment during the dry run, then cut, combine, or shorten material where needed to protect the overall workshop schedule.

| File | Demo | Mode | Planning budget |
|---|---|---|---:|
| `00_project_tour_and_cost_contract.md` | Project tour, evidence framework, and opening developer build | Facilitator walkthrough | 12 min |
| `01_cluster_order_items_from_workload.md` | Find clustering candidates from workload and improve pruning | Follow-along demo | 20 min |
| `02_persist_reused_wizard_dimension.md` | Persist a frequently consumed dimension | Short guided change | 15 min |
| `03_process_changed_orders_incrementally.md` | Match merge incremental processing to observed ingestion | Guided diagnosis plus 5–10 min individual work | 25 min |
| `04_fix_exploding_order_join.md` | Align line-item and payment grains before joining | Independent fix and debrief | 20 min |
| `05_refactor_customer_behavior_mart.md` | Resolve a Jira-style mixed-grain mart refactor ticket | Main independent lab | 35 min |
| `06_optimize_jobs_and_test_scope.md` | Explain dbt State, job/test scope, and environment hygiene | Follow-along jobs demo and wrap-up | 20 min |

Current projected content time: approximately 2 hours 27 minutes before a break or open discussion. Rebaseline after the dry run.

## Attendee operating model

- Attendees work in the starter models and build assets together during the workshop.
- `models/answer_key/` is a trainer reference and take-home resource. Attendees do not inspect or build it live.
- Use `dbt build --exclude tag:optimized` for attendee full builds.
- Run exactly two full builds: once at the beginning of Demo 00 and once at the end of Demo 06.
- Use targeted builds or focal-model full refreshes between them.
- Start the opening build immediately so it completes during workshop orientation.
- Do not run live source ingestion or reset the incremental baseline.
- Use screenshots for incremental before/after build timing.
- Run one `fct_order_items` consumption query before/after and one `dim_wizards` consumption query before/after. The remaining analyses generate query history before the workshop.
- Trigger only the dbt State/model-reuse job live. Present all other job comparisons from prepared runs.

## Narrative progression

1. **Clustering:** trainers demonstrate diagnosis and a small physical-config change.
2. **Persistence:** attendees make a quick, low-risk materialization decision.
3. **Incremental:** attendees interpret ingestion behavior and independently add merge config.
4. **Join grain:** trainers frame the symptom; attendees own the SQL fix.
5. **Refactor:** attendees solve an open-ended Jira ticket and defend their architecture.
6. **Jobs:** trainers return to a follow-along format, explain dbt State, and close the cost story.

The join demo intentionally sits immediately before the refactor. Demo 05 should refer back to native-grain alignment without reteaching Demo 04.

## Cost framing

Current full-build benchmark:

- starter: 3:13 / 193 seconds;
- optimized: 2:46 / 166 seconds;
- savings: 27 seconds / 14.0%.

A linear 30-minute illustration becomes approximately 25:48, saving 4:12 per run. Treat this as an illustration only.

The workshop ROI needs multiple evidence surfaces:

- full-build elapsed time;
- focal-model build time and bytes written;
- recurring incremental versus full-refresh work;
- consumption-query scans and pruning;
- repeated view recomputation;
- rows entering expensive joins; and
- annualized frequency and warehouse credits.

Clustering and dimension persistence may add producer-side work while saving much more across repeated consumption. Shared upstream models and tests also dilute whole-project elapsed-time improvements.

## Teaching emphasis

- Contracts and tests are supporting controls, not the main workshop topic.
- Explain how weak grain validation and missing assumptions can allow fanout, excess scans, and write amplification to survive.
- For incremental strategy, start from observed arrival cadence, update behavior, stable grain, and changed-row ratio.
- Discuss Snowflake strategy tradeoffs and why `merge` fits new plus historically updated `order_id`s.
- For clustering, show trainer automation for finding candidate keys, then validate candidates against actual query history and pruning evidence.
- For the refactor, provide symptoms, constraints, required outputs, and evidence expectations as a Jira-style ticket rather than prescribing the implementation.

## Evidence to prepare

### Demo 00

- clean attendee-schema opening build timing;
- repository map and development-schema instructions;
- fallback relation for anyone whose build is delayed.

### Demo 01

- accumulated history from all five `fct_order_items` analyses;
- one representative live before/after query;
- query profiles showing partitions and bytes scanned;
- clustering candidate automation output;
- clustering write/reclustering cost note.

### Demo 02

- accumulated history from all five `dim_wizards` analyses;
- one representative live before/after consumer query;
- profile showing view recomputation versus persisted read.

### Demo 03

- historical ingestion cadence;
- changed-row ratio and late-update examples;
- full-table bytes scanned/written;
- merge-incremental before/after screenshots;
- Snowflake incremental-strategy comparison.

### Demo 04

- profile showing line-item × payment row expansion;
- expected order-grain row counts and metric checks;
- targeted downstream build timing.

### Demo 05

- finalized Jira-style ticket;
- expected public columns and customer grain;
- targeted build evidence for starter and trainer-reference designs;
- annualized savings calculation template;
- two or three acceptable design variations for debrief.

### Demo 06

- one live-ready dbt State/model-reuse job;
- saved CI before/after runs;
- saved benchmark and test-scope runs;
- job configuration screenshots;
- opening-versus-closing attendee build comparison template.

## Remaining tasks

1. Rehearse the seven modules end to end under workshop timing.
2. Automate recurring execution of all ten analysis queries to build query history.
3. Rehearse `04_weekly_orders_change_batch.sql` for trainer evidence generation only.
4. Capture stable benchmark profiles, run artifacts, and fallback screenshots.
5. Finalize the incremental-strategy comparison for Snowflake.
6. Write the Jira-style customer behavior refactor ticket and acceptance criteria.
7. Create the workshop-account jobs and record their IDs and UI paths.
8. Validate the attendee exclusion command after any future tag changes.
9. Review all facilitator outlines as one narrative before slide production.
