# Part 4 — Debug lab findings

I kept the terminal transcript in `part4-session.log`. Some command output
wasn't captured in the transcript, so I have only quoted output I actually
have and have not filled gaps with made-up messages.

The verifier initially reported:

```text
FAIL  backend does not answer on http://backend:8080/healthz
FAIL  gateway /status does not report backend=ok
FAIL  reporter /report does not return a pod count
4 check(s) failing, 7 passing. Keep digging — every failure is a symptom.
```

## Defect 1 — The image user needed a numeric UID

**Symptom:** The app image declares its user by the name `nonroot`. The image
account lookup returned:

```text
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
```

**Cause:** Kubernetes could not confirm the named image user was non-root
under the pod's `runAsNonRoot` setting.

**Fix:** I set `runAsUser: 65532` and kept `runAsNonRoot: true` on the
containers and migration Job.

**How I found it:** I described the pod to check its events, inspected the
image's configured user, then read the image's `/etc/passwd` to find the
numeric UID.

## Defect 2 — Service port and container port did not match

**Symptom:** The verifier printed `FAIL  backend does not answer on
http://backend:8080/healthz`.

**Cause:** The application listens on port `8081`, while the Service is
intended to be reached on port `8080`. The Service must forward `8080` to the
container's `8081`; using `8080` as the container target sends traffic to the
wrong port.

**Fix:** I set the container port and Service `targetPort` to `8081`, keeping
the backend Service port at `8080`.

**How I found it:** I compared the verifier's URL with the Service and pod
ports, then checked the image's default listening port. This is why a
port-forward to the Service uses its `8080` port, not the container's
`8081`.

## Defect 3 — Gateway pointed at the wrong backend address

**Symptom:** The verifier printed `FAIL  gateway /status does not report
backend=ok`.

**Cause:** The gateway's backend URL used a service name that did not resolve
to the backend in the lab namespace.

**Fix:** I changed `BACKEND_URL` to `http://backend:8080`, using the backend
Service's namespace-local DNS name and Service port.

**How I found it:** I checked the gateway's `/status` result, then compared
its configured backend URL with the actual Service name and port.

## Defect 4 — Metrics exceeded the namespace CPU limit

**Symptom:** The initial metrics values requested `2` CPUs and allowed up to
`4`, while the namespace LimitRange caps a container at `1` CPU.

**Cause:** Its configured CPU request and limit exceeded the environment
provided by the lab.

**Fix:** I lowered the metrics CPU request to `100m` and its limit to `500m`,
below the namespace cap.

**How I found it:** I compared the metrics resources in the chart values with
the LimitRange in `lab/cluster-state/limits.yaml`.

## Defect 5 — Worker had no writable cache directory

**Symptom:** The worker could not initialize its cache with a read-only root
filesystem. The image's diagnostic text says:

```text
the process needs a writable directory at %s (mount a volume there, or set CACHE_DIR)
```

**Cause:** The worker needs to write under `/var/cache/app`, but the chart
made the container root filesystem read-only without mounting a writable
directory there.

**Fix:** I mounted an `emptyDir` at `/var/cache/app` and set the pod's
`fsGroup` to the non-root UID so the worker can write to the volume.

**How I found it:** I checked the worker pod and its logs, then matched the
cache requirement with the read-only security setting in the template.

## Defect 6 — Migration Job used a Deployment restart policy

**Symptom:** The migration Job's pod template specified
`restartPolicy: Always`, which is invalid for a Job.

**Cause:** Job pods must use `Never` or `OnFailure`; `Always` is intended for
long-running workload controllers such as Deployments.

**Fix:** I changed the Job to `restartPolicy: Never`.

**How I found it:** I inspected the Job template and corrected the pod
restart policy before checking whether the Job completed.

## Other issue found while installing

Helm also could not take ownership of the built-in `default` ServiceAccount.
I changed the chart to create and use its own `reporter` ServiceAccount and
bound the pod-list Role to that account. The Role is limited to listing and
getting pods in the lab namespace.

## Reporter — still unresolved

The reporter remains unready, so the lab is **not all green**. Its log
contains:

```text
pod list failed: parse pod list: unexpected end of JSON input
GET /healthz -> 503
```

I checked that the reporter ServiceAccount can list pods and tested the API
request from a temporary pod using that account; the request returned HTTP
`200`. I also tried giving the reporter a writable cache, but the same JSON
error remained, so I removed that experiment. I did not find a confirmed
chart-side cause for the empty JSON the app reports. The next step would be to
compare the app's own API request with the successful test request, without
claiming the reporter is fixed.
