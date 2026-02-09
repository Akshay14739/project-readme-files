# Interview Preparation Guide: Part 2
## Advanced Kubernetes: Microservices, Data Plane Integration & Observability
**Sections 14, 18, 19, 20: Retail Store, HPA, Helm, OpenTelemetry**

**Date**: February 9, 2026  
**Status**: Complete Interview Preparation Guide

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Section 14: Retail Store Microservices with AWS Data Plane](#section-14-retail-store-microservices-with-aws-data-plane)
3. [Section 18: Horizontal Pod Autoscaling (HPA)](#section-18-horizontal-pod-autoscaling-hpa)
4. [Section 19: Helm Charts for Microservices Deployment](#section-19-helm-charts-for-microservices-deployment)
5. [Section 20: Observability with OpenTelemetry](#section-20-observability-with-opentelemetry)
6. [Complete Microservices Architecture](#complete-microservices-architecture)
7. [Interview Q&A - Part 2](#interview-qa---part-2)

---

## Executive Summary

You implemented a **complete microservices platform** with:

✅ **Multi-Service Architecture** - 5 microservices (Catalog, Cart, Checkout, Orders, UI)  
✅ **AWS Data Plane Integration** - RDS, DynamoDB, ElastiCache, SQS  
✅ **Auto-Scaling** - Horizontal Pod Autoscaling (HPA) based on metrics  
✅ **Package Management** - Helm charts for standardized deployment  
✅ **Observability** - OpenTelemetry for traces, logs, metrics  
✅ **High Availability** - Multi-pod deployments, resource requests/limits, pod disruption budgets  

---

## Section 14: Retail Store Microservices with AWS Data Plane

### Problem: Building Production Microservices

```
Challenges:
├─ How do multiple pods share databases?
├─ How do services communicate securely?
├─ How do we validate configuration?
├─ How do we monitor applications?
├─ How do we scale under load?
└─ How do we handle failures gracefully?
```

### Solution: Full Microservices Stack

```
COMPLETE RETAIL STORE APPLICATION
═════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────┐
│                      END-USER INTERFACE                          │
│                       (app.example.com)                          │
└────────────────┬─────────────────────────────────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────────────────────────────────┐
│                    AWS ALB (Ingress)                             │
│   - Port: 80/443                                                 │
│   - Routing: path-based to services                              │
└────────────────┬─────────────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┬──────────────┬───────────────┐
    │            │            │              │               │
    ↓            ↓            ↓              ↓               ↓
┌────────┐  ┌────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│  UI    │  │Catalog │  │  Orders  │  │Cart      │  │Checkout  │
│(Port 3000)│(Port 80) │  (Port 80)  │ (Port 80) │  │(Port 80) │
└────────┘  └────────┘  └──────────┘  └──────────┘  └──────────┘
     3         ✓            ✓            ✓            ✓
   replicas   replicas     replicas     replicas     replicas
     │            │            │            │            │
     │      ┌─────┘            │       ┌────┘            │
     │      │                  │       │                 │
     │      ↓                  ↓       ↓                 ↓
     │  RDS MySQL         PostgreSQL ElastiCache   (No DB)
     │  (Catalog DB)      (Orders DB) Redis
     │  ├─ Products       ├─ Orders   (Sessions)
     │  └─ Inventory      └─ Items    └─ Shopping
     │                                   Cart
     │
     └────→ SQS Queue (async messaging for Orders)
            └─ Order processing events


KEY INTEGRATION POINTS:
═════════════════════════════════════════════════════════════════════

1. CATALOG MICROSERVICE
   ├─ Service: catalog (3 replicas)
   ├─ API: GET /products, /inventory
   ├─ Database: AWS RDS MySQL
   │  └─ credentials from AWS Secrets Manager
   ├─ Service Account: catalog (with Pod Identity to RDS)
   └─ Service Type: ClusterIP (internal only)

2. CART MICROSERVICE
   ├─ Service: cart (3 replicas)
   ├─ API: GET, POST /cart/{userId}
   ├─ Database: AWS DynamoDB (NoSQL)
   │  └─ table: carts
   │  └─ partition key: userId
   ├─ Service Account: cart (with Pod Identity to DynamoDB)
   └─ Service Type: ClusterIP

3. CHECKOUT MICROSERVICE
   ├─ Service: checkout (2 replicas)
   ├─ API: POST /process-payment
   ├─ Cache: AWS ElastiCache Redis
   │  └─ stores session tokens
   │  └─ credentials from Secrets Manager
   ├─ Service Account: checkout (with Pod Identity to Redis)
   └─ Service Type: ClusterIP

4. ORDERS MICROSERVICE
   ├─ Service: orders (2 replicas)
   ├─ API: POST /order, GET /order/{id}
   ├─ Database: AWS RDS PostgreSQL
   ├─ Queue: AWS SQS (for async order processing)
   │  └─ order-processing-queue
   ├─ Service Account: orders (with Pod Identity to RDS, DynamoDB, SQS)
   └─ Service Type: ClusterIP

5. UI SERVICE
   ├─ Service: ui (3 replicas, frontend website)
   ├─ Framework: React/Angular/Vue (static HTML/JS)
   ├─ No database (state stored in browser/cache)
   ├─ Calls backend APIs via /api paths
   └─ Service Type: ClusterIP (exposed via Ingress)
```

### Catalog Microservice Startup & Database Connection Workflow

**How a Microservice Starts and Connects to AWS RDS:**

```
DEVELOPER APPLIES MANIFEST
├─ kubectl apply -f catalog-deployment.yaml
└─ Kubernetes receives manifest

KUBERNETES CREATES OBJECTS (in order)
├─ ServiceAccount: catalog ✅
├─ ConfigMap: catalog-config ✅
├─ SecretProviderClass: catalog-secrets ✅
└─ Deployment: catalog (3 replicas) ❌ PENDING

DEPLOYMENT CONTROLLER WATCHES DEPLOYMENT
├─ Desired: 3 pods
├─ Current: 0 pods
└─ Action: "Need to create 3 pods"

SCHEDULER PLACES POD 1
├─ Pod requirements:
│  ├─ image: catalog:v1.0.0
│  ├─ CPU: 100m requested, 500m limit
│  ├─ Memory: 256Mi requested, 512Mi limit
│  ├─ ServiceAccount: catalog
│  └─ Volumes:
│     ├─ secrets-store (CSI volume)
│     └─ empty volumes
│
├─ Find suitable node:
│  ├─ Node-1: Has 5vCPU free, 8GB RAM free ✓
│  ├─ Node-2: Has 1vCPU free, 2GB RAM free ✗ (not enough)
│  └─ Selected: Node-1
│
└─ Pod scheduled ✅

KUBELET STARTS POD (on Node-1)
├─ Create pod sandbox (containerd runtime)
├─ Set up pod networking:
│  ├─ Pause container
│  ├─ Pod gets IP: 10.0.11.45 (from pod subnet)
│  ├─ Add to service (catalog:3306)
│  └─ Expose metrics port :10255
│
├─ Mount volumes:
│  ├─ secrets-store → Secrets Store CSI driver
│  │  └─ Waits for secrets to be mounted
│  │
│  └─ emptyDir → ephemeral storage (temp logs)
│
├─ Pull image: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/catalog:v1.0.0
│  ├─ Download from Amazon ECR
│  ├─ Cache locally
│  └─ Extract layers
│
└─ Image ready ✅

CSI DRIVER MOUNTS SECRETS (Parallel with above)
├─ Secrets Store CSI DaemonSet running on Node-1
├─ Detects: Pod needs secrets-store volume
│
├─ Step 1: Get Pod Identity
│  ├─ Read: ServiceAccount token (in /var/run/secrets/kubernetes.io/serviceaccount/token)
│  ├─ Token: OIDC signed JWT
│  └─ Contains: {pod_name: "catalog-abc123", namespace: "default", sa: "catalog"}
│
├─ Step 2: Contact Pod Identity Agent
│  ├─ URL: http://169.254.169.254/latest/api/sts (AWS IMDSv2)
│  ├─ Send: Pod token + ServiceAccount name
│  └─ Goal: "I am ServiceAccount `catalog`, can I assume the catalog-pod-iam-role?"
│
├─ Step 3: Pod Identity Agent Validates
│  ├─ Query: EKS Pod Identity Association table
│  ├─ Check: Is "catalog" SA → "catalog-pod-iam-role" possible? YES ✓
│  ├─ Call: aws sts assume-role
│  │  └─ Role: arn:aws:iam::123456789:role/catalog-pod-iam-role
│  │
│  └─ Receive: Temporary credentials
│     ├─ AWS_ACCESS_KEY_ID: temporary
│     ├─ AWS_SECRET_ACCESS_KEY: temporary
│     ├─ AWS_SESSION_TOKEN: temporary
│     └─ Expiration: 15 minutes

├─ Step 4: Fetch Secrets from AWS Secrets Manager
│  ├─ Credentials obtained from above ✓
│  ├─ Call: aws secretsmanager get-secret-value --secret-id catalog-db-secret
│  │  ├─ Authenticates with temporary credentials
│  │  └─ Reads encrypted secret
│  │
│  └─ Receive: {"username": "catalog_user", "password": "SecurePass123", ...}
│
├─ Step 5: Mount Secrets as Files
│  ├─ Create directory: /var/lib/kubelet/pods/xxx/volumes/csi/secrets-store/mount
│  │
│  ├─ Write files:
│  │  ├─ /mnt/secrets/username (contains "catalog_user")
│  │  ├─ /mnt/secrets/password (contains "SecurePass123")
│  │  └─ /mnt/secrets/host (contains "catalog-mysql.default.svc.cluster.local")
│  │
│  └─ Pod can now read these files ✅

CONTAINER STARTS
├─ Image layers merged (via OCI runtime)
├─ Container networking configured
├─ ENTRYPOINT runs: python app.py
│  └─ Python process starts
│
└─ Container running ✅ (status: Starting)

APPLICATION INITIALIZATION (Inside container)
├─ Import: Flask framework, MySQL client library
├─ Read environment:
│  ├─ ConfigMap mounted as ENV vars:
│  │  ├─ DB_HOST: "catalog-mysql.default.svc.cluster.local"
│  │  ├─ DB_PORT: "3306"
│  │  ├─ DATABASE_NAME: "catalogdb"
│  │  └─ API_PORT: "8080"
│  │
│  └─ Secrets from mounted files:
│     ├─ DB_USER = content of /mnt/secrets/username = "catalog_user"
│     ├─ DB_PASSWORD = content of /mnt/secrets/password = "SecurePass123"
│     └─ DB_ENDPOINT = content of /mnt/secrets/host = "catalog-mysql.default.svc.cluster.local"
│
├─ Create database connection pool:
│  ├─ Engine: mysql+pymysql
│  ├─ Connection string:
│  │  └─ mysql+pymysql://catalog_user:SecurePass123@catalog-mysql.default.svc.cluster.local:3306/catalogdb
│  │
│  └─ Connect to RDS MySQL
│     ├─ Network: Pod (10.0.11.45) → MySQL endpoint (RDS DNS)
│     ├─ Security group check: Pod SG → RDS SG ✓
│     ├─ Firewall: 3306 allowed ✓
│     ├─ Authenticate: username/password ✓
│     └─ Connected ✅
│
├─ Run database migrations:
│  ├─ CREATE TABLE IF NOT EXISTS products
│  ├─ CREATE TABLE IF NOT EXISTS inventory
│  └─ Migrations complete ✅
│
└─ Start HTTP server:
   ├─ Bind: 0.0.0.0:8080
   ├─ Routes: /products, /inventory, /health, /ready
   └─ Listening ✅

READINESS PROBE
├─ kubelet: "Is pod ready to serve traffic?"
├─ HTTP GET /ready (port 8080)
├─ Response: 200 OK (database connected)
└─ Pod marked: Ready ✅ (status: Running)

SERVICE LOAD BALANCING
├─ Service object watches: Pods with label app=catalog
├─ Pod matches: YES ✓
├─ Add endpoint: 10.0.11.45:8080
├─ Endpoints now available:
│  ├─ Pod 1: 10.0.11.45:8080
│  ├─ Pod 2: 10.0.11.46:8080
│  └─ Pod 3: 10.0.11.47:8080
│
└─ Service name: catalog.default.svc.cluster.local

OTHER PODS CAN NOW CALL CART
├─ Example: UI pod calling /api/catalog/products
├─ Network resolve:
│  ├─ DNS query: catalog.default.svc.cluster.local
│  ├─ CoreDNS returns: 10.0.11.45, 10.0.11.46, 10.0.11.47
│  └─ Pick random: 10.0.11.46
│
├─ Make HTTP request:
│  ├─ GET http://10.0.11.46:8080/products
│  ├─ Routed to: Catalog Pod 2
│  └─ Response: JSON list of products from MySQL
│
└─ Request complete ✅

PERIODIC CREDENTIAL ROTATION
├─ AWS Secrets Manager: Auto-rotate every 30 days
├─ Old credentials: Still valid for 7 days
├─ New credentials: Automatically available
├─ CSI driver: Re-reads secret files
├─ Application: Picks up new credentials
└─ ZERO-DOWNTIME rotation ✅
```

### Implementation: Catalog Microservice (RDS MySQL)

```yaml
---
# ServiceAccount (with Pod Identity Association)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: default

---
# ConfigMap (non-sensitive config)
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog-config
data:
  DB_HOST: "catalog-mysql.default.svc.cluster.local"
  DB_PORT: "3306"
  DATABASE_NAME: "catalogdb"
  LOG_LEVEL: "INFO"
  API_PORT: "8080"

---
# SecretProviderClass (fetch from AWS Secrets Manager)
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: catalog-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "catalog-db-secret"
        objectType: "secretsmanager"
        objectAlias: "username"
        jmesPath: "username"
      - objectName: "catalog-db-secret"
        objectType: "secretsmanager"
        objectAlias: "password"
        jmesPath: "password"

---
# Deployment (3 replicas)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  
  selector:
    matchLabels:
      app: catalog
  
  template:
    metadata:
      labels:
        app: catalog
        tier: backend
    
    spec:
      serviceAccountName: catalog  # Links to IAM role via Pod Identity
      
      containers:
      - name: catalog
        image: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/catalog:v1.0.0
        imagePullPolicy: IfNotPresent
        
        ports:
        - containerPort: 8080
          name: http
        
        # ConfigMap mount
        envFrom:
        - configMapRef:
            name: catalog-config
        
        # Secrets mount (from AWS Secrets Manager)
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
        
        # Resource requests and limits
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 2
        
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
      
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          volumeAttributes:
            secretProviderClass: "catalog-secrets"

---
# ClusterIP Service (internal communication)
apiVersion: v1
kind: Service
metadata:
  name: catalog
spec:
  type: ClusterIP
  selector:
    app: catalog
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http

---
# ExternalName Service (points to RDS endpoint)
apiVersion: v1
kind: Service
metadata:
  name: catalog-mysql
spec:
  type: ExternalName
  externalName: "catalog-mysql.cxxxxxx.us-east-1.rds.amazonaws.com"
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

### Implementation: Cart Microservice (DynamoDB)

```yaml
---
# ServiceAccount with DynamoDB permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cart
  namespace: default

---
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cart-config
data:
  DYNAMODB_TABLE_NAME: "carts"
  AWS_REGION: "us-east-1"
  API_PORT: "8080"

---
# Cart Deployment (DynamoDB - no secrets needed for table name)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cart
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cart
  
  template:
    metadata:
      labels:
        app: cart
    
    spec:
      serviceAccountName: cart  # Has Pod Identity → DynamoDB role
      
      containers:
      - name: cart
        image: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/cart:v1.0.0
        
        ports:
        - containerPort: 8080
        
        envFrom:
        - configMapRef:
            name: cart-config
        
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: cart
spec:
  type: ClusterIP
  selector:
    app: cart
  ports:
  - port: 80
    targetPort: 8080
```

### Terraform: AWS Data Plane Setup

**AWS Data Plane Components Workflow:**

```
┌──────────────────────────────────────────────────────────────────┐
│ Terraform AWS Data Plane Provisioning                            │
└──────────────────────────────────────────────────────────────────┘

  resource "aws_db_instance" "catalog_mysql"
         │
         ├─ Engine: MySQL 8.0
         ├─ Instance: db.t3.micro  
         ├─ Storage: 20GB
         └─ Encrypted: true

  resource "aws_dynamodb_table" "cart"
         │
         ├─ Table: cart-table
         ├─ Key: userId
         ├─ Billing: PAY_PER_REQUEST
         └─ Point-in-time recovery: enabled

  resource "aws_elasticache_cluster" "checkout_redis"
         │
         ├─ Engine: redis
         ├─ Node: cache.t3.micro
         ├─ Nodes: 2 (HA)
         └─ Auto-failover: true

  resource "aws_rds_instance" "orders_postgres"
         │
         ├─ Engine: PostgreSQL
         ├─ Storage: 50GB
         └─ Multi-AZ: true

  resource "aws_sqs_queue" "orders_queue"
         │
         ├─ FIFO: true
         ├─ Dedup: enabled
         └─ Retention: 4 days

         ↓ All connected via IAM roles & security groups
        
  Result: Complete isolated microservices infrastructure
```

```hcl
# RDS MySQL for Catalog
resource "aws_db_instance" "catalog_mysql" {
  identifier            = "catalog-mysql"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "catalogdb"
  username = "catalog_user"
  # password from Secrets Manager
  
  vpc_security_group_ids = [aws_security_group.catalog_db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.catalog_db_subnet.name
  
  multi_az               = true  # High availability
  backup_retention_period = 30   # 30-day backup
  skip_final_snapshot    = false
  final_snapshot_identifier = "catalog-mysql-final-snapshot"
}

# DynamoDB Table for Cart
resource "aws_dynamodb_table" "carts" {
  name           = "carts"
  billing_mode   = "PAY_PER_REQUEST"  # Serverless pricing
  hash_key       = "userId"
  
  attribute {
    name = "userId"
    type = "S"  # String
  }
  
  ttl {
    attribute_name = "expirationTime"
    enabled        = true
  }
  
  point_in_time_recovery_specification {
    enabled = true
  }
  
  tags = {
    Name = "carts"
  }
}

# IAM Role for Cart Pod
resource "aws_iam_role" "cart_pod_role" {
  name = "cart-pod-iam-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# DynamoDB permissions
resource "aws_iam_role_policy" "cart_dynamodb" {
  name = "cart-dynamodb-policy"
  role = aws_iam_role.cart_pod_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.carts.arn
    }]
  })
}

# Pod Identity Association
resource "aws_eks_pod_identity_association" "cart" {
  cluster_name    = var.cluster_name
  namespace       = "default"
  service_account = "cart"
  role_arn        = aws_iam_role.cart_pod_role.arn
}

# ElastiCache Redis for Checkout
resource "aws_elasticache_cluster" "checkout_redis" {
  cluster_id           = "checkout-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 2
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  
  subnet_group_name = aws_elasticache_subnet_group.checkout.name
  security_group_ids = [aws_security_group.checkout_redis_sg.id]
  
  automatic_failover_enabled = true
  multi_az_enabled          = true
}
```

---

## Section 18: Horizontal Pod Autoscaling (HPA)

### Problem: Static Pod Deployment

```
❌ STATIC DEPLOYMENT (3 replicas fixed):
├─ Low traffic hours: 3 pods waste resources ($$$ cost)
├─ High traffic hours: 3 pods can't handle load (timeouts)
├─ No way to respond to traffic spikes

✅ AUTOSCALING SOLUTION:
├─ HPA monitors CPU/memory
├─ Automatic: 3-10 pods based on load
├─ High efficiency: right-sized for current demand
├─ Cost optimization: scale down during low traffic
```

### HPA Architecture

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

KUBERNETES CLUSTER WITH HPA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. METRICS COLLECTION
   ├─ Metrics Server (EKS add-on)
   ├─ Runs on every node
   ├─ Collects CPU/memory from kubelet
   ├─ Stores metrics in memory (no storage)
   └─ HPA queries metrics every 15s (default)

2. HPA DECISION LOGIC
   HorizontalPodAutoscaler watches:
   ├─ Current pod count: 3
   ├─ Target CPU: 80%
   ├─ Current average CPU across pods: 85%
   ├─ Decision:
   │  ├─ Pod replicas = current (3) × (current/target)
   │  ├─ = 3 × (85/80)
   │  ├─ = 3 × 1.06
   │  ├─ = 3.18 → SCALE UP to 4 pods ✅
   │  └─ (rounds up to next integer)
   └─ Action: Add 1 pod → total 4 pods

3. DEPLOYMENT UPDATE
   ├─ HPA updates Deployment replicas: 3 → 4
   ├─ Deployment creates new Pod
   ├─ Scheduler finds node with capacity
   ├─ New pod starts
   └─ Metrics recalculated after cooldown

4. SCALE DOWN
   ├─ Traffic decreases
   ├─ Average CPU drops to 60%
   ├─ Wait 5 minutes (cooldown period)
   ├─ Scale down: 4 → 3 pods
   ├─ Evict extra pod gracefully
   └─ Saves costs ✅

═══════════════════════════════════════════════════════════════════

SCALING TIMELINE (Example)
═══════════════════════════════════════════════════════════════════

Time  │ Event                      │ Pod Count │ CPU Usage
──────┼────────────────────────────┼───────────┼──────────
10:00 │ Morning traffic start       │    3      │  70%
10:15 │ Traffic increases           │    3      │  85%
10:16 │ HPA detects 85% > 80%      │    3→4    │  (scaling)
10:17 │ Pod 4 ready                 │    4      │  72%
──────┼────────────────────────────┼───────────┼──────────
12:00 │ Lunch rush (peak traffic)  │    4      │  90%
12:01 │ HPA scales up               │    4→7    │  (scaling)
12:03 │ All pods ready              │    7      │  82%
──────┼────────────────────────────┼───────────┼──────────
14:00 │ Lunch rush ended            │    7      │  55%
14:05 │ Cooldown expires            │    7→5    │  (scaling)
14:07 │ Pods evicted gracefully      │    5      │  68%
──────┼────────────────────────────┼───────────┼──────────
20:00 │ Evening quiet               │    5      │  40%
20:05 │ Scale down again            │    5→3    │  (scaling)
20:07 │ Back to baseline            │    3      │  60%
──────┴────────────────────────────┴───────────┴──────────
```

### HPA Implementation

**HPA Decision Engine Workflow:**

```
┌───────────────────────────────────────────────────────────────┐
│ Metrics Server (DaemonSet)                                    │
│ Collects kubelet resource metrics every 15 seconds            │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          ↓
  ┌──────────────────────────────────────────────────┐
  │ Pod CPU Metrics:                                 │
  │ ├─ Pod 1: 42% CPU                               │
  │ ├─ Pod 2: 48% CPU                               │
  │ └─ Pod 3: 45% CPU                               │
  │ Avg: (42+48+45)/3 = 45% CPU                     │
  └──────────────────────┬───────────────────────────┘
                         │
                         ↓
  ┌──────────────────────────────────────────────────┐
  │ HPA Controller (every 15 seconds)                │
  │ Reads HPA config:                               │
  │ ├─ Target CPU: 80%                             │
  │ ├─ Min pods: 2                                 │
  │ ├─ Max pods: 10                                │
  │ └─ Cooldown: 300 seconds (5 min)               │
  └──────────────────────┬───────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ↓                               ↓
   Current: 45%              Compare:  45% < 80%
   Target: 80%               (Don't scale up)
        │                            │
        └─────────────────┬──────────┘
                          ↓
                  ┌───────────────┐
                  │ Check history │
                  ├───────────────┤
                  │ Last scale: ?  │
                  └───────────────┘
                          │
            ┌─────────────┴─────────────┐
            ↓                           ↓
    < 5 min ago              >= 5 min ago
    (Still cooling down)    (Can scale now)
            │                           │
            └─ Keep current            ├─ Scale metrics drop
              replicas (3)             │  to 30%?
                                      │  Yes: Scale down
                                      │
                                      └─ kubectl scale ... --replicas=2
                                         └─ Evict pod gracefully
                                            └─ Cost savings ✅
```

```yaml
---
# HPA for Catalog (CPU-based autoscaling)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: catalog-hpa
spec:
  # Link to Deployment
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog
  
  # Min/max replicas
  minReplicas: 3
  maxReplicas: 10
  
  # Metrics to watch
  metrics:
  # CPU-based metric
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80  # Scale up if > 80%
  
  # Memory-based metric
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75  # Scale up if > 75%
  
  # Scaling behavior
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0      # Scale up immediately
      policies:
      - type: Percent
        value: 50                        # Add 50% more pods
        periodSeconds: 15
      - type: Pods
        value: 2                         # Or add 2 pods
        periodSeconds: 15
      selectPolicy: Max                  # Use whichever adds more
    
    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 50                        # Remove 50% of excess
        periodSeconds: 15
      - type: Pods
        value: 2                         # Or remove 2 pods
        periodSeconds: 15
      selectPolicy: Min                  # Use whichever removes fewer

---
# HPA for Cart (memory-based)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cart-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cart
  minReplicas: 3
  maxReplicas: 10
  
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70

---
# HPA for Orders (CPU + memory)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: orders-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orders
  minReplicas: 2
  maxReplicas: 8
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75

---
# Pod Disruption Budget (prevent evictions during scaling)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: catalog-pdb
spec:
  minAvailable: 2              # Always keep 2 pods running
  selector:
    matchLabels:
      app: catalog
```

### Metrics Server & Pod Status

```bash
# Install Metrics Server (via EKS add-on)
# Shows CPU/Memory in real-time

# View current metrics
kubectl top nodes
kubectl top pods -n default

# Watch HPA status
kubectl get hpa -w

# Example output:
# NAME          REFERENCE            TARGETS              MINPODS MAXPODS REPLICAS AGE
# catalog-hpa   Deployment/catalog   72%/80%, 60%/75%     3       10      4        5m
# cart-hpa      Deployment/cart      65%/70%              3       10      3        5m
# orders-hpa    Deployment/orders    85%/80%, 70%/75%     2       8       6        5m

# View HPA events
kubectl describe hpa catalog-hpa
```

---

## Section 19: Helm Charts for Microservices Deployment

### Problem: Repetitive Kubernetes Manifests

```
❌ BEFORE (Manual YAML):
├─ Each microservice needs 10+ YAML files
├─ Copy-paste causes inconsistencies
├─ Hard to maintain versions
├─ Difficult to test different configurations

✅ AFTER (Helm Charts):
├─ 1 Helm chart template = all YAML files
├─ {{ variables }} = DRY principle
├─ values.yaml = configuration management
├─ Easy to deploy multiple versions
├─ Share charts across teams
```

### Helm Chart Structure

**Helm Template Processing & Deployment Flow:**

```
┌──────────────────────────────────┐
│ Helm Chart Repository            │
│ (Docker Hub, Artifact Hub, etc)  │
└─────────────┬────────────────────┘
              │ helm pull catalog:1.0.0
              ↓
┌──────────────────────────────────┐
│ Local Directory: catalog/         │
├──────────────────────────────────┤
│ Chart.yaml                       │ (metadata)
│ values.yaml                      │ (defaults)
│ values-prod.yaml                 │ (environment override)
│ templates/                       │ (template files)
│  ├─ deployment.yaml              │
│  │  {{ .Values.image.tag }}      │ (placeholder)
│  │  {{ .Replic as }}             │
│  ├─ service.yaml                 │
│  ├─ configmap.yaml               │
│  └─ hpa.yaml                     │
└─────────────┬────────────────────┘
              │
         helm install --values values-prod.yaml
              │
              ↓
┌──────────────────────────────────┐
│ Helm Go Template Engine          │
├──────────────────────────────────┤
│ INPUT:                           │
│  deployment.yaml:                │
│   image: {{ .Values.image.tag }} │
│  values-prod.yaml:               │
│   image.tag: "v2.1.0"            │
│                                  │
│ PROCESS: Replace {{ }} vars      │
│                                  │
│ OUTPUT:                          │
│  deployment.yaml:                │
│   image: "v2.1.0"                │
│  (All templates rendered)        │
└─────────────┬────────────────────┘
              │
         kubectl apply -f -
         (or ArgoCD auto-deploy)
              │
              ↓
┌──────────────────────────────────┐
│ EKS Cluster                      │
│ ├─ Deployment created            │
│ ├─ Service created               │
│ ├─ ConfigMap mounted             │
│ └─ HPA configured                │
│   (Auto-scaling enabled)         │
└──────────────────────────────────┘
```

```
retail-charts/
├── catalog/              # Chart for Catalog microservice
│   ├── Chart.yaml        # Chart metadata (name, version)
│   ├── values.yaml       # Default values (image, replicas, etc.)
│   ├── templates/
```
│   │   ├── deployment.yaml      # Deployment template
│   │   ├── service.yaml         # Service template
│   │   ├── configmap.yaml       # ConfigMap template
│   │   ├── serviceaccount.yaml  # ServiceAccount template
│   │   ├── hpa.yaml             # HPA template
│   │   ├── pdb.yaml             # Pod Disruption Budget
│   │   └── _helpers.tpl         # Helper functions
│   ├── values-prod.yaml  # Override values for production
│   └── values-dev.yaml   # Override values for development
│
└── cart/                 # Similar structure for other services
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── ...
```

### Helm Chart Template Example

```yaml
# Chart.yaml
apiVersion: v2
name: catalog
description: "Catalog microservice Helm chart"
version: 1.0.0
appVersion: "1.0.0"

---
# values.yaml (default values)
replicaCount: 3

image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/catalog
  tag: "1.0.0"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

config:
  DB_HOST: "catalog-mysql.default.svc.cluster.local"
  DB_PORT: "3306"
  DATABASE_NAME: "catalogdb"
  LOG_LEVEL: "INFO"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

serviceAccount:
  create: true
  name: catalog

secrets:
  secretName: "catalog-db-secret"
  awsRegion: "us-east-1"

---
# templates/deployment.yaml (using values)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        
        ports:
        - containerPort: 8080
        
        envFrom:
        - configMapRef:
            name: {{ include "catalog.configmapname" . }}
        
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
        
        resources: {{- toYaml .Values.resources | nindent 10 }}
        
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
      
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          volumeAttributes:
            secretProviderClass: "catalog-secrets"

---
# templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
spec:
  type: ClusterIP
  selector:
    app: {{ .Chart.Name }}
  ports:
  - port: 80
    targetPort: 8080

---
# templates/hpa.yaml
{{ if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Chart.Name }}-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Chart.Name }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{ end }}

---
# values-prod.yaml (production overrides)
replicaCount: 5

image:
  tag: "1.2.0"

autoscaling:
  minReplicas: 5
  maxReplicas: 20
  targetCPUUtilizationPercentage: 75

resources:
  requests:
    cpu: "200m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

### Helm Deployment

```bash
# Install a single chart
helm install catalog ./retail-charts/catalog \
  --values values-prod.yaml \
  --namespace default

# Install all charts (microservices)
helm install catalog ./charts/catalog
helm install cart ./charts/cart
helm install checkout ./charts/checkout
helm install orders ./charts/orders
helm install ui ./charts/ui

# Upgrade chart (new version)
helm upgrade catalog ./charts/catalog --values values-prod.yaml

# Rollback to previous version
helm rollback catalog 1

# View release status
helm list
helm status catalog --show-resources

# View generated manifests (without applying)
helm template catalog ./charts/catalog --values values-prod.yaml
```

---

## Section 20: Observability with OpenTelemetry

### Problem: Blind Spots in Production

```
What Happens When Catalog Microservice Calls Orders?

❌ WITHOUT OBSERVABILITY:
Application error → "Database connection timeout"
Questions without answers:
├─ Which service is slow?
├─ Is it the database or network?
├─ Are there errors in other services?
├─ How did the request get routed?
└─ Which user triggered this?

✅ WITH OBSERVABILITY (OpenTelemetry):
Complete visibility:
├─ Trace: Track request across all services
├─ Logs: Detailed message at each step
├─ Metrics: CPU, memory, latency, error rates
├─ Context: User ID, request ID, version
```

### Three Pillars of Observability

```
OBSERVABILITY STACK
═════════════════════════════════════════════════════════════════

1. TRACES (Request flow across services)
   ├─ Parent trace: user request (req-123)
   ├─ Span 1: UI service (renders page)
   ├─ Span 2: Catalog service (fetches products) ← 200ms
   ├─ Span 3: Cart service (gets user cart) ← 150ms
   ├─ Span 4: Orders service (fetches recent orders) ← X (timeout)
   ├─ Total latency: 600ms (timeout)
   └─ OpenTelemetry exports to AWS X-Ray / Jaeger

2. LOGS (Detailed events)
   ├─ 2024-02-09T10:15:32Z [catalog] INFO: Request received from UI
   ├─ 2024-02-09T10:15:32Z [catalog] DEBUG: DB query: SELECT *...
   ├─ 2024-02-09T10:15:33Z [catalog] DEBUG: DB query took 500ms
   ├─ 2024-02-09T10:15:33Z [catalog] INFO: Response sent (200 items)
   └─ OpenTelemetry exports to CloudWatch / Elasticsearch

3. METRICS (Aggregated data)
   ├─ catalog_http_requests_total: 1234 (total requests)
   ├─ catalog_http_request_duration_seconds: p99=200ms (latency)
   ├─ catalog_database_connection_pool_used: 8/10 (resource usage)
   ├─ orders_request_errors_total: 5 (error rate)
   └─ prometheus_scrapes: every 15 seconds

═════════════════════════════════════════════════════════════════════

DATA FLOW
═════════════════════════════════════════════════════════════════════

Application Pods (with OTEL SDK)
    │
    ├─ Traces library (trace-collector)
    ├─ Logs library (log-shipper)
    └─ Metrics library (metrics-exporter)
            │
            ↓
    OTEL Collector (DaemonSet on every node)
            │
    ┌───────┼───────┐
    │       │       │
    ↓       ↓       ↓
AWS X-Ray CloudWatch Prometheus
(Traces)  (Logs)     (Metrics)
```

### OpenTelemetry Implementation

**Complete Observability Data Flow:**

```
┌─────────────────────────────────────────────────────────────┐
│ APPLICATIONS (Microservices)                                │
│ ├─ Catalog (Python Flask)                                  │
│ ├─ Cart (Node.js/Express)                                  │
│ ├─ Orders (Java Spring Boot)                               │
│ ├─ Checkout (Go)                                           │
│ └─ UI (React)                                              │
└──────────────────┬──────────────────────────────────────────┘
                   │ (SDK: Import OTEL libraries)
                   │
          ┌────────┴────────┬────────────┬────────────┐
          ↓                 ↓            ↓            ↓
   ┌──────────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐
   │   TRACES     │ │    LOGS    │ │ METRICS  │ │TXN CTXTS │
   │ (Span data)  │ │  (Console) │ │(CPU,Mem) │ │(Baggage) │
   └──────────────┘ └────────────┘ └──────────┘ └──────────┘
          │              │             │              │
          └──────────────┼─────────────┼──────────────┘
                         │
              ┌──────────┴──────────┐
              │ OTEL Instrumentation│
              │   Libraries         │
              │ ├─ otel-api         │
              │ ├─ otel-sdk         │
              │ ├─ auto-instrumentation
              │ └─ propagation-rules
              └──────────┬──────────┘
                         │
         ┌───────────────┴────────────────┐
         │ SDK Exporter                   │
         │ (Format: OTLP protocol)        │
         │ (gRPC or HTTP)                 │
         └───────────────┬────────────────┘
                         │
         ┌───────────────┴────────────────────────────┐
         │ ADOT Collector DaemonSet                   │
         │ (Every node has one pod)                   │
         ├─────────────────────────────────────────────┤
         │ ├─ Receives: Traces, Logs, Metrics         │
         │ ├─ Process: Batch, filter, sample          │
         │ ├─ Export: Send to AWS services            │
         │ └─ Config: ConfigMap-driven                │
         └───────────────┬────────────────────────────┘
                         │
       ┌─────────────────┼─────────────────┐
       ↓                 ↓                 ↓
  ┌──────────────┐ ┌─────────────┐ ┌──────────────┐
  │  AWS X-Ray   │ │CloudWatch   │ │ Prometheus   │
  │   (Traces)   │ │   (Logs)    │ │  (Metrics)   │
  │              │ │             │ │              │
  │ ├─Service map│ │ ├─Log groups│ │├─Scrape port│
  │ ├─Latency    │ │ ├─Timestamps│ │├─Time series│
  │ └─Errors     │ │ └─Full text │ │└─Dashboards │
  └──────────────┘ └─────────────┘ └──────────────┘
       ↑                ↑                  ↑
       └────────────────┼──────────────────┘
                        │
              ┌─────────┴──────────┐
              │ DEBUGGING:         │
              │ ├─X-Ray traces     │
              │ ├─Error logs       │
              │ ├─Performance data │
              │ └─Alert triggers   │
              └────────────────────┘
```

```yaml
---
# ADOT Collector DaemonSet (OTEL Collector)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: adot-collector
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: adot-collector
  
  template:
    metadata:
      labels:
        app: adot-collector
    
    spec:
      serviceAccountName: adot-collector
      
      containers:
      - name: adot-collector
        image: public.ecr.aws/aws-observability/aws-for-fluent-bit:latest
        
        ports:
        - containerPort: 4317  # OTLP gRPC
          name: otlp-grpc
        - containerPort: 4318  # OTLP HTTP
          name: otlp-http
        
        volumeMounts:
        - name: config
          mountPath: /etc/otel
        
        env:
        - name: AWS_REGION
          value: "us-east-1"
        
        - name: AWS_XRAY_SDK_ENABLED
          value: "true"
      
      volumes:
      - name: config
        configMap:
          name: adot-collector-config

---
# OTEL Collector Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: adot-collector-config
  namespace: monitoring
data:
  otel-collector-config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      prometheus:
        config:
          scrape_configs:
          - job_name: 'kubernetes-pods'
            kubernetes_sd_configs:
            - role: pod
    
    processors:
      batch:
        send_batch_size: 100
        timeout: 10s
      
      resource:
        attributes:
          - key: environment
            value: production
            action: insert
          - key: cluster
            value: retail-dev-eksdemo
            action: insert
    
    exporters:
      awsxray:
        region: us-east-1
      
      awscloudwatch:
        region: us-east-1
        log_group_name: /aws/eks/otel
        log_stream_name: otel-stream
      
      prometheusremotewrite:
        endpoint: "http://prometheus:9009/api/v1/write"
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [awsxray]
        
        metrics:
          receivers: [otlp, prometheus]
          processors: [batch, resource]
          exporters: [prometheusremotewrite, awscloudwatch]
        
        logs:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [awscloudwatch]

---
# Application Pod with OTEL SDK
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
spec:
  template:
    spec:
      containers:
      - name: catalog
        image: retail-store/catalog:v1.0.0
        
        env:
        # OTEL Configuration
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://adot-collector:4317"
        
        - name: OTEL_EXPORTER_OTLP_HEADERS
          value: "X-Amzn-Trace-Id=true"
        
        - name: OTEL_METRICS_EXPORTER
          value: "otlp"
        
        - name: OTEL_TRACES_EXPORTER
          value: "otlp"
        
        - name: OTEL_LOGS_EXPORTER
          value: "otlp"
        
        - name: OTEL_SERVICE_NAME
          value: "catalog"
        
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.name=catalog,service.version=1.0.0"
```

### Application Code: Instrumentation

```python
# catalog_service/main.py

from opentelemetry import trace, metrics, logs as otel_logs
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
import logging

# Setup OTEL exporters
trace_exporter = OTLPSpanExporter(endpoint="http://adot-collector:4317")
trace_provider = TracerProvider()
trace_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
trace.set_tracer_provider(trace_provider)

# Setup metrics
metrics_exporter = OTLPMetricExporter(endpoint="http://adot-collector:4317")
meter_provider = MeterProvider(metric_readers=[metrics_exporter])
metrics.set_meter_provider(meter_provider)

# Auto-instrumentation
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Get tracer
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Create custom metrics
request_counter = meter.create_counter(
    name="catalog_requests",
    description="Total requests to catalog",
    unit="1"
)

request_duration = meter.create_histogram(
    name="catalog_request_duration_ms",
    description="Request duration in milliseconds",
    unit="ms"
)

@app.route('/api/v1/products', methods=['GET'])
def get_products():
    with tracer.start_as_current_span("get_products") as span:
        span.set_attribute("user.id", request.headers.get('X-User-ID'))
        span.set_attribute("method", "GET")
        span.set_attribute("path", "/api/v1/products")
        
        request_counter.add(1, {"endpoint": "/products"})
        
        start_time = time.time()
        
        try:
            # Fetch from database
            with tracer.start_as_current_span("database_query"):
                products = db.query("SELECT * FROM products LIMIT 100")
            
            # Process response
            with tracer.start_as_current_span("process_response"):
                response_data = [p.to_dict() for p in products]
            
            duration_ms = (time.time() - start_time) * 1000
            request_duration.record(duration_ms, {"endpoint": "/products"})
            
            span.add_event("products_fetched", {
                "count": len(response_data)
            })
            
            return {"data": response_data, "status": "success"}, 200
        
        except Exception as e:
            span.set_attribute("error.type", type(e).__name__)
            span.set_attribute("error.message", str(e))
            span.add_event("error", {"message": str(e)})
            
            logging.error(f"Error fetching products: {e}")
            return {"error": "Internal server error"}, 500
```

### Observability Queries

```bash
# View traces in AWS X-Ray
# Console: AWS X-Ray → Traces
# Query: "service(catalog) from(order) duration > 500"
# Shows: Catalog → Orders requests taking > 500ms

# View metrics in CloudWatch
# Console: CloudWatch → Dashboards
# Metric: "catalog_requests" (request count)
# Metric: "catalog_request_duration_ms" (latency percentiles)

# View logs in CloudWatch Logs
# Console: CloudWatch → Logs
# Log group: /aws/eks/otel
# Filter: "service.name=catalog AND error"
# Shows: All catalog service errors

# Prometheus queries
# Query: rate(catalog_requests[5m])
# Result: 20 requests per second
```

---

## Complete Microservices Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     COMPLETE SYSTEM ARCHITECTURE                     │
│                    (All Sections Combined)                           │
└──────────────────────────────────────────────────────────────────────┘

LAYER 1: EXTERNAL ENTRY POINT
┌──────────────────────────────────────────────────────────────────────┐
│  Browser/Client → DNS (Route53) → ALB (AWS Load Balancer)            │
│  Domain: app.example.com                                             │
│  Path routing: /api/*, /images/*, / → different services            │
└──────────────────────────────────────────────────────────────────────┘

LAYER 2: KUBERNETES CLUSTER (EKS)
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ MICROSERVICES (with HPA & Helm)                                 │ │
│  │                                                                 │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │ │
│  │  │ Catalog  │  │ Cart     │  │ Orders   │  │ Checkout     │  │ │
│  │  │ (3-10)   │  │ (3-10)   │  │ (2-8)    │  │ (2-8)        │  │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘  │ │
│  │       ↓              ↓             ↓              ↓            │ │
│  │   HPA (80%)      HPA (70%)     HPA (80%)      HPA (80%)       │ │
│  │                                                               │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ UI Service (3-12 replicas)                           │   │ │
│  │  │ (User-facing frontend)                               │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                               │ │
│  │  System Add-ons:                                             │ │
│  │  ├─ Pod Identity Agent (auth)                               │ │
│  │  ├─ Metrics Server (HPA metrics)                            │ │
│  │  ├─ ALB Ingress Controller (load balancer)                  │ │
│  │  ├─ EBS CSI Driver (storage)                                │ │
│  │  ├─ Secrets Store CSI Driver (secrets injection)            │ │
│  │  ├─ External DNS (automatic DNS)                            │ │
│  │  ├─ ADOT Collector (observability traces/logs/metrics)      │ │
│  │  └─ kube-proxy, CoreDNS, VPC CNI (core services)            │ │
│  │                                                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘

LAYER 3: AWS DATA PLANE (Managed Services)
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ RDS MySQL        │  │ RDS PostgreSQL   │  │ ElastiCache      │  │
│  │ (Catalog DB)     │  │ (Orders DB)      │  │ Redis (Sessions) │  │
│  │ - Multi-AZ       │  │ - Multi-AZ       │  │ - Multi-AZ       │  │
│  │ - Auto-backups   │  │ - Auto-backups   │  │ - Failover       │  │
│  │ - Encrypted      │  │ - Encrypted      │  │ - Encrypted      │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ DynamoDB (NoSQL) │  │ SQS Queue        │  │ Secrets Manager  │  │
│  │ (Cart DB)        │  │ (Order events)   │  │ (DB passwords)   │  │
│  │ - Serverless     │  │ - Async          │  │ - Encrypted      │  │
│  │ - Auto-scale     │  │ - Reliable       │  │ - Auto-rotate    │  │
│  │ - PITR           │  │ - Decoupling     │  │ - Audit trail    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ EBS Volumes      │  │ EC2 Instances    │  │ Route53          │  │
│  │ (StatefulSets)   │  │ (Worker nodes)   │  │ (DNS)            │  │
│  │ - Encrypted      │  │ - Auto-scaling   │  │ - Auto-updated   │  │
│  │ - Snapshots      │  │ - Multi-AZ       │  │ - High available │  │
│  │ - Expansion      │  │ - Secure         │  │ - IP aliasing    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────────────────────────────┐ │
│  │ ECR (Container)  │  │ CloudWatch / X-Ray (Observability)       │ │
│  │ - Image registry │  │ - Logs: /aws/eks/*                       │ │
│  │ - Encrypted      │  │ - Metrics: CPU, memory, custom           │ │
│  │ - Scan images    │  │ - Traces: X-Ray service map              │ │
│  │ - Lifecycle      │  │ - Dashboards: Real-time monitoring       │ │
│  └──────────────────┘  └──────────────────────────────────────────┘ │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘

LAYER 4: CI/CD PIPELINE
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Actions (CI)  →  Amazon ECR (Registry)  →  ArgoCD (CD)      │
│  - Build image        - Store images             - Deploy to EKS    │
│  - Push to ECR        - Tag versions             - GitOps sync      │
│  - OIDC auth          - KMS encryption           - Helm deploy      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Interview Q&A - Part 2

### Q1: "Describe the complete data flow for a user shopping on this platform"

**Answer**:
> "It's a complete microservices flow:
>
> **User Journey**:
> 1. User visits app.example.com
> 2. Browser DNS lookup → Route53 → ALB IP (208.1.1.1)
> 3. ALB (port 80) → Ingress rule → UI service
> 4. UI pod returns HTML/CSS/JS (React app)
> 5. JavaScript makes API calls to backend services
>
> **API Request Flow (example: Get Products)**:
> 1. Browser: GET /api/v1/catalog/products
> 2. ALB routes → Catalog service (ClusterIP)
> 3. Service → Pod 1, 2, or 3 (load balanced)
> 4. Catalog pod receives request
> 5. Pod reads DB credentials from /mnt/secrets (AWS Secrets Manager)
> 6. Pod connects to RDS MySQL (catalog-mysql.default.svc)
> 7. MySQL returns product list
> 8. Pod formats response (JSON)
> 9. Response returns to browser
> 10. JavaScript renders product list
>
> **Add to Cart**:
> 1. User clicks "Add to Cart"
> 2. Browser: POST /api/v1/cart/{userId}
> 3. ALB → Cart service
> 4. Cart pod uses Pod Identity to access DynamoDB
> 5. Pod puts item in DynamoDB carts table
> 6. Response: success
>
> **Checkout**:
> 1. User clicks "Checkout"
> 2. Browser: POST /api/v1/checkout/payment
> 3. ALB → Checkout service
> 4. Checkout pod reads Redis credentials from Secrets Manager
> 5. Pod connects to ElastiCache Redis
> 6. Stores session token in Redis (expires in 1 hour)
> 7. Returns token to browser
>
> **Order Placement**:
> 1. User submits order form
> 2. Browser: POST /api/v1/orders
> 3. ALB → Orders service
> 4. Orders pod validates payment (checks Redis)
> 5. Orders pod creates database record (RDS PostgreSQL)
> 6. Orders pod publishes event to SQS queue
> 7. Returns order confirmation
> 8. Queue worker processes order asynchronously
>
> **Scaling Example**:
> - Traffic spike → Metrics Server detects high CPU
> - HPA notices CPU > 80%
> - HPA increases Catalog replicas: 3 → 5
> - New pods start
> - ALB adds new pods to target group
> - Traffic distributed across 5 pods
>
> **Observability**:
> - Each request has unique trace ID (X-Amzn-Trace-Id)
> - OTEL SDK captures traces from all services
> - ADOT Collector exports to X-Ray
> - Developer can see: UI → Catalog → MySQL (timing, errors)
> - CloudWatch logs: detailed messages from each pod
> - Prometheus metrics: request rate, error rate, latency
>
> **All of this automated, scalable, observable, and secure!**"

---

### Q2: "How does HPA work, and what prevents load balancing issues?"

**Answer**:
> "HPA is elegant but needs careful configuration:
>
> **How HPA Works**:
> 1. Metrics Server collects CPU/memory every 15 seconds
> 2. HPA controller queries metrics
> 3. Calculates: desired_pods = current_pods × (current_metric / target_metric)
> 4. Example: 3 pods × (85% CPU / 80% target) = 3.19 → Scale to 4 pods
> 5. Deployment updates: replicas 3 → 4
> 6. Kubernetes scheduler finds node with capacity
> 7. New pod starts
>
> **Issues Without Proper Config**:
> ❌ Thundering Herd: All pods scale up at once → crash
> ❌ Flapping: Scale up/down constantly (waste)
> ❌ Graceful Shutdown: Pod killed mid-request → user error
>
> **Solutions**:
>
> **1. Gradual Scaling**
> ```
> scaleUp:
>   stabilizationWindowSeconds: 0  (scale immediately)
>   maxRatePercent: 50              (add 50% more pods gradually)
> scaleDown:
>   stabilizationWindowSeconds: 300 (wait 5 min before scaling down)
>   maxRate: 2                      (remove max 2 pods per action)
> ```
>
> **2. Pod Disruption Budgets (PDB)**
> - Ensures minimum availability during evictions
> - minAvailable: 2 (always keep 2 Catalog pods running)
> - Prevents all pods from being killed at once
>
> **3. Graceful Shutdown**
> - preStop hook (wait for connection draining)
> - terminationGracePeriodSeconds: 30 (wait 30s before force kill)
> - Ensures inflight requests complete
>
> **4. Resource Requests/Limits**
> - requests: tells scheduler node has capacity
> - limits: prevents OOM kills
> - HPA uses requests for scaling decisions
>
> **Real Example**:
> - Catalog: 3 pods, CPU request 100m, limit 500m
> - Traffic increases → CPU usage = 85%
> - HPA: 3 × (85/80) = 3.19 → scale to 4
> - Wait 1 minute (stabilization)
> - Traffic stays high → CPU still 85%
> - HPA calculates again: 4 × (85/80) = 4.25 → scale to 5
> - Continue until: (current × usage%) ≤ (pods × limit)
>"

---

### Q3: "What's the benefit of Helm vs raw Kubernetes manifests?"

**Answer**:
> "Helm solves the DRY problem in Kubernetes deployment:
>
> **Without Helm (Repetitive)**:
> - Catalog service: 11 YAML files (deployment, service, configmap, hpa, pdb, secret, sa, etc.)
> - Cart service: 11 YAML files (same structure, different names)
> - Orders service: 11 YAML files
> - Total: 55 YAML files to maintain
>
> **Issues**:
> ❌ Copy-paste errors
> ❌ Version mismatch (some services use old config)
> ❌ Hard to maintain consistency
> ❌ Complex to deploy variations (dev/test/prod)
>
> **With Helm**:
> - 1 Chart = 1 template with placeholders
> - {{ .Values.image.tag }} = insert value from values.yaml
> - {{ if .Values.autoscaling.enabled }} = conditional logic
> - 1 Helm release per service = 11 YAML files auto-generated
>
> **Benefits**:
> 1. **DRY Principle**: Write once, use everywhere
> 2. **Versioning**: helm list shows all releases
> 3. **Rollback**: helm rollback catalog 1 (previous version)
> 4. **Variations**: values-prod.yaml, values-dev.yaml
> 5. **Reusability**: Share charts across teams
> 6. **Package/Publish**: Upload to Helm Hub, share publicly
>
> **Example**:
> ```bash
> # Deploy Catalog to 3 environments
> helm install catalog ./charts/catalog -f values-dev.yaml
> helm install catalog ./charts/catalog -f values-test.yaml
> helm install catalog ./charts/catalog -f values-prod.yaml
> # All use same chart, different configurations
> ```
>
> **Production Workflow**:
> 1. Develop app code
> 2. Push to GitHub
> 3. GitHub Actions builds image → ECR
> 4. Update values.yaml: image.tag = new version
> 5. Git commit
> 6. ArgoCD detects change
> 7. ArgoCD runs: helm upgrade catalog ./charts/catalog
> 8. New pods deployed (zero-downtime rolling update)
>
> **Audit Trail**: Complete history of every helm release, version, what changed"

---

### Q4: "How does observability help with the microservices architecture?"

**Answer**:
> "Observability is critical with microservices because there are many moving parts:
>
> **Without Observability**:
> - User reports: 'App is slow'
> - Question: Which service is slow?
> - Answer: 'I don't know'
>
> **With OpenTelemetry**:
>
> **1. Distributed Tracing**:
> - Single request has trace ID: req-abc123
> - Follows across all services:
>   ├─ Catalog span (100ms) - fast
>   ├─ Orders span (450ms) - SLOW!
>   └─ Cart span (80ms) - fast
> - root cause: Orders service is slow
> - Drill down: Orders → PostgreSQL query took 400ms
> - Fix: Add database index
>
> **2. Logs with Context**:
> ```
> 2024-02-09T10:15:33.123Z [catalog] INFO: Request received
>   trace_id=req-abc123
>   user_id=user-456
>   request_id=req-abc123
>   service=catalog
>   version=1.0.0
> 2024-02-09T10:15:33.124Z [catalog] DEBUG: DB query started
>   query_type=SELECT
>   table=products
> 2024-02-09T10:15:33.523Z [catalog] DEBUG: DB query completed
>   duration_ms=400
>   rows_returned=100
> ```
> - All logs tied to same request
> - Can search: trace_id=req-abc123
> - See complete request flow
>
> **3. Metrics (Real-time)**:
> - Catalog request rate: 100 req/s (normal)
> - Orders request rate: 50 req/s but latency spiked: 450ms (spike!)
> - Error rate Orders: 5% (something wrong)
> - Alert threshold triggered
>
> **4. Dashboard (Visual)**:
> - Service map shows all dependencies
> - Color coded: Green (ok), Yellow (slow), Red (errors)
> - Can see: UI → Catalog → MySQL → RDS
> - Which links are slow: 450ms between Orders and PostgreSQL
>
> **5. Root Cause Analysis (RCA)**:
> - Alert: Orders service errors high
> - Check trace: Orders pod logs show 'connection timeout'
> - Check metrics: PostgreSQL CPU at 95%
> - Check RDS console: Query running for 30 minutes
>  - Statement: SELECT with bad join (missing index)
> - Fix: Add index, query completes in 10ms
> - Deploy + Monitor
>
> **Without OTEL**: Blindly restart services hoping it helps  
> **With OTEL**: Precise diagnosis, targeted fix
>"

---

