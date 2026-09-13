# Timing Run: Instrumented Transfer

## Run Meta

| Field           | Value                                            |
|-----------------|--------------------------------------------------|
| Date            | 2026-09-06                                       |
| Worker          | cursor-agent 2026.09.02-c22c1a3                   |
| Prompt          | "What host am I running on?"                      |
| Network         | 4G cellular                                       |
| Plugin state    | 6948 .installed absent, tar.gz on disk (51 MB)    |

## Timestamps (UTC)

| Event                       | UTC                  | Source                          |
|-----------------------------|----------------------|---------------------------------|
| Worker claimed              | 23:05:25.823         | Debug log Agent Store warn       |
| Read 6948 .installed        | 23:05:28.224         | ENOENT                          |
| FRAME_START (first byte)    | 23:04:37.599         | bridge-trace.log                |
| FRAME_END (last byte)       | 23:10:05.204         | bridge-trace.log                |
| Bridge connection closed    | 23:10:05.367         | sessionDurationMs: 358421       |
| Reconnect claims            | 23:10:10.912+        | Multiple Agent Store warns      |

## Deltas

| Delta                            | Seconds |
|----------------------------------|---------|
| FRAME_START to FRAME_END         | 357.6   |
| Claim to FRAME_END               | 279.4   |
| FRAME_END to bridge close        | 0.16    |
| Claim to first tool call         | ~295    |

## Transfer Rate

53,359,696 bytes / 357.6 s = 149,218 B/s = 143 KB/s = 1.1 Mbps

## After the Transfer

| Check                        | Result                                               |
|------------------------------|------------------------------------------------------|
| tar -xzf for 6948 executed?  | No (extract dir empty)                               |
| 6948 .installed created?     | No                                                    |
| Agent answered prompt?       | Yes (after reconnect)                                |
| Tar md5 after rewrite        | aadfc7fd64bd19f6b302c3f5df7bebb9 (identical to orig) |
