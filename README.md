# DevOps 

This repository builds a small Flask service, packages it as a Docker image,
and deploys it to a local Kubernetes cluster with Helm. 

## Run the application

You need Docker, kind, kubectl, Helm, and Bash. On Windows, run the commands
from Git Bash. From the repository root:

```bash
./setup.sh
kubectl get pods -n demo
curl --resolve demo.local:80:127.0.0.1 http://demo.local/
curl --resolve demo.local:80:127.0.0.1 http://demo.local/healthz
```

The first response includes the configured app name, version, and pod name.
The health endpoint should return HTTP 200. In PowerShell, use `curl.exe`
instead of `curl` in those two commands.

`setup.sh` creates or reuses the `demo` kind cluster, installs ingress-nginx,
builds and loads the image, then installs the Helm release into the `demo`
namespace. The chart in `chart/` creates:

- A Deployment with two replicas by default and liveness/readiness probes.
- A ConfigMap for `APP_NAME` and `VERSION`.
- A ClusterIP Service and an Ingress for `demo.local`.

The values are in `chart/values.yaml`, so they can be changed without editing
the templates. Helm renders those templates and tracks the resulting resources
as a release; `setup.sh` uses `helm upgrade --install` so it can be run again.

## Resource sizes and trade-offs

The app requests `100m` CPU and `64Mi` memory, with limits of `500m` CPU and
`256Mi` memory. It is a small Flask service, so these are modest starting
values: requests give the scheduler a baseline, while limits put a ceiling on
resource use. They should be checked against real usage before production.

## Debug lab status

From the repository root, start and check the lab with:

```bash
cd lab
./scenario.sh up
./scenario.sh verify
```

The chart fixes cover the numeric non-root UID, the image's port (`8081`)
behind the backend Service's port (`8080`), the gateway's backend URL, the
worker's writable cache, the metrics CPU limit, the migration Job restart
policy, and the reporter ServiceAccount/RBAC setup. The chart passes
`helm lint`, but the lab is **not fully green**: the reporter remains
unready. Its logs show `pod list failed: parse pod list: unexpected end of
JSON input`, and `/healthz` returns 503. I checked its ServiceAccount
permissions and tested listing pods through the Kubernetes API; that request
returned HTTP 200. A writable-cache experiment did not fix the reporter, so
I removed that experiment instead of presenting it as a solution. The actual
reporter failure is still unresolved.

The terminal transcript is in `lab/part4-session.log`. The lab is not part of
the normal `demo` application setup.


## How I used AI

I used Copilot in VS Code to help review the repo, explain Helm/Kubernetes
behaviour, and troubleshoot the lab. I ran the commands against my local
cluster and checked the results rather than treating suggestions as proof.
One thing I had to correct was the reporter cache suggestion: mounting a
writable cache did not fix the JSON parsing failure, so I backed that
experiment out. The reporter issue is documented as unresolved; I am not
claiming the lab passes.
