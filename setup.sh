
#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER="demo"
IMAGE="demo-app:0.1.0"
RELEASE="demo"
NAMESPACE="demo"

INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/kind/deploy.yaml"

# Check prerequisites.
for cmd in docker kind kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command '$cmd' is not installed or not in PATH." >&2
    exit 1
  fi
done

# Create the kind cluster if it does not already exist.
if ! kind get clusters | grep -qx "$CLUSTER"; then
  CONFIG="$(mktemp)"

  trap 'rm -f "${CONFIG:-}"' EXIT

  cat > "$CONFIG" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

  kind create cluster --name "$CLUSTER" --config "$CONFIG"
  rm -f "$CONFIG"
  trap - EXIT
fi

# Configure kubectl.
kubectl config use-context "kind-$CLUSTER"
kubectl cluster-info

# Ensure the existing single-node cluster has the ingress label.
kubectl label node "${CLUSTER}-control-plane" \
  ingress-ready=true --overwrite

# Permit local workloads on the control-plane node.
# This is for this single-node local development cluster only.
if kubectl get node "${CLUSTER}-control-plane" -o json |
   grep -q '"key": "node-role.kubernetes.io/control-plane"'; then
  kubectl taint nodes "${CLUSTER}-control-plane" \
    node-role.kubernetes.io/control-plane:NoSchedule- || true
fi

# Install ingress-nginx.
kubectl apply -f "$INGRESS_MANIFEST"

# Wait for the controller Deployment to become available.
kubectl rollout status deployment/ingress-nginx-controller \
  --namespace ingress-nginx \
  --timeout=180s

# Build the application image.
docker build -t "$IMAGE" ./service

# Load the image into kind.
kind load docker-image "$IMAGE" --name "$CLUSTER"

# Install or upgrade the application.
helm upgrade --install "$RELEASE" ./chart \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --wait \
  --timeout 180s

# Verify the application rollout.
kubectl rollout status deployment/demo \
  --namespace "$NAMESPACE" \
  --timeout=180s

kubectl get pods,svc,ingress -n "$NAMESPACE"

echo "Setup completed successfully."