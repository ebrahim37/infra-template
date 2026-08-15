vps1/services/rootless/rybbit/update-rybbit/SKILL.md
---
name: update-rybbit
description: Update the Rybbit Podman Quadlets in the parent directory from their pinned version to the latest stable GitHub release. Use when asked to upgrade, refresh, or compare this self-hosted Rybbit deployment.
---

# Update Rybbit

1. Read the current tag from `Image=ghcr.io/rybbit-io/rybbit-{backend,client}:vX.Y.Z`; stop if the two tags disagree.
2. Get `tag_name` from `https://api.github.com/repos/rybbit-io/rybbit/releases/latest` and keep the exact `vX.Y.Z` tag rather than `latest`.
3. Fetch and diff `https://raw.githubusercontent.com/rybbit-io/rybbit/refs/tags/<tag>/docker-compose.yml` for the current and target tags.
4. Map every relevant Compose change into the existing Quadlets, including supporting image pins, environment, commands, health checks, dependencies, and ClickHouse configs. Preserve local ports, paths, secrets, rootless networking, and other intentional adaptations.
5. Report changes made.
