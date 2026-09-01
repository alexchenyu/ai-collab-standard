# Project Status Snapshot

> Last updated: YYYY-MM-DD

Current deployment state, data scale, ports, and resource usage. Refresh regularly;
stable selections (tech stack, architecture principles) belong in `CLAUDE.md`;
deployment steps and runbooks belong in `docs/DEPLOYMENT.md`.

## Usage rules

- This file records **state that changes periodically** (versions, data scale,
  ports, instance counts, capacity), not stable selections.
- Expected refresh cadence ≥ once per 2 weeks; untouched for 4+ weeks means you
  wrote a stable rule here — move it out.
- On conflict this file wins — `CLAUDE.md` should contain no concrete numbers
  that can go stale.

## Deployment status

Must answer (delete this hint when filling in): which services are live? For each:
current version / instance count / ports?

| Service | Status | Version / Instances | Ports |
| ------- | ------ | ------------------- | ----- |

## Data scale

Must answer: what data scale is committed externally? What is the actual scale?
When was the last full update / backfill?

| Source | Type | Scale | Last updated |
| ------ | ---- | ----- | ------------ |

## Hardware / resources

Must answer: which machine hosts each important component? GPU/CPU allocation?

| Component | Machine | Resources | Purpose |
| --------- | ------- | --------- | ------- |

## Known capacity / rate limits

Must answer: any known capacity bottlenecks? External-service rate limits?

- TODO: if there is no known bottleneck, write "no known bottleneck" explicitly;
  don't delete this section.

## Update requirements

Update on data import, instance changes, port changes, component migration.
Changes to stable selections (vector DB, LLM swap) go to `CLAUDE.md`, not here.