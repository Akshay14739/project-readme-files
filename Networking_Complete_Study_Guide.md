# Complete Networking Study Guide
### Pre-Kubernetes Mastery | Based on Abishek & Kunal's Video Lectures

---

# 📋 TABLE OF CONTENTS
1. [What is a Network & The Internet](#1-what-is-a-network--the-internet)
2. [IP Addresses & Binary Fundamentals](#2-ip-addresses--binary-fundamentals)
3. [IPv4 vs IPv6](#3-ipv4-vs-ipv6)
4. [Subnets & CIDR Notation](#4-subnets--cidr-notation)
5. [How the Internet Started (ARPANET)](#5-how-the-internet-started-arpanet)
6. [Protocols — What, Why, How](#6-protocols--what-why-how)
7. [The OSI Model (7 Layers)](#7-the-osi-model-7-layers)
8. [TCP/IP Model](#8-tcpip-model)
9. [DNS — Domain Name System](#9-dns--domain-name-system)
10. [Ports & Sockets](#10-ports--sockets)
11. [HTTP & HTTPS](#11-http--https)
12. [NAT — Network Address Translation](#12-nat--network-address-translation)
13. [VPC — Virtual Private Cloud (AWS)](#13-vpc--virtual-private-cloud-aws)
14. [Subnets in AWS (Public & Private)](#14-subnets-in-aws-public--private)
15. [Internet Gateway & Route Tables](#15-internet-gateway--route-tables)
16. [Security Groups & NACLs](#16-security-groups--nacls)
17. [NAT Gateway](#17-nat-gateway)
18. [Load Balancer](#18-load-balancer)
19. [MAC Addresses & ARP](#19-mac-addresses--arp)
20. [AWS Project Walkthrough](#20-aws-project-walkthrough)

---

# 1. What is a Network & The Internet

## Objective
Understand the foundational definition of networking before diving into technical details.

## Key Concepts

- **Computer Network** — Two or more computers connected to each other. That's it. No complex definition needed.
- **Internet** — A collection of computer networks connected together on a **global scale**.
  - Your computer → connected to your router → connected to your ISP → connected to other networks worldwide = Internet

## Architecture Diagram

```
[Your PC] ──┐
            ├──[Router/Wi-Fi]──[ISP]──[Internet Backbone]──[Other Networks Worldwide]
[Phone]  ──┘
```

- **Why it matters for Kubernetes:** Kubernetes clusters are distributed across multiple nodes (machines) that communicate over a network. Understanding how machines talk to each other is the foundation.

---

# 2. IP Addresses & Binary Fundamentals

## Objective
Understand what an IP address is, why it exists, how it is structured, and how computers read it.

## What is an IP Address?

- A **unique identification number** assigned to every device connected to a network.
- Just like houses have unique house numbers, devices have unique IP addresses.
- Without it, you cannot: track, monitor, block, or route traffic to/from a specific device.

## Real-World Analogy

```
Home Network (Wi-Fi Router)
│
├── Device 1 (Laptop)     → 192.168.1.2
├── Device 2 (Phone)      → 192.168.1.3
├── Device 3 (Tablet)     → 192.168.1.4
└── Device 4 (Smart TV)   → 192.168.1.5
```
- If a device makes a suspicious payment, the IP address tells you exactly WHICH device did it.
- If you want to block YouTube for one device only → you block by its IP address.

## IPv4 Format

- IP addresses follow the **IPv4 standard**.
- Format: `A.B.C.D` — four numbers separated by dots.
- Example: `192.168.1.4`, `172.16.0.1`, `10.0.0.1`
- Each number (called an **octet**) ranges from **0 to 255**.
- **Why 0–255?** Because each octet is **1 byte = 8 bits**, and the max value of 8 bits in binary is 255.

## Binary Deep Dive

```
IPv4 Address = 4 bytes = 32 bits total

Bit positions (right to left):
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
  2^7     2^6     2^5     2^4     2^3     2^2     2^1     2^0
  128      64      32      16       8       4       2       1
```

**Example — How does 192 look in binary?**
```
192 = 128 + 64 = 2^7 + 2^6
Binary: 1  1  0  0  0  0  0  0
```

**Why max is 255:**
```
All 8 bits ON = 1 1 1 1 1 1 1 1
= 128+64+32+16+8+4+2+1 = 255
```

**Invalid IP Example:**
- `192.600.12.254` → INVALID because 600 > 255

## How to Check Your IP Address

```bash
# Linux / Mac
ifconfig

# Windows
ipconfig

# Modern Linux
ip addr
```

- **What it shows:** Your device's IP address, subnet mask, and more.
- **Why:** Used for debugging network issues, verifying configuration.

---

# 3. IPv4 vs IPv6

## The Problem with IPv4

- IPv4 gives us: `256 × 256 × 256 × 256 = ~4.3 billion` unique addresses.
- The internet grew so fast that **we ran out of IPv4 addresses**.

## IPv6 — The Solution

| Feature | IPv4 | IPv6 |
|---|---|---|
| Format | `192.168.1.1` | `2001:0db8:85a3:0000:0000:8a2e:0370:7334` |
| Bits | 32 bits | 128 bits |
| Total Addresses | ~4.3 billion | ~340 undecillion (3.4 × 10^38) |
| Separator | Dot (`.`) | Colon (`:`) |
| Usage Today | Still dominant | Growing adoption |

- **Why IPv6 matters for Kubernetes:** Modern cloud platforms and Kubernetes support IPv6 for pod and service networking.

---

# 4. Subnets & CIDR Notation

## Objective
Understand how large networks are divided into smaller, manageable sub-networks.

## What is a Subnet?

- A **subnet** (sub-network) is a logical division of a larger network.
- Purpose: Organize IP address space, improve security, and control traffic flow.

## CIDR Notation

- **CIDR** = Classless Inter-Domain Routing.
- Format: `IP_Address / Prefix_Length`
- Example: `192.168.1.0/24`

## How to Read CIDR

```
192.168.1.0/24

"24" = the first 24 bits are FIXED (network part)
Remaining 8 bits = HOST part (can change)

Binary breakdown:
11000000.10101000.00000001.XXXXXXXX
|←────────── 24 bits fixed ────────→|←8 bits free→|

Number of hosts = 2^8 = 256 addresses (192.168.1.0 to 192.168.1.255)
```

## CIDR Quick Reference

| CIDR | Fixed Bits | Host Bits | Total IPs |
|---|---|---|---|
| /8 | 8 | 24 | 16,777,216 |
| /16 | 16 | 16 | 65,536 |
| /24 | 24 | 8 | 256 |
| /28 | 28 | 4 | 16 |
| /32 | 32 | 0 | 1 (single host) |

## Subnet Examples in Real Networks

```
Company Network: 10.0.0.0/16
│
├── Subnet A (Dev):     10.0.1.0/24   → 256 IPs
├── Subnet B (Prod):    10.0.2.0/24   → 256 IPs
└── Subnet C (DB):      10.0.3.0/24   → 256 IPs
```

- **Why subnets matter for Kubernetes:** Each Kubernetes pod gets an IP. Subnets define how many pods can exist in a given network range.

---

# 5. How the Internet Started (ARPANET)

## The Story

- **Cold War context:** USA and USSR were racing in technology.
- USSR launched **Sputnik** (1957) — world's first satellite.
- USA responded by creating **ARPA** (Advanced Research Projects Agency).
- ARPA's challenge: How do geographically spread facilities communicate?

## ARPANET — The First Internet

```
[MIT] ──────── [Stanford]
  │                │
[UCLA] ──────── [Univ. of Utah]

These 4 nodes = the first ARPANET (1969)
```

- Used **TCP** (Transmission Control Protocol) for file transfer.
- This eventually evolved into the modern internet.

## Evolution Timeline

```
1957 → Sputnik launched
1969 → ARPANET (4 nodes)
1970s → TCP/IP developed (Vint Cerf & Bob Kahn)
1989 → WWW invented (Tim Berners-Lee)
1990s → Commercial internet explodes
Today → Billions of connected devices
```

---

# 6. Protocols — What, Why, How

## Objective
Understand what protocols are and why they are essential for communication.

## What is a Protocol?

- A **protocol** is a set of rules that defines HOW data is sent and received between devices.
- Think of it like a language: both sides must speak the same language to communicate.

## Real-World Analogy

```
Sending an Email:
1. Compose email (Application layer)
2. Attach sender/receiver info (Transport layer)
3. Route to correct server (Network layer)
4. Transmit physically (Physical layer)

Each step has RULES = Protocol
```

## Key Protocols You Must Know

| Protocol | Full Name | Layer | Purpose |
|---|---|---|---|
| HTTP | HyperText Transfer Protocol | Application | Web pages |
| HTTPS | HTTP Secure | Application | Encrypted web |
| FTP | File Transfer Protocol | Application | File transfer |
| SMTP | Simple Mail Transfer Protocol | Application | Sending email |
| TCP | Transmission Control Protocol | Transport | Reliable delivery |
| UDP | User Datagram Protocol | Transport | Fast, unreliable delivery |
| IP | Internet Protocol | Network | Routing packets |
| DNS | Domain Name System | Application | Name resolution |
| ARP | Address Resolution Protocol | Data Link | IP→MAC resolution |

## TCP vs UDP — When to Use What

| Feature | TCP | UDP |
|---|---|---|
| Reliability | ✅ Guaranteed delivery | ❌ No guarantee |
| Order | ✅ In-order delivery | ❌ May arrive out of order |
| Speed | Slower (overhead) | Faster (no overhead) |
| Use Case | Web, email, file transfer | Video streaming, gaming, DNS |
| Handshake | 3-way handshake | None |

### TCP 3-Way Handshake

```
Client                    Server
  │──── SYN ────────────→│   "I want to connect"
  │←─── SYN-ACK ─────────│   "OK, acknowledged"
  │──── ACK ────────────→│   "Got it, let's go!"
  │                       │
  │════ DATA TRANSFER ════│
```

- **SYN** = Synchronize (initiate connection)
- **ACK** = Acknowledge (confirm receipt)
- **Why TCP for Kubernetes:** Kubernetes API server, etcd, kubelet all use TCP for reliable communication.

---

# 7. The OSI Model (7 Layers)

## Objective
Understand the 7-layer framework that describes how data travels from one application to another across a network.

## Why OSI Exists

- Before OSI, different vendors had incompatible networking systems.
- OSI = a **standard model** so all vendors build compatible products.
- It separates concerns: each layer has one job.

## The 7 Layers (Top to Bottom)

```
┌───────────────────────────────────────────┐
│  7. Application Layer  (HTTP, DNS, SMTP)  │  ← What you see/use
├───────────────────────────────────────────┤
│  6. Presentation Layer (Encryption, SSL)  │  ← Format & encrypt
├───────────────────────────────────────────┤
│  5. Session Layer      (Sessions, auth)   │  ← Manage connections
├───────────────────────────────────────────┤
│  4. Transport Layer    (TCP, UDP)         │  ← Port-to-port delivery
├───────────────────────────────────────────┤
│  3. Network Layer      (IP, Routing)      │  ← IP addressing & routing
├───────────────────────────────────────────┤
│  2. Data Link Layer    (MAC, Ethernet)    │  ← Device-to-device on LAN
├───────────────────────────────────────────┤
│  1. Physical Layer     (Cables, Signals)  │  ← Raw bits on wire
└───────────────────────────────────────────┘
```

**Memory trick:** "**A**ll **P**eople **S**eem **T**o **N**eed **D**ata **P**rocessing"

## Layer-by-Layer Breakdown

### Layer 7 — Application Layer
- **What:** The layer users interact with directly.
- **Protocols:** HTTP, HTTPS, FTP, SMTP, DNS
- **Example:** You type `google.com` in Chrome → Chrome uses HTTP/HTTPS here.
- **Data unit:** Message/Data

### Layer 6 — Presentation Layer
- **What:** Translates data formats; handles encryption/decryption and compression.
- **Examples:** SSL/TLS encryption, JPEG compression, ASCII/Unicode encoding.
- **Why:** Ensures data from sender can be read by receiver regardless of format.

### Layer 5 — Session Layer
- **What:** Manages sessions (conversations) between applications.
- **Examples:** Logging into a website → session is established. Logging out → session terminated.
- **Protocols:** NetBIOS, RPC

### Layer 4 — Transport Layer
- **What:** Ensures end-to-end data delivery between applications on different hosts.
- **Key concepts:** **Ports**, **TCP/UDP**, segmentation, flow control, error checking.
- **Data unit:** Segment (TCP) / Datagram (UDP)

```
Application → Transport Layer adds:
  [Source Port: 54321] [Destination Port: 443] [Data...]
```

### Layer 3 — Network Layer
- **What:** Handles logical addressing (IP) and routing packets across networks.
- **Key concepts:** **IP addresses**, **routers**, **routing tables**.
- **Data unit:** Packet

```
Network Layer adds:
  [Source IP: 192.168.1.5] [Dest IP: 142.250.80.46] [Segment...]
```

### Layer 2 — Data Link Layer
- **What:** Handles communication between devices on the **same local network (LAN)**.
- **Key concepts:** **MAC addresses**, **Ethernet**, **switches**, **ARP**, **frames**.
- **Data unit:** Frame

```
Data Link Layer adds:
  [Source MAC: AA:BB:CC:DD:EE:FF] [Dest MAC: 11:22:33:44:55:66] [Packet...]
```

- **Important:** MAC addresses change hop-to-hop. IP addresses stay the same end-to-end.

### Layer 1 — Physical Layer
- **What:** Raw transmission of bits (0s and 1s) over physical media.
- **Examples:** Ethernet cables, fiber optics, Wi-Fi radio waves, voltage signals.
- **Data unit:** Bits

## How Data Travels — Encapsulation & De-encapsulation

```
SENDER (Top → Down — Encapsulation):
Application:  [Data]
Transport:    [TCP Header][Data]
Network:      [IP Header][TCP Header][Data]
Data Link:    [MAC Header][IP Header][TCP Header][Data][Trailer]
Physical:     1010010101010011100... (bits on wire)

RECEIVER (Bottom → Up — De-encapsulation):
Physical:     Receives bits
Data Link:    Strips MAC header, checks MAC address
Network:      Strips IP header, checks IP address
Transport:    Strips TCP header, checks port
Application:  Delivers data to correct app
```

---

# 8. TCP/IP Model

## What is It?

- A **simplified, practical** version of OSI. This is what the internet actually uses.
- Condenses OSI's 7 layers into 4 layers.

## OSI vs TCP/IP Comparison

```
OSI (7 layers)              TCP/IP (4 layers)
────────────────────────    ─────────────────────────
7. Application              ┐
6. Presentation             ├─→ Application (HTTP, DNS, SMTP)
5. Session                  ┘
4. Transport               ──→ Transport (TCP, UDP)
3. Network                 ──→ Internet (IP, ICMP)
2. Data Link               ┐
1. Physical                ┘─→ Network Access (Ethernet, Wi-Fi)
```

- **Why TCP/IP is used:** OSI is a theoretical model; TCP/IP was actually implemented and became the internet standard.

---

# 9. DNS — Domain Name System

## Objective
Understand how human-readable domain names get resolved to machine-readable IP addresses.

## The Problem DNS Solves

- Computers communicate using IP addresses (e.g., `142.250.80.46`).
- Humans remember names (e.g., `google.com`).
- DNS = the phone book of the internet — translates names to IPs.

## DNS Resolution Flow

```
You type: www.google.com

1. Browser Cache → "Do I have this IP already?"
2. OS Cache → "Does my OS know this IP?"
3. Resolver (ISP's DNS) → "Let me ask..."
4. Root Name Server → "I don't know, ask .com TLD server"
5. TLD Server (.com) → "I don't know, ask Google's Name Server"
6. Authoritative Name Server (Google) → "142.250.80.46"
7. IP returned → Browser connects to 142.250.80.46
```

## DNS Hierarchy

```
                        Root (.)
                          │
          ┌───────────────┼──────────────┐
         .com            .org           .in
          │
      google.com
          │
      www.google.com
```

## DNS Record Types

| Record Type | Purpose | Example |
|---|---|---|
| A | Maps domain → IPv4 | `google.com → 142.250.80.46` |
| AAAA | Maps domain → IPv6 | `google.com → 2607:f8b0::...` |
| CNAME | Alias to another domain | `www.google.com → google.com` |
| MX | Mail server | `google.com → aspmx.l.google.com` |
| NS | Name server | Who manages this domain |
| TXT | Text info | SPF records, verification |

## Command to Test DNS

```bash
# Look up IP of a domain
nslookup google.com

# Detailed DNS lookup
dig google.com

# What it shows: IP address, DNS server used, query time
# Why: Debug DNS issues, verify DNS records
```

---

# 10. Ports & Sockets

## What is a Port?

- A **port** is a logical endpoint for a specific process/service on a machine.
- An IP address identifies the machine; a port identifies the **application** on that machine.
- Combined: `IP:Port` = a **socket**.

```
Analogy:
IP Address = Apartment Building address
Port = Apartment number inside the building
```

## How Ports Work

```
Server IP: 54.210.100.5

Port 80  → HTTP web server (nginx/apache)
Port 443 → HTTPS web server
Port 22  → SSH service
Port 3306 → MySQL database
Port 6443 → Kubernetes API server
```

## Port Ranges

| Range | Type | Description |
|---|---|---|
| 0–1023 | Well-known | Reserved for standard services (HTTP=80, SSH=22) |
| 1024–49151 | Registered | Used by applications (MySQL=3306, Redis=6379) |
| 49152–65535 | Ephemeral | Temporary ports used by clients |

## Common Ports to Memorize

| Port | Service |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 53 | DNS |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 6443 | Kubernetes API Server |
| 2379-2380 | etcd (Kubernetes) |
| 10250 | Kubelet |

## Socket

- A **socket** = `IP:Port` combination.
- Example: `192.168.1.5:54321` (client) connecting to `54.210.100.5:443` (server).
- Sockets allow multiple simultaneous connections to the same server.

---

# 11. HTTP & HTTPS

## HTTP — HyperText Transfer Protocol

- The **request-response** protocol used for web communication.
- Client sends a **request**; server sends a **response**.
- **Stateless:** Each request is independent (server doesn't remember previous requests).

## HTTP Request Structure

```
GET /index.html HTTP/1.1
Host: www.example.com
User-Agent: Mozilla/5.0
Accept: text/html

[Optional body]
```

- **Method:** `GET`, `POST`, `PUT`, `DELETE`, `PATCH`
- **Path:** `/index.html`
- **HTTP Version:** `HTTP/1.1`
- **Headers:** Metadata about the request

## HTTP Response Structure

```
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1234

<!DOCTYPE html>
<html>...</html>
```

## HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | OK — Success |
| 201 | Created |
| 301 | Moved Permanently (redirect) |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 500 | Internal Server Error |

## HTTPS — Secure HTTP

- HTTP + **TLS/SSL encryption**.
- Data is encrypted in transit → no eavesdropping.
- Requires an **SSL certificate**.

```
HTTP  → Data sent as plain text  (INSECURE)
HTTPS → Data encrypted with TLS  (SECURE)
```

## TLS Handshake (simplified)

```
Client                        Server
  │── ClientHello ──────────→│  (I support TLS 1.3, here are cipher suites)
  │←── ServerHello ──────────│  (Let's use AES-256, here's my certificate)
  │── Verify certificate ────│  (Is this cert valid & trusted?)
  │── Key Exchange ──────────│  (Generate shared secret)
  │←──────────────────────── │
  │════ Encrypted Traffic ═══│
```

---

# 12. NAT — Network Address Translation

## The Problem NAT Solves

- Private networks use private IP ranges (not routable on the internet).
- You have one **public IP** (from your ISP) but many devices in your home.
- NAT translates between private and public IPs.

## Private IP Ranges

```
Class A: 10.0.0.0    – 10.255.255.255    (/8)
Class B: 172.16.0.0  – 172.31.255.255   (/12)
Class C: 192.168.0.0 – 192.168.255.255  (/16)
```

These ranges are **never routed on the public internet**.

## How NAT Works

```
HOME NETWORK                          INTERNET
                                         
Device 1: 192.168.1.2 ──┐           
Device 2: 192.168.1.3 ──┼──[Router/NAT]── Public IP: 203.0.113.5 ──→ Google (142.250.x.x)
Device 3: 192.168.1.4 ──┘           
                                         
When Device 1 requests google.com:
  1. Packet leaves with: Src=192.168.1.2:54000 → Dst=142.250.x.x:443
  2. Router replaces: Src=203.0.113.5:54000 → Dst=142.250.x.x:443
  3. Google responds to: 203.0.113.5:54000
  4. Router maps back to: 192.168.1.2:54000
```

- **Why NAT matters for Kubernetes:** Kubernetes uses NAT internally to route pod traffic to the correct node and pod.

---

# 13. VPC — Virtual Private Cloud (AWS)

## Objective
Understand VPC — your isolated private network within AWS, which is the foundation of all AWS networking.

## What is a VPC?

- A **VPC** is your own isolated section of the AWS cloud.
- Think of it as your **private data center** in the cloud.
- All AWS resources (EC2, RDS, EKS) live inside a VPC.
- You control: IP range, subnets, routing, security.

## VPC Architecture Overview

```
AWS Cloud
└── Your VPC (e.g., 10.0.0.0/16)
    ├── Public Subnet (10.0.1.0/24)
    │   ├── EC2 Instance (Web Server) — has public IP
    │   └── Load Balancer
    ├── Private Subnet (10.0.2.0/24)
    │   ├── EC2 Instance (App Server) — no public IP
    │   └── RDS Database
    ├── Internet Gateway (for public subnet internet access)
    ├── NAT Gateway (for private subnet outbound access)
    └── Route Tables
```

## How to Create a VPC (AWS Console)

- Go to VPC → Create VPC
- Name: `prod-vpc`
- IPv4 CIDR: `10.0.0.0/16` (gives 65,536 IP addresses)
- **Why `/16`?** Large enough CIDR to create multiple subnets within it.

## Default VPC vs Custom VPC

| Feature | Default VPC | Custom VPC |
|---|---|---|
| Created by | AWS automatically | You manually |
| CIDR | `172.31.0.0/16` | Your choice |
| Use case | Quick testing | Production |
| Security | Less controlled | Full control |

- **Best practice:** Always create a custom VPC for production workloads.

---

# 14. Subnets in AWS (Public & Private)

## What is a Subnet in AWS?

- A subnet is a **range of IPs within your VPC**, bound to a specific **Availability Zone (AZ)**.
- VPC spans a region; Subnets span one AZ.

```
VPC: 10.0.0.0/16  (us-east-1)
│
├── Public Subnet:  10.0.1.0/24  (us-east-1a) → Internet accessible
├── Public Subnet:  10.0.2.0/24  (us-east-1b) → Internet accessible
├── Private Subnet: 10.0.3.0/24  (us-east-1a) → No direct internet
└── Private Subnet: 10.0.4.0/24  (us-east-1b) → No direct internet
```

## Public vs Private Subnet

| Feature | Public Subnet | Private Subnet |
|---|---|---|
| Internet access | ✅ Direct (via IGW) | ❌ No direct access |
| Has public IP | Yes (EC2 gets auto-assigned) | No |
| Route table | Points to Internet Gateway | Points to NAT Gateway |
| Use case | Web servers, Load Balancers | Databases, App servers |

## Why This Separation?

```
CORRECT Architecture:
Internet → Load Balancer (Public) → App Server (Private) → Database (Private)

WRONG Architecture:
Internet → Database (Public) ← SECURITY RISK!
```

- Databases and backend servers should NEVER be directly exposed to the internet.
- This layered approach is called **defense in depth**.

---

# 15. Internet Gateway & Route Tables

## Internet Gateway (IGW)

- A **horizontally scaled, redundant AWS-managed component** that allows traffic between your VPC and the internet.
- One IGW per VPC.
- By itself, IGW does nothing — you must also configure **route tables**.

```
VPC ←──── Internet Gateway ←──── Internet
```

### Steps to Enable Internet Access

1. Create Internet Gateway
2. Attach IGW to VPC
3. Edit Public Subnet's Route Table → add route: `0.0.0.0/0 → IGW`
4. Enable auto-assign public IP on public subnet

## Route Tables

- A **route table** is a set of rules (routes) that determine where network traffic goes.
- Every subnet must be associated with a route table.

### Public Subnet Route Table

```
Destination       Target
10.0.0.0/16      local          ← Traffic within VPC stays local
0.0.0.0/0        igw-xxxxxxx   ← Everything else → Internet
```

### Private Subnet Route Table

```
Destination       Target
10.0.0.0/16      local          ← Traffic within VPC stays local
0.0.0.0/0        nat-xxxxxxx   ← Everything else → NAT Gateway
```

- **`0.0.0.0/0`** means "any destination not matched above → send here" (default route).
- **`local`** means traffic destined within the VPC CIDR range stays within the VPC.

---

# 16. Security Groups & NACLs

## Objective
Understand the two layers of network security in AWS VPC.

## Security Groups (SG)

- **What:** A virtual **stateful firewall** at the **instance (EC2) level**.
- **Stateful:** If you allow inbound traffic, the response is automatically allowed outbound (no need to create outbound rule).
- **Default:** Denies ALL inbound, allows ALL outbound.
- Works at the **ENI (Elastic Network Interface)** level.

### Security Group Rules

```
Inbound Rules:
  Type     Protocol   Port Range   Source
  SSH      TCP        22           My IP (0.0.0.0/0 for all — NOT recommended)
  HTTP     TCP        80           0.0.0.0/0
  Custom   TCP        8080         0.0.0.0/0
  
Outbound Rules:
  All traffic  All  All  0.0.0.0/0  (default — allow all outbound)
```

### Common Security Group Patterns

```
Web Server SG:
  Inbound:  Port 80/443 from 0.0.0.0/0  (public HTTP/HTTPS)
  Inbound:  Port 22 from your-ip/32      (SSH only from your IP)
  Outbound: All traffic allowed

Database SG:
  Inbound:  Port 3306 from Web-Server-SG ONLY  (only app servers can connect)
  Outbound: All traffic allowed
```

- **Key insight:** You can reference another Security Group as source → all EC2s in that SG can connect. This is more dynamic than using IPs.

## NACLs — Network Access Control Lists

- **What:** A **stateless firewall** at the **subnet level**.
- **Stateless:** You must explicitly allow both inbound AND outbound traffic (response traffic not automatically allowed).
- Applied to all resources in the subnet.
- Rules are evaluated in **numbered order** (lowest number first).

### NACL vs Security Group

| Feature | Security Group | NACL |
|---|---|---|
| Level | Instance (EC2) | Subnet |
| State | Stateful | Stateless |
| Rules | Allow only | Allow AND Deny |
| Default | Deny all inbound | Allow all |
| Rule evaluation | All rules checked | Rules in numeric order |
| Use case | Fine-grained per-instance | Broad subnet-level control |

### When to Use NACL vs Security Group

- **Use Security Groups** for: Most cases — simpler, stateful, instance-level.
- **Use NACLs** for: Blocking a specific IP across an entire subnet (e.g., blocking a known attacker IP).

```
Internet → [NACL - Subnet boundary check] → [Security Group - Instance boundary check] → EC2
```

---

# 17. NAT Gateway

## What is a NAT Gateway?

- Allows **private subnet instances** to initiate outbound connections to the internet.
- But **prevents inbound** connections from the internet to private instances.
- Managed by AWS — highly available, scalable.

## NAT Gateway vs Internet Gateway

| Feature | Internet Gateway | NAT Gateway |
|---|---|---|
| Direction | Both inbound & outbound | Outbound only |
| Used by | Public subnets | Private subnets |
| Initiated from | Both internet & instance | Only instance |
| Use case | Public-facing resources | Private instance internet access |

## Architecture

```
Private EC2 (10.0.3.5)
    │  wants to download updates from internet
    ↓
Private Subnet Route Table → 0.0.0.0/0 → NAT Gateway (in Public Subnet)
    │
    ↓
NAT Gateway (has Elastic/Public IP: 203.0.113.10)
    │
    ↓
Internet Gateway
    │
    ↓
Internet (e.g., apt-get update, pip install)
```

- Private EC2 can reach internet for updates/downloads.
- Internet **cannot** initiate a connection TO the private EC2.

---

# 18. Load Balancer

## What is a Load Balancer?

- Distributes incoming traffic across **multiple backend servers**.
- Prevents any single server from being overwhelmed.
- Provides **high availability**: if one server fails, traffic goes to healthy ones.

## Load Balancer Architecture

```
                     Internet
                        │
                 [Load Balancer]
                  /     │     \
        [EC2-1]  [EC2-2]  [EC2-3]
        (10.0.3.4)(10.0.3.5)(10.0.3.6)
         App-1    App-2    App-3
```

## Types of Load Balancers in AWS

| Type | Layer | Use Case |
|---|---|---|
| Application LB (ALB) | Layer 7 (HTTP/HTTPS) | Web apps, microservices, path-based routing |
| Network LB (NLB) | Layer 4 (TCP/UDP) | High performance, low latency |
| Classic LB | Layer 4 & 7 | Legacy (avoid for new deployments) |

## ALB Key Concepts

- **Listener:** What port/protocol the LB listens on (e.g., Port 80 HTTP).
- **Target Group:** A group of EC2s (or other targets) that receive traffic.
- **Health Check:** LB pings targets to verify they're healthy before sending traffic.

```
ALB Setup Flow:
1. Create Target Group → select EC2 instances → set health check port
2. Create ALB → select VPCs and public subnets → assign security group
3. Add Listener → Port 80 → forward to Target Group
```

## Health Checks

- LB sends periodic HTTP requests to each target.
- If target doesn't respond correctly → marked **unhealthy** → traffic NOT sent to it.
- When it recovers → marked **healthy** → traffic resumes.

```
Target Group Status:
  EC2-1: ✅ Healthy   → receives traffic
  EC2-2: ❌ Unhealthy → no traffic sent
```

## Security Group for Load Balancer

```
LB Security Group:
  Inbound: Port 80 from 0.0.0.0/0   (internet can reach LB on port 80)
  
EC2 Security Group (backend):
  Inbound: Port 8080 from LB-SG-ID  (only LB can reach EC2)
  
⚠️ Do NOT expose EC2 port to 0.0.0.0/0 — only LB should reach it!
```

---

# 19. MAC Addresses & ARP

## MAC Address — Media Access Control

- A **hardware address** burned into every network interface (NIC, Wi-Fi card, Bluetooth).
- Format: 12 hexadecimal digits — `AA:BB:CC:DD:EE:FF`
- **Unique per network interface** (not per device — one device can have multiple MACs).
- Works at **Layer 2 (Data Link Layer)**.

```
Your laptop might have:
  Wi-Fi MAC:    AA:BB:CC:11:22:33
  Ethernet MAC: AA:BB:CC:44:55:66
  Bluetooth MAC: AA:BB:CC:77:88:99
```

### MAC vs IP Address

| Feature | IP Address | MAC Address |
|---|---|---|
| Layer | Network (L3) | Data Link (L2) |
| Scope | Logical, changes per network | Physical, fixed to hardware |
| Changes? | Yes (DHCP, VPN) | Rarely (can be spoofed) |
| Range | Entire internet | Local network only |

### How MAC Addresses Are Used in Routing

```
Data travels across multiple hops:
  
[Your PC]──────[Router 1]──────[Router 2]──────[Google Server]
  
IP addresses stay SAME end-to-end:  Src: 192.168.1.2 → Dst: 142.250.80.46
MAC addresses change HOP-by-HOP:    Each router uses MAC of NEXT router
```

## ARP — Address Resolution Protocol

- **Problem:** You know the IP of a device on your LAN but need its MAC to send a frame.
- **Solution:** ARP — broadcasts "Who has this IP? Tell me your MAC."

### ARP Process

```
Device 1 (192.168.1.2) wants to talk to Device 4 (192.168.1.5)

1. Device 1 checks ARP cache → "Do I know MAC of 192.168.1.5?"
2. If NO → broadcasts ARP Request to ALL devices on LAN:
   "Who has 192.168.1.5? Tell 192.168.1.2"
3. Device 4 replies with ARP Reply:
   "192.168.1.5 is at AA:BB:CC:44:55:66"
4. Device 1 stores this in ARP cache
5. Now Device 1 can send frames directly to Device 4's MAC
```

### ARP Cache

```bash
# View ARP cache on Linux
arp -a

# What it shows: IP → MAC mappings your device has learned
```

### Why MAC Changes Hop-by-Hop

```
When your packet travels from home to Google:
  
[Your PC] → [Home Router]     MAC: Your-MAC → Router-MAC
[Home Router] → [ISP Router]  MAC: Router-MAC → ISP-MAC
[ISP Router] → [Google]       MAC: ISP-MAC → Google-MAC

IP: always 192.168.1.2 → 142.250.80.46
MAC: changes at every hop
```

## Commands

```bash
# Check your MAC address (Linux/Mac)
ifconfig
# Look for "ether" field — that's your MAC

# Modern Linux
ip link show

# Check ARP cache
arp -a

# Windows
arp -a
ipconfig /all
```

---

# 20. AWS Project Walkthrough

## Project Architecture

```
Internet
   │
   ↓
[Application Load Balancer] ← Public Subnet ← Internet Gateway
   │
   ├──→ [EC2 Instance 1 - App Running] ← Private Subnet
   └──→ [EC2 Instance 2 - App Running] ← Private Subnet
```

## Step-by-Step Implementation

### Step 1: Create VPC
- CIDR: `10.0.0.0/16`
- Name: `prod-vpc`

### Step 2: Create Subnets
```
Public Subnet 1:  10.0.1.0/24 (AZ-1)
Public Subnet 2:  10.0.2.0/24 (AZ-2)
Private Subnet 1: 10.0.3.0/24 (AZ-1)
Private Subnet 2: 10.0.4.0/24 (AZ-2)
```

### Step 3: Create & Attach Internet Gateway
- Create IGW → Attach to `prod-vpc`

### Step 4: Configure Route Tables
- **Public Route Table:** `0.0.0.0/0 → IGW` → Associate with public subnets
- **Private Route Table:** `0.0.0.0/0 → NAT GW` → Associate with private subnets

### Step 5: Create NAT Gateway
- Place in Public Subnet
- Assign Elastic IP

### Step 6: Launch EC2 Instances (in Private Subnets)
- Deploy Python web app on port 8080:

```bash
# Simple Python HTTP server — run on EC2
python3 -m http.server 8080

# Or a simple Flask app
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'This is my first AWS project')

HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
"
```

### Step 7: Create Security Groups

**EC2 Security Group:**
```
Inbound:
  Port 22   (SSH)    from your IP
  Port 8080 (App)    from Load Balancer SG
Outbound:
  All traffic allowed
```

**Load Balancer Security Group:**
```
Inbound:
  Port 80   (HTTP)   from 0.0.0.0/0  ← internet can reach LB
Outbound:
  All traffic allowed
```

### Step 8: Create Target Group
- Type: EC2 Instances
- Port: 8080 (where app runs)
- Health check: HTTP on port 8080
- Add both EC2 instances as targets

### Step 9: Create Application Load Balancer
- Scheme: Internet-facing
- Subnets: Both Public Subnets (multi-AZ)
- Security Group: LB Security Group
- Listener: Port 80 → forward to Target Group

### Step 10: Test

```bash
# Get LB DNS name from AWS console, then:
curl http://your-alb-dns-name.us-east-1.elb.amazonaws.com

# Expected: Response from one of the EC2 instances
# Refresh multiple times → see traffic distributed across instances
```

## Troubleshooting Checklist

```
LB not reachable?
  → Check LB Security Group allows port 80 inbound from 0.0.0.0/0

Getting 502 Bad Gateway?
  → Check EC2 Security Group allows traffic from LB SG on port 8080
  → Check app is actually running on EC2: ps aux | grep python

Target shows unhealthy?
  → Check health check port matches app port (8080)
  → SSH into EC2 and verify app is running
  → Check EC2 SG allows health check traffic from LB

EC2 in private subnet can't download packages?
  → Check NAT Gateway exists in public subnet
  → Check private route table: 0.0.0.0/0 → NAT Gateway
```

---

# 🗺️ Complete Networking Mental Map for Kubernetes

```
┌─────────────────────────────────────────────────────────────────────┐
│                     HOW DATA FLOWS END-TO-END                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  USER (Browser)                                                     │
│    │  Type: https://myapp.com                                       │
│    │                                                                 │
│    ↓ DNS Resolution                                                 │
│  DNS Lookup: myapp.com → 54.210.100.5                               │
│    │                                                                 │
│    ↓ TCP Connection (3-way handshake to port 443)                   │
│  TLS Handshake (HTTPS encryption)                                   │
│    │                                                                 │
│    ↓ HTTP Request                                                   │
│  Internet → Internet Gateway → Load Balancer (Public Subnet)        │
│    │  [Security Group: allow 443 from 0.0.0.0/0]                   │
│    │                                                                 │
│    ↓ Route to backend                                               │
│  Load Balancer → EC2/Pod (Private Subnet)                           │
│    │  [Security Group: allow app port from LB-SG only]             │
│    │                                                                 │
│    ↓ Database query                                                 │
│  App → Database (Private Subnet, different SG)                      │
│    │  [Security Group: allow DB port from App-SG only]             │
│    │                                                                 │
│    ↓ Response travels back up the same path                        │
│  Database → App → LB → Internet → User                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Concepts Summary Table

| Concept | What it is | Kubernetes Relevance |
|---|---|---|
| IP Address | Unique device identifier | Every pod, node, service gets one |
| Subnet | IP range division | Node pools, pod CIDR ranges |
| CIDR | IP range notation | `podCIDR: 10.244.0.0/16` |
| DNS | Name → IP translation | CoreDNS resolves service names in K8s |
| Port | App endpoint on a host | Container ports, NodePort, Service port |
| TCP | Reliable transport | API server, etcd, kubelet all use TCP |
| NAT | Private→Public IP translation | Pod traffic NATed to node IP |
| VPC | Isolated cloud network | EKS clusters live inside VPC |
| Security Group | Stateful instance firewall | Node group security, pod-level with VPC CNI |
| NACL | Stateless subnet firewall | Subnet-level cluster traffic control |
| Load Balancer | Traffic distributor | Kubernetes Service type: LoadBalancer |
| MAC/ARP | Physical device addressing | CNI plugins use ARP for pod networking |
| OSI Model | Layered network model | Understand where each K8s component operates |

---

*This guide covers 100% of the content from both Abishek's AWS Networking Course and Kunal's Complete Computer Networking Course.*
