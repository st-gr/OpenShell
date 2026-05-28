# st-gr/OpenShell — fork notes

This is a fork of [NVIDIA/OpenShell](https://github.com/NVIDIA/OpenShell)
maintained at <https://github.com/st-gr/OpenShell>.

The fork carries one Rust patch on the `feat/external-compute-driver-socket`
branch (and, once merged, on `main`):

- **`crates/openshell-core/src/config.rs`** — adds an `External(PathBuf)`
  variant to `ComputeDriverKind` so the gateway can dispatch sandbox
  lifecycle to an out-of-process compute driver speaking the existing
  `compute_driver.proto` contract over a Unix domain socket.
- **`crates/openshell-core/src/drivers/external.rs`** (new) — a tonic
  gRPC client that connects to the configured UDS and forwards each
  `ComputeDriver` RPC.
- **`crates/openshell-server/src/cli.rs`** — adds the
  `--compute-driver-socket=PATH` CLI flag (env
  `OPENSHELL_COMPUTE_DRIVER_SOCKET`) which appends
  `ComputeDriverKind::External(path)` to the resolved driver list.

The patch is intentionally minimal so it can later be upstreamed; see the
companion [openshell-driver-kyma plan](https://github.com/st-gr/openshell-driver-kyma/blob/main/docs/superpowers/plans/2026-05-27-phase2a-gateway-fork.md)
for the full task breakdown.

## Built image

Each push to `main` and tagged release publishes
`ghcr.io/st-gr/openshell-gateway:{<sha>,<tag>,latest}`. Consumers pin
the tag matching the openshell CLI version they intend to use against
this gateway.

## Upstream sync

We rebase onto `upstream/main` regularly. When the upstream API surface
changes, follow the playbook in
[`openshell-driver-kyma/reference-openshift/docs/upstream-sync-review.md`](https://github.com/st-gr/openshell-driver-kyma/blob/main/reference-openshift/docs/upstream-sync-review.md)
which catalogs the kinds of drift to look for.
