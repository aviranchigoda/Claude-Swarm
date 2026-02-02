# Secure Containerized Deployment Plan for HFT Trading System

## Overview
Deploy the C++23 ultra-low-latency HFT trading engine to Linode Kubernetes Engine (LKE) Sydney with comprehensive security hardening, HashiCorp Vault integration, and full audit trail compliance.

**Target:** ASX via Interactive Brokers FIX CTCI
**Latency Target:** <5ms tick-to-trade
**Infrastructure:** LKE Sydney + HashiCorp Vault

---

## 1. Container Security Hardening

### 1.1 Multi-Stage Distroless Build
Modify `docker/Dockerfile` for minimal attack surface:

```dockerfile
# Stage 1: Build (existing pattern)
FROM ubuntu:24.04 AS builder
# ... existing build steps ...

# Stage 2: Runtime (minimal image)
FROM gcr.io/distroless/cc-debian12:latest
COPY --from=builder /src/build/trade_bin /opt/trading/bin/trade_bin
COPY --from=builder /usr/lib/x86_64-linux-gnu/liburing.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libnuma.so.1 /usr/lib/x86_64-linux-gnu/
ENTRYPOINT ["/opt/trading/bin/trade_bin"]
```

### 1.2 Custom Seccomp Profile for io_uring
Create `/k8s/seccomp/hft-trading.json` with allowlist for:
- `io_uring_setup`, `io_uring_enter`, `io_uring_register`
- `mmap`, `mlock`, `mlockall`
- `sched_setaffinity`, `sched_setscheduler`
- TCP socket operations

### 1.3 Security Scanning Pipeline
- **Trivy**: Vulnerability scanning in CI
- **Grype**: Second-opinion scanner
- **TruffleHog**: Secrets detection
- **Cosign**: Image signing with keyless OIDC

---

## 2. Kubernetes Security Architecture

### 2.1 Trading Pod Security Context
```yaml
securityContext:
  capabilities:
    add: [SYS_NICE, IPC_LOCK, SYS_RESOURCE]  # Required for CPU pinning, mlock
    drop: [ALL]
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: Localhost
    localhostProfile: profiles/hft-trading.json
```

### 2.2 Dedicated Trading Node
```bash
kubectl label nodes trading-node-1 node-role.kubernetes.io/trading=true
kubectl taint nodes trading-node-1 dedicated=trading:NoSchedule
```

### 2.3 Network Policies
- **Ingress:** Allow only Prometheus metrics scraping (port 9090)
- **Egress:** Allow only:
  - IBKR FIX gateway (fix.ibkr.com:4001)
  - Vault server (port 8200)
  - DNS (port 53)

### 2.4 Guaranteed QoS Class
```yaml
resources:
  requests:
    cpu: "7000m"
    memory: "8Gi"
    hugepages-2Mi: "4Gi"
  limits:
    cpu: "7000m"      # Same as request = Guaranteed
    memory: "8Gi"
    hugepages-2Mi: "4Gi"
```

---

## 3. HashiCorp Vault Integration

### 3.1 Vault Agent Sidecar Pattern
- Init container: Load FIX credentials at startup
- Sidecar: Monitor for TLS cert rotation

### 3.2 Vault Policy
```hcl
path "secret/data/trading/fix" { capabilities = ["read"] }
path "secret/data/trading/risk" { capabilities = ["read"] }
path "pki/issue/trading-client" { capabilities = ["create", "update"] }
```

### 3.3 Kubernetes Auth
```bash
vault write auth/kubernetes/role/hft-trading \
    bound_service_account_names=hft-trading-sa \
    bound_service_account_namespaces=trading \
    policies=hft-trading-policy \
    ttl=1h
```

### 3.4 Secret Injection Template
```yaml
annotations:
  vault.hashicorp.com/agent-inject-secret-fix-credentials: 'secret/data/trading/fix'
  vault.hashicorp.com/agent-inject-template-fix-credentials: |
    {{- with secret "secret/data/trading/fix" -}}
    [fix]
    username = {{ .Data.data.username }}
    password = {{ .Data.data.password }}
    sender_comp_id = {{ .Data.data.sender_comp_id }}
    {{- end }}
```

**Note:** IBKR does NOT support dynamic credential rotation. Rotate during non-trading hours only.

---

## 4. Audit Trail Architecture

### 4.1 FIX Message Logging
- Log ALL FIX messages (35=D orders, 35=8 executions, 35=9 rejects)
- Include nanosecond timestamps
- Calculate SHA-256 hash per message for integrity

### 4.2 Tamper-Evident Chain
Each log entry includes hash of previous entry (blockchain-style).

### 4.3 Immutable Storage
- Ship logs via Fluentd to Linode Object Storage (S3-compatible)
- Enable Object Lock with Governance mode
- Retention: 7 years (regulatory requirement)

### 4.4 Indexed Fields for Compliance
- `msg_type`, `cl_ord_id`, `order_id`, `exec_id`
- `symbol`, `side`, `order_qty`, `price`
- `last_qty`, `last_px` (for fills)

---

## 5. Network Security

### 5.1 TLS Configuration
- Minimum: TLS 1.2, prefer TLS 1.3
- Cipher suites: `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`
- Client certificate if IBKR requires (via cert-manager)

### 5.2 Linode Cloud Firewall
**Inbound:**
- SSH from management IPs only
- K8s API from LKE control plane
- NodePort range cluster-internal only

**Outbound:**
- FIX gateway (port 4001) to IBKR IP only
- HTTPS (443) for Vault, container registry
- DNS, NTP

---

## 6. Low-Latency Considerations

### 6.1 Latency Impact Assessment
| Component | Impact | Mitigation |
|-----------|--------|------------|
| CNI overlay | +50-200us | Use `hostNetwork: true` |
| Container runtime | +10-50us | Acceptable |
| Service mesh | +500us-2ms | **Skip for trading pod** |

### 6.2 Node Tuning (DaemonSet)
Apply kernel parameters from `os_tuning.sh`:
- `vm.swappiness=0`
- `net.core.busy_poll=50`
- `kernel.sched_rt_runtime_us=-1`
- CPU governor: `performance`
- Reserve 2048 huge pages
- IRQ affinity to cores 0-6 (keep core 7 isolated)

### 6.3 Recommendation
For true sub-millisecond latency, consider:
- `hostNetwork: true` to bypass CNI
- Static pod (kubelet-managed) to bypass scheduler
- Or hybrid: Trading engine as systemd, K8s for supporting services

---

## 7. Monitoring & Alerting

### 7.1 Prometheus Metrics
- `hft_tick_to_trade_latency_ns` (histogram)
- `hft_loop_latency_ns` (histogram)
- `hft_daily_pnl` (gauge)
- `hft_risk_utilization` (gauge)
- `hft_fix_session_state` (gauge)

### 7.2 Critical Alerts
- **P99 tick-to-trade > 5ms**: Critical
- **Daily P&L < -$8,000**: Critical (approaching $10K limit)
- **FIX session disconnected > 30s**: Critical
- **Order reject rate > 10%**: Warning

### 7.3 Health Probes
- Liveness: Check process exists, heartbeat fresh
- Readiness: Check FIX session ACTIVE state

---

## 8. Disaster Recovery

### 8.1 Graceful Shutdown
1. Signal USR1: Stop accepting new orders
2. Wait 10s for pending orders
3. Signal TERM: Trigger FIX logout (35=5)
4. Wait 30s for session close
5. `terminationGracePeriodSeconds: 60`

### 8.2 State Recovery
- Persist `last_outgoing_seq`, `last_incoming_seq`
- On restart: Request FIX resend if needed
- Reconcile positions via IBKR Position Report

### 8.3 DR Runbook
**CRITICAL:** Never run two trading engines simultaneously - sequence number conflicts!

---

## 9. Deployment Pipeline

### 9.1 Image Signing (Cosign)
```bash
cosign sign --yes ghcr.io/your-org/hft-trading@$DIGEST
```

### 9.2 GitOps (ArgoCD)
- Auto-sync drift correction
- Manual prune (safety)
- Retry with exponential backoff

### 9.3 Admission Controllers (Kyverno)
- Verify Cosign signature before deployment
- Enforce required labels
- Restrict capabilities to allowlist

---

## Critical Files to Modify

| File | Change |
|------|--------|
| `docker/Dockerfile` | Add multi-stage distroless build |
| `config/trading.conf.example` | Add Vault template markers |
| NEW: `k8s/` directory | All Kubernetes manifests |
| NEW: `k8s/seccomp/hft-trading.json` | Custom seccomp profile |
| NEW: `vault/policy.hcl` | Vault policy for trading service |
| NEW: `.github/workflows/security.yaml` | Security scanning + signing |

---

## Verification Plan

1. **Build verification:**
   - `docker build` succeeds with distroless runtime
   - Trivy scan shows no CRITICAL/HIGH vulnerabilities
   - Cosign signature verifies

2. **Deployment verification:**
   - Pod starts with Guaranteed QoS class
   - Vault secrets inject correctly (`/vault/secrets/fix-credentials`)
   - Network policies block unauthorized egress

3. **Functional verification:**
   - FIX session establishes (35=A logon, 35=0 heartbeat)
   - Market data subscription works
   - Test order submission in paper trading mode

4. **Security verification:**
   - Cannot exec into container (distroless, no shell)
   - Cannot escalate privileges
   - Audit logs appear in object storage

5. **Latency verification:**
   - Measure tick-to-trade P99 < 5ms
   - Compare with bare-metal baseline

---

## Honest Trade-offs

**Containerization adds 50-200us latency** from CNI overhead. For true microsecond HFT, consider:
- Bare metal for trading engine
- Kubernetes for supporting services (monitoring, logging, secrets)
- Or accept the latency trade-off for operational benefits

Kubernetes adds value for: secrets management, monitoring, log aggregation, GitOps, security policies.

Bare metal may be preferable for: trading engine I/O path, kernel bypass (DPDK), NUMA optimization.
