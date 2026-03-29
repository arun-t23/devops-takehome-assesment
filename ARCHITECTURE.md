# RoboshopDev: Infrastructure Architecture & Migration Proposal

## Executive Summary

This document outlines the re-architecture of a manual EC2/RDS deployment into a scalable, observable, and automated platform. The proposal addresses performance spikes, database bottlenecks, manual deployments, and operational visibility through a phased 6-12 month migration strategy.

**Key Outcomes:**
- **Zero-downtime deployments** via CI/CD with blue-green strategy
- **Auto-scaling** to handle 5x load spikes without slowdown
- **Fixed outbound IP** for partner integrations via NAT Gateway
- **Centralized observability** for logs, metrics, and distributed tracing
- **Database scalability** through RDS read replicas, connection pooling, and async processing
- **Cost-efficient** with mixed on-demand and spot instances

---

## Current State Analysis

### Existing Pain Points
1. **Manual Deployments**: SSH-based deployments = human error, slow, version tracking issues
2. **Single Application Instance**: No redundancy; one bad deploy = downtime
3. **Database Performance**: All writes to single RDS instance; high I/O spikes cause slowness
4. **Memory/Swap Thrashing**: Insufficient instance capacity during peaks; no auto-scaling
5. **Zero Observability**: No central logs, minimal metrics, no tracing; hard to debug issues
6. **No IP Whitelisting Support**: Dynamic IP from EC2 breaks partner integrations
7. **Security Gaps**: No secrets management, IAM underutilized, network not segmented

### Current Architecture (Sketch)
```
Manual SSH Deployments
        ↓
Single EC2 Instance (React frontend + Python backend)
        ↓
RDS PostgreSQL (single writer, no replicas)
        ↓
S3 (static assets)
```

---

## Proposed Architecture (Target State)

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│  Load Balancing & Security                                      │
│  - CloudFront (CDN for frontend)                               │
│  - ALB (Application Load Balancer for backend)                 │
│  - WAF (optional, future enhancement)                          │
└─────────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│  Compute Layer (Auto-scaling)                                   │
│  - ECS Fargate for microservices (frontend + backend)          │
│  - Auto Scaling Group: min=2, target=4, max=10 (during peaks) │
│  - Spot instances (70%) + On-demand (30%) for cost savings     │
└─────────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│  Data & Cache Layer                                             │
│  - RDS PostgreSQL (Multi-AZ for HA)                            │
│  - Read Replicas (for reporting/analytics)                     │
│  - ElastiCache Redis (connection pooling, caching)             │
│  - S3 (static content + backups)                               │
└─────────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│  Network & Security                                             │
│  - VPC with public/private/DB subnets (already in place)       │
│  - NAT Gateway (fixed outbound IP for partner APIs)            │
│  - Security Groups (segmented by component)                    │
│  - Secrets Manager (API keys, DB passwords)                    │
└─────────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│  CI/CD & Deployment                                             │
│  - GitHub Actions (build → test → deploy stages)               │
│  - ECR (Docker image registry)                                 │
│  - Blue-Green Deployment (instant rollback capability)         │
└─────────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│  Observability                                                  │
│  - CloudWatch Logs (centralized logging)                       │
│  - CloudWatch Metrics (auto-scaling metrics, custom business)  │
│  - X-Ray (distributed tracing)                                 │
│  - CloudWatch Alarms (triggers for on-call team)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phased Migration Plan (6-12 Months)

### Phase 1: Foundation (Months 1-3) - **PRIORITY**
**Goal**: Build CI/CD foundation, containerize app, add observability

**Tasks**:
1. **Containerization**
   - Create Dockerfile for React frontend (multi-stage build)
   - Create Dockerfile for Python backend (with optimized layers)
   - Push to Amazon ECR
   - *Why*: Enables consistent deployments across environments; eliminates "works on my machine" problems

2. **CI/CD Pipeline**
   - GitHub Actions workflow: `push → build image → run unit tests → push to ECR → manual approval`
   - Separate workflows for staging vs. production
   - *Why*: Eliminates manual SSH deployments; enables code review gates; instant rollback

3. **ECS Fargate Setup**
   - Create task definitions for frontend & backend containers
   - Deploy to single AZ initially (reduce complexity)
   - ALB in front of ECS tasks
   - *Why*: Serverless containers = no instance management; auto-scaling built-in

4. **Observability Foundation**
   - CloudWatch log groups for each service
   - Basic metrics: CPU, memory, request latency, error rates
   - *Why*: Foundation for debugging; helps identify bottlenecks

5. **Secrets Management**
   - Move DB password to AWS Secrets Manager
   - Update app to fetch at startup
   - Rotate credentials monthly
   - *Why*: Reduces risk of credential leaks; enables rotation without redeployment

**Success Metrics**:
- Deploy 1x per day without manual SSH access
- < 1 min deployment window
- Logs searchable in CloudWatch

**Old Manual Deployment → New CI/CD**:
```
OLD: Developer → SSH to EC2 → git pull → restart service (5-10 min, error-prone)
NEW: Developer → git push → GitHub Actions → test → ECR push → ECS auto-update (2-3 min, automated)
```

---

### Phase 2: Scalability & Resilience (Months 4-6)
**Goal**: Handle 5x load spikes, eliminate downtime

**Tasks**:
1. **Auto-scaling Configuration**
   - ECS auto-scaling group: scale on CPU (70%), memory (80%), request count
   - Min 2 instances (high availability), max 10 (cost limit)
   - Warm container pools to avoid cold starts
   - *Why*: Requests queue instead of timeout; users see slow response instead of 502

2. **RDS Multi-AZ + Read Replicas**
   - Enable Multi-AZ (automatic failover in 1-2 min if primary fails)
   - Create read replica in same region (for reporting without impacting primary)
   - *Why*: HA from 99.5% → 99.95%; read offloading prevents write bottleneck

3. **Connection Pooling**
   - Deploy PgBouncer between app and RDS (max 100 connections from ECS)
   - *Why*: RDS max connections = 500; without pooling, each task opens 5 connections = only 100 tasks possible; with pooling = 1000+ tasks

4. **Caching Layer**
   - ElastiCache Redis for:
     - Session storage (auth tokens, user preferences)
     - Frequently queried data (product catalog, pricing)
   - Cache invalidation strategy on data updates
   - *Why*: DB doesn't see 95% of reads; 100x faster; reduces DB load during spikes

5. **Fixed Outbound IP**
   - Deploy NAT Gateway in public subnet
   - Route all outbound traffic through NAT
   - Whitelist NAT IP with partners
   - *Why*: Partner APIs require static IP; prevents connection failures during auto-scaling

**Success Metrics**:
- Handle 5x concurrent users without performance degradation
- Zero unplanned downtime
- RDS CPU < 50% during peak load
- 99.9% availability SLA

**Load Spike Handling**:
```
BEFORE: 100 users → max requests → memory swap → 30s response time → users abandon
AFTER:  500 users → 10 ECS tasks spawn (30s) → 2s response time → processed gracefully
```

---

### Phase 3: Advanced Observability & Optimization (Months 7-12)
**Goal**: Predictive scaling, cost optimization, operational excellence

**Tasks**:
1. **Distributed Tracing (X-Ray)**
   - Instrument Python backend with X-Ray SDK
   - Trace requests end-to-end: ALB → ECS → RDS → ElastiCache
   - Identify slow endpoints (e.g., N+1 queries)
   - *Why*: Visual request flow; instant identification of bottlenecks

2. **Async Job Processing**
   - Move expensive operations (report generation, image processing) to SQS + Lambda
   - App enqueues job → Lambda processes in background → stores result to S3
   - *Why*: Prevents blocking user requests; peak load no longer affects UX

3. **Database Performance Tuning**
   - Analyze slow query logs
   - Add indexes for common queries
   - Partition large tables (events, logs) by date
   - *Why*: Eliminates O(n) queries; maintains sub-100ms response times at scale

4. **Cost Optimization**
   - Switch to Spot instances (70% cost savings)
   - Reserved instances for baseline capacity
   - Auto-shutdown dev/staging environments after 6 PM
   - *Why*: 40-50% reduction in cloud spend

5. **Disaster Recovery**
   - Automated daily RDS snapshots
   - Cross-region read replica (for true disaster recovery)
   - Document RTO/RPO targets: RTO = 1 hr, RPO = 15 min
   - *Why*: Recoverable from data center outage; business continuity

**Success Metrics**:
- Predictive auto-scaling (scale before spike detected)
- 50% reduction in cloud costs
- < 200ms p95 latency under peak load
- 99.99% availability SLA

---

## Technology Decisions & Justifications

### Why ECS Fargate (Not Kubernetes)?

| Aspect | ECS Fargate | Kubernetes |
|--------|------------|-----------|
| **Setup Time** | Hours (managed by AWS) | Days (need EKSCTL, security config) |
| **Learning Curve** | Steep | Vertical cliff |
| **Cost** | $0.015/vCPU-hour | $0.10/hour per control plane + node costs |
| **AWS Integration** | Native (IAM, Secrets, CloudWatch) | Requires custom integrations |
| **Team Size** | Ideal for 1-2 DevOps engineers | Requires 1+ K8s specialist |

**Decision**: ECS Fargate for Phase 1-2 (move fast, reduce ops overhead). Kubernetes only if scaling to 10+ microservices or multi-cloud needs emerge.

### Why RDS (Not DynamoDB)?

- **SQL requirements**: Existing app built for PostgreSQL; DynamoDB requires schema redesign (6+ weeks)
- **ACID guarantees**: Financial/transactional data needs ACID; DynamoDB eventual consistency risky
- **Existing investment**: Already written SQL; schema tuning is faster path
- **Escape hatch**: If scale becomes issue, migrate specific tables to DynamoDB later

**Decision**: Stick with RDS + read replicas + connection pooling. If PostgreSQL becomes bottleneck (unlikely < 10M records), evaluate DynamoDB for analytics/events tables.

### Why GitHub Actions (Not Jenkins/GitLab)?

- **Tight AWS integration**: Native OIDC, no credentials needed in GitHub
- **Cost**: Free for public repos; $0.008/min for private (much cheaper than Jenkins)
- **Simplicity**: YAML-based, no server to maintain
- **Ecosystem**: Vast action marketplace for common tasks

**Decision**: GitHub Actions. Revisit if need advanced conditional logic or complex secrets handling.

### Why CloudWatch (Not ELK Stack)?

- **Integration**: Native ECS/RDS logs without agent
- **Cost**: Pay-per-log (cheaper than ELK for small workloads)
- **Setup**: Instant; no infrastructure to manage
- **Limitation**: Less customizable than ELK
- **Future**: ELK can be added later if Insights queries become insufficient

**Decision**: CloudWatch for Phase 1-2; evaluate ELK/Datadog at Phase 3 if cost becomes issue.

---

## Database Scalability Strategy

### Problem: "High database load when writing hundreds of thousands of rows"

### Solution Architecture

```
Application
    ↓
SQS Queue (bulk writes enqueued)
    ↓
Lambda (batches 1000 rows, writes to RDS in single transaction)
    ↓
RDS Primary (accepts batched writes efficiently)
    ↓
Read Replica (offloads reporting/analytics queries)
```

### Three-Tier Approach:

**Tier 1: Write Optimization (Immediate)**
- Batching: App writes in 1000-row batches, not individual rows (1000x faster)
- Connection pooling: PgBouncer limits connections
- Indexes: Ensure INSERT-heavy tables have clustered indexes

**Tier 2: Read Offloading (Phase 2)**
- Read replicas (send analytics/reporting to replica, not primary)
- ElastiCache Redis (cache hot data: products, user profiles)
- Result: Primary handles writes; replicas handle reads → balanced load

**Tier 3: Horizontal Partitioning (Phase 3+)**
- Partition events table by date: `events_2024_01`, `events_2024_02`
- Partition by customer: `customer_a_events`, `customer_b_events`
- Move cold data to S3 (for historical analysis via Athena)

### Concrete Example:

```python
# BEFORE: 100,000 writes = 100,000 round-trips to DB = 100 seconds
for row in rows:
    db.insert(row)  # 1 query per row

# AFTER: 100,000 writes = 100 batches of 1000 = 0.5 seconds
for batch in chunks(rows, 1000):
    db.insert_many(batch)  # 1 query per 1000 rows

# Result: 200x faster; RDS CPU 90% → 10%
```

---

## Security Considerations

### Not Mandatory, But Recommended

**Phase 1 (MVP)**:
- [x] IAM roles for ECS tasks (least privilege)
- [x] Secrets Manager for credentials
- [x] Network segmentation (security groups per component)
- [x] HTTPS for ALB

**Phase 2-3 (Nice-to-have)**:
- [ ] WAF (AWS Web Application Firewall) - blocks SQL injection, XSS, DDoS
- [ ] Encryption at rest (RDS, S3)
- [ ] Encryption in transit (TLS 1.3)
- [ ] VPC Flow Logs (audit network traffic)
- [ ] GuardDuty (threat detection)
- [ ] CloudTrail (audit API calls)

---

## Observability & Operational Readiness

### Logging
- **Container logs**: Streamed to CloudWatch
- **RDS logs**: Slow query logs, error logs
- **Application logs**: Structured JSON with correlation IDs for tracing

### Metrics
- **ECS**: CPU, memory, task count, request latency, error rate
- **RDS**: CPU, connections, storage, replication lag
- **ALB**: Request count, latency, HTTP 5xx errors
- **Custom**: Business metrics (orders/min, conversion rate)

### Alerting (CloudWatch Alarms)
| Condition | Threshold | Action |
|-----------|-----------|--------|
| ECS CPU > 80% for 5 min | Scale up | On-call notified |
| RDS CPU > 85% for 10 min | Investigate | On-call page |
| ALB 5xx > 5% | Investigate | On-call page |
| Deployment failure | Any | Slack notification |

### Deployment & Rollback Strategy
1. **Blue-Green Deployment**:
   - Deploy new version to empty task group (green)
   - Run smoke tests
   - Switch ALB traffic from blue → green (instant, zero downtime)
   - Keep blue running 30 min; if green fails, switch back

2. **Rollback**: 30 seconds (switch ALB target group)
   - *vs. Rolling restart*: 5 min (gradually replace containers)

---

## 3-Month Priorities vs. What Can Wait

### Months 1-3 (DO THIS FIRST)
1. ✅ Containerize app (frontend + backend)
2. ✅ GitHub Actions CI/CD pipeline
3. ✅ Deploy to ECS Fargate (single AZ, 2 tasks)
4. ✅ CloudWatch logs and basic metrics
5. ✅ Secrets Manager for credentials

**Outcome**: Deploy daily without SSH; 99.5% availability

### Months 4-6 (NEXT PRIORITY)
1. ✅ Auto-scaling (ECS tasks)
2. ✅ RDS Multi-AZ + read replica
3. ✅ NAT Gateway (fixed outbound IP)
4. ✅ PgBouncer connection pooling
5. ✅ ElastiCache Redis

**Outcome**: Handle 5x load; 99.9% availability

### Months 7-12 (NICE-TO-HAVE)
1. ❌ Kubernetes (premature)
2. ❌ ELK stack (CloudWatch sufficient)
3. ❌ Machine learning-based auto-scaling
4. ❌ Multi-region disaster recovery
5. ❌ Advanced WAF rules

**Outcome**: Cost-optimized, predictive scaling, 99.99% availability

---

## Migration Execution Plan (Minimizing Downtime)

### Week 1-2: Infrastructure Setup (Zero Downtime)
```
Phase      | Existing System | New System | Status
-----------|-----------------|-----------|----------
Databases  | RDS 1.x         | RDS 1.x   | Unchanged (backward compatible)
Secrets    | Hardcoded       | Secrets Mgr | App accepts both
Networking | EC2 + ALB       | New ALB   | Deployed in parallel
```

### Week 3-4: Application Cutover (5-min downtime)
```
1. Old traffic: EC2 → ALB → EC2 Instance
2. Deploy new app to ECS (in parallel)
3. Run smoke tests on ECS
4. Switch ALB target from EC2 → ECS (30 seconds)
5. Verify, then decommission EC2
```

### Week 5+: Cleanup
- Decommission old EC2 instances
- Archive old deployment scripts
- Document lessons learned

**Total Downtime**: ~5 minutes (during DNS cutover)
**Rollback Time**: 30 seconds (just move ALB back to old infra)

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| ECS deployment fails | Medium | High | Deploy to staging first; auto-rollback on failures |
| DB connection pool exhaustion | Low | High | Start with conservative limits; monitor connection count |
| Cost overrun from auto-scaling | Medium | Medium | Set max task count = 10; reserved instances for baseline |
| Data corruption during migration | Low | Critical | Backup RDS before cutover; verify data integrity post-migration |
| DNS propagation delays | Low | Medium | Pre-warm DNS caches; set TTL = 60s |

---

## Cost Projection

### Current State (Manual EC2 + RDS)
- EC2 (t3.large × 1): $60/month
- RDS (db.t3.medium): $150/month
- Data transfer: $20/month
- **Total**: $230/month

### Proposed (ECS + RDS optimized)
- ECS Fargate (2 vCPU, 4GB × 4 tasks avg): $90/month
- RDS Multi-AZ (db.t3.medium + replica): $300/month
- ElastiCache (cache.t3.micro): $30/month
- NAT Gateway: $32/month
- Data transfer: $40/month
- **Total**: $492/month

**ROI**: +113% cost for:
- 10x better scalability
- 99.9% vs. 99% availability
- Zero-downtime deployments
- Observability
- Disaster recovery
- **Breakeven**: When manual interventions would cost > $262/month in labor

---

## Conclusion

This proposal prioritizes getting to automated, scalable deployments in 3 months, then adds observability and cost optimization in subsequent phases. The architecture is AWS-native, cost-effective, and designed for a small DevOps team.

**Key Success Criteria**:
- ✅ Zero-downtime deployments
- ✅ 5x load handling without slowdown
- ✅ Fixed outbound IP for partner APIs
- ✅ Centralized observability
- ✅ Disaster recovery
- ✅ Maintainable by 1 DevOps engineer
