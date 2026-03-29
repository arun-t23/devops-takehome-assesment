# System Architecture Diagram

Save this as `ARCHITECTURE_DIAGRAM.md` and view in VS Code (or paste into draw.io/Mermaid viewer)

## Proposed Architecture (Mermaid Diagram)

```mermaid
graph TB
    subgraph "Client Layer"
        User["👤 Users"]
        Partner["🔗 Partner APIs"]
    end

    subgraph "CDN & WAF"
        CloudFront["CloudFront<br/>(CDN)"]
        WAF["WAF<br/>(optional)"]
    end

    subgraph "Load Balancing"
        ALBFrontend["ALB<br/>(Frontend - Port 443)"]
        ALBBackend["ALB<br/>(Backend - Port 80)"]
    end

    subgraph "AWS VPC"
        subgraph "Public Subnets"
            NAT["NAT Gateway<br/>(Fixed Outbound IP)"]
        end

        subgraph "Private Subnets - ECS Cluster"
            ECS1["ECS Task<br/>(Frontend)"]
            ECS2["ECS Task<br/>(Backend)"]
            ECS3["ECS Task<br/>(Backend)"]
            ECS4["ECS Task<br/>(Backend)"]
        end

        subgraph "Data Layer"
            RDSPrimary["RDS PostgreSQL<br/>(Primary - Write)"]
            RDSReplica["RDS Read Replica<br/>(Read-only)"]
            Redis["ElastiCache Redis<br/>(Session + Cache)"]
            S3["S3 Bucket<br/>(Static Assets)"]
        end

        subgraph "Job Processing"
            SQS["SQS Queue<br/>(Async Jobs)"]
            Lambda["Lambda<br/>(Bulk Processing)"]
        end
    end

    subgraph "Observability"
        CloudWatchLogs["CloudWatch Logs"]
        CloudWatchMetrics["CloudWatch Metrics"]
        XRay["X-Ray<br/>(Distributed Tracing)"]
        Alarms["CloudWatch Alarms"]
    end

    subgraph "CI/CD"
        GitHub["GitHub Repo"]
        GitHubActions["GitHub Actions<br/>(Build → Test → Deploy)"]
        ECR["Amazon ECR<br/>(Docker Images)"]
    end

    subgraph "Security"
        SecretsManager["Secrets Manager<br/>(Credentials)"]
        IAM["IAM Roles"]
        SecurityGroups["Security Groups<br/>(Network Segmentation)"]
    end

    subgraph "Auto-Scaling"
        ASG["Auto Scaling Group<br/>(Min: 2, Max: 10)"]
    end

    %% Client connections
    User -->|HTTPS| CloudFront
    CloudFront --> WAF
    WAF --> ALBFrontend
    ALBFrontend --> ECS1
    
    User -->|Backend API| ALBBackend
    ALBBackend --> ECS2
    ALBBackend --> ECS3
    ALBBackend --> ECS4
    
    Partner -->|Whitelist NAT IP| NAT

    %% ECS connections
    ECS1 -->|Fetch Config| SecretsManager
    ECS2 -->|Fetch Config| SecretsManager
    ECS3 -->|Read/Write| RDSPrimary
    ECS4 -->|Read| RDSReplica
    
    ECS2 -->|Cache Hit| Redis
    ECS3 -->|Session Store| Redis
    
    ECS1 -->|Static Assets| S3
    
    ECS2 -->|Enqueue Job| SQS
    SQS --> Lambda
    Lambda -->|Bulk Write| RDSPrimary

    %% RDS Replication
    RDSPrimary -->|Async Replication| RDSReplica

    %% Monitoring
    ECS1 -->|Container Logs| CloudWatchLogs
    ECS2 -->|Metrics| CloudWatchMetrics
    ECS3 -->|Traces| XRay
    RDSPrimary -->|Slow Queries| CloudWatchLogs
    ALBFrontend -->|Request Metrics| CloudWatchMetrics
    
    CloudWatchMetrics --> Alarms
    Alarms -->|CPU > 80%| ASG
    ASG -->|Scale Up| ECS2
    ASG -->|Scale Up| ECS3

    %% CI/CD
    GitHub --> GitHubActions
    GitHubActions -->|Push Image| ECR
    ECR -->|Blue-Green Deploy| ECS2
    
    %% IAM & Security
    ECS1 -->|Assume Role| IAM
    ECS2 -->|Assume Role| IAM
    ECS3 -->|Network Rules| SecurityGroups
    Lambda -->|Assume Role| IAM

    %% Styling
    classDef client fill:#e1f5ff
    classDef compute fill:#fff3e0
    classDef data fill:#f3e5f5
    classDef observability fill:#e8f5e9
    classDef cicd fill:#fce4ec
    classDef security fill:#fff9c4

    class User,Partner client
    class ECS1,ECS2,ECS3,ECS4,ASG compute
    class RDSPrimary,RDSReplica,Redis,S3,SQS,Lambda data
    class CloudWatchLogs,CloudWatchMetrics,XRay,Alarms observability
    class GitHub,GitHubActions,ECR cicd
    class SecretsManager,IAM,SecurityGroups security
```

## Phase-by-Phase Deployment

### Phase 1: Foundation (Month 1-3)
```mermaid
graph LR
    GitHub["GitHub Actions"] -->|Build| ECR["ECR"]
    ECR -->|Deploy| ECS["ECS Fargate<br/>(Single AZ)"]
    ECS -->|Read/Write| RDS["RDS<br/>(Single Instance)"]
    ECS -->|Logs| CWLogs["CloudWatch Logs"]
    
    style ECS fill:#fff3e0
    style RDS fill:#f3e5f5
    style ECR fill:#fce4ec
```

### Phase 2: Scalability (Month 4-6)
```mermaid
graph LR
    GitHub["GitHub"] -->|Build| ECR["ECR"]
    ECR -->|Deploy| ASG["Auto Scaling Group<br/>(2-10 tasks)"]
    ASG -->|Write| RDSPrimary["RDS Primary"]
    ASG -->|Read| RDSReplica["RDS Replica"]
    ASG -->|Cache| Redis["Redis"]
    RDSPrimary -->|Replicate| RDSReplica
    ASG -->|Outbound| NAT["NAT Gateway"]
    
    style ASG fill:#fff3e0
    style RDSPrimary fill:#f3e5f5
    style RDSReplica fill:#f3e5f5
    style Redis fill:#f3e5f5
```

### Phase 3: Observability (Month 7-12)
```mermaid
graph TB
    ASG["ECS Cluster"]
    ASG -->|Logs| CWLogs["CloudWatch Logs"]
    ASG -->|Metrics| CWMetrics["CloudWatch Metrics"]
    ASG -->|Traces| XRay["X-Ray"]
    CWMetrics -->|Triggers| Alarms["Alarms"]
    Alarms -->|Scale| ASG
    Lambda["Lambda Jobs"]
    SQS["SQS Queue"]
    ASG -->|Enqueue| SQS
    SQS -->|Process| Lambda
    
    style CWLogs fill:#e8f5e9
    style CWMetrics fill:#e8f5e9
    style XRay fill:#e8f5e9
```

## Deployment Strategy: Blue-Green

```mermaid
graph TD
    subgraph Current["🔵 BLUE (Current - Serving Traffic)"]
        Blue["ECS Tasks - v1.0"]
        BlueALB["ALB"]
    end
    
    subgraph Next["🟢 GREEN (New - Testing)"]
        Green["ECS Tasks - v1.1"]
        GreenALB["Isolated ALB"]
    end
    
    subgraph Switch["Switch Point"]
        Decision["Smoke Tests Pass?"]
    end
    
    BlueALB -->|Traffic| Users["Users"]
    GreenALB -->|Internal Tests| SmokeTests["Automated Tests"]
    SmokeTests --> Decision
    Decision -->|YES| Users
    Decision -->|NO| Blue
    
    style Blue fill:#e3f2fd
    style Green fill:#e8f5e9
    style Decision fill:#fff9c4
```

## Load Spike Handling Comparison

### BEFORE: Single EC2
```
Load Increases
    ↓
Memory Usage ↑↑↑
    ↓
Swap Thrashing
    ↓
Response Time: 10s → 100s
    ↓
Users abandon site 😞
    ↓
Downtime
```

### AFTER: Auto-Scaling ECS
```
Load Increases
    ↓
CloudWatch detects CPU > 70%
    ↓
ASG spawns 2-3 new ECS tasks (10s)
    ↓
Tasks ready, traffic distributed
    ↓
Response Time: 2s (stable)
    ↓
Graceful handling 😊
    ↓
Zero downtime
```

## Database Scalability: Batching Example

### BEFORE: Individual Inserts
```
INSERT INTO events VALUES (1);
INSERT INTO events VALUES (2);
INSERT INTO events VALUES (3);
... (100,000 times)

Time: 100 seconds
RDS Connections: 5
RDS CPU: 90%
I/O Throughput: Saturated
```

### AFTER: Batch Inserts
```
INSERT INTO events VALUES (1), (2), (3), ... (1000);
... (100 times)

Time: 0.5 seconds
RDS Connections: 1
RDS CPU: 10%
I/O Throughput: Normal
```

## Network Topology

```
┌──────────────────────────────────────────────────────────────┐
│                        Internet                              │
│                                                              │
│  Users (0.0.0.0/0)     Partner APIs                        │
│         ↓                      ↓                             │
│      CloudFront ◄─────────────┘                            │
│         ↓                                                    │
│        WAF                                                   │
│         ↓                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            AWS VPC (10.0.0.0/16)                    │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Public Subnet (10.0.1.0/24)               │    │  │
│  │  │  - ALB (Frontend/Backend)                  │    │  │
│  │  │  - NAT Gateway ◄────────────── Partners    │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Private Subnet (10.0.11.0/24)             │    │  │
│  │  │  - ECS Tasks (Frontend)                    │    │  │
│  │  │  - ECS Tasks (Backend)                     │    │  │
│  │  │  - ElastiCache Redis                       │    │  │
│  │  │  - Lambda (Async Jobs)                     │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Database Subnet (10.0.21.0/24)            │    │  │
│  │  │  - RDS Primary (Write)                     │    │  │
│  │  │  - RDS Replica (Read)                      │    │  │
│  │  │  - Multi-AZ: Primary in AZ-A, Replica AZ-B│    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Key Metrics & Monitoring

```mermaid
graph LR
    ECS["ECS Cluster"]
    
    ECS -->|CPU%<br/>Memory%| CWM1["CloudWatch<br/>Metrics"]
    ECS -->|Request Count<br/>Latency| CWM2["ALB<br/>Metrics"]
    RDS["RDS"] -->|CPU%<br/>Connections<br/>Storage| CWM3["DB<br/>Metrics"]
    
    CWM1 --> Dashboard["📊 Dashboard"]
    CWM2 --> Dashboard
    CWM3 --> Dashboard
    
    Dashboard -->|CPU > 80%<br/>for 5min| Alarm1["Scale Up"]
    Dashboard -->|5xx > 5%| Alarm2["Page On-Call"]
    Dashboard -->|Deployment<br/>Failed| Alarm3["Slack Alert"]
    
    style Dashboard fill:#e8f5e9
    style Alarm1 fill:#ffe0b2
    style Alarm2 fill:#ffcdd2
    style Alarm3 fill:#ffcdd2
```

