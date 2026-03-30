# Student Hostel Management System (SHMS)
### Final Year Project — Comprehensive Technical & Functional Documentation

---

## Table of Contents
1. [What is SHMS?](#1-what-is-shms)
2. [The Problem It Solves](#2-the-problem-it-solves)
3. [Why SHMS is Unique](#3-why-shms-is-unique)
4. [Getting Started](#4-getting-started)
5. [System Architecture — How Everything Talks Together](#5-system-architecture)
6. [App Walkthrough — Every Screen Explained](#6-app-walkthrough)
7. [Computations the System Performs](#7-computations)
8. [Reports the System Generates](#8-reports)
9. [Data Models & Database Design](#9-data-models)
10. [Technology Stack](#10-technology-stack)

---

## 1. What is SHMS?

**SHMS (Student Hostel Management System)** is a full-stack, cross-platform mobile and web application built with **Flutter** and **Firebase** that digitises the complete lifecycle of student hostel management — from room browsing and booking, to rent payment via M-Pesa, to maintenance tracking and administrative reporting.

It targets two distinct user groups:

| Role | Who They Are | What They Do |
|------|-------------|--------------|
| **Student** | A university/college student living in a hostel | Browse rooms, book, pay rent, report issues |
| **Admin** | Hostel manager / estate officer | Manage rooms, approve bookings, track payments, resolve maintenance |

---

## 2. The Problem It Solves

### The Traditional (Broken) System

In most student hostels across Kenya and Africa, hostel management is done manually:

```
┌──────────────────────────────────────────────────────────────┐
│               PROBLEMS WITH MANUAL MANAGEMENT                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Student wants a room?     ──► Walk to the hostel office    │
│  Student wants to pay?     ──► Bank deposit / cash to admin │
│  Room has a problem?       ──► Write a paper complaint       │
│  Admin needs a report?     ──► Count rooms by hand           │
│  Admin tracks payments?    ──► Paper ledger / Excel file     │
│  Room occupied/vacant?     ──► Manual whiteboard update      │
│                                                              │
│  RESULT: Lost records, payment disputes, delayed repairs,   │
│          inefficiency, and zero real-time visibility.        │
└──────────────────────────────────────────────────────────────┘
```

### How SHMS Fixes Every One of These Problems

| Manual Problem | SHMS Solution |
|----------------|---------------|
| Physical room booking | Online room browsing & booking from any device |
| Cash / bank rent payments | Instant M-Pesa STK Push — pay from your phone |
| Paper maintenance complaints | Digital submission with urgency levels, tracked in real-time |
| Manual payment records | Automatic Firestore logging with M-Pesa receipt numbers |
| Admin guesswork on occupancy | Real-time dashboard: total rooms, occupied, vacant |
| No audit trail | Every action timestamped and stored in cloud database |
| Lost receipts | Payment history stored permanently in the cloud |
| No offline access | Works offline — payments and actions queue and sync automatically |

---

## 3. Why SHMS is Unique

### 3.1 — M-Pesa STK Push Integration
Most student management systems either don't have payment systems or use manual bank transfer confirmations. SHMS uses the **Safaricom Daraja API** to send an M-Pesa payment prompt directly to the student's phone — no app switching, no bank visit.

```
  Student taps "Pay" ──► STK Push sent ──► Phone vibrates with M-Pesa prompt
         ──► Student enters PIN ──► Payment confirmed ──► Receipt logged
```

### 3.2 — Offline-First Architecture
SHMS does not require a constant internet connection. If the network drops:
- Students can still view their dashboard using cached data
- Payment attempts are **queued** and automatically processed when connectivity is restored
- Admins can add/edit rooms offline — they sync to the cloud automatically

### 3.3 — Real-Time Dual Dashboard
Both admin and student views update **instantly** without refreshing, using Firestore real-time streams. When an admin approves a booking, the student's dashboard reflects it within seconds.

### 3.4 — Cross-Platform — One Codebase
SHMS runs natively on:
- **Android** (student's phone)
- **Web browser** (any computer)
- **Windows Desktop** (office PC)

All from a single Flutter codebase — no separate development for each platform.

### 3.5 — Role-Based Security
The system enforces strict separation between admin and student:
- Admin routes are protected by an `AdminGate` widget
- Firebase Auth tokens are verified on every Cloud Function call
- Students cannot access any admin screen even by typing the URL directly

### 3.6 — Automated PDF Reporting
Admins can download a fully-formatted PDF report with a single tap — no Excel, no copy-pasting. The report is generated on-device in real time.

---

## 4. Getting Started

### 4.1 — Student Journey

```
┌─────────────────────────────────────────────────────────────────────┐
│                     STUDENT JOURNEY IN SHMS                         │
└─────────────────────────────────────────────────────────────────────┘

  STEP 1          STEP 2           STEP 3          STEP 4
  ┌──────┐       ┌──────┐        ┌──────┐         ┌──────┐
  │      │       │      │        │      │          │      │
  │ Open │──────►│Sign  │───────►│Browse│─────────►│ Book │
  │ App  │       │ Up   │        │Rooms │          │ Room │
  │      │       │      │        │      │          │      │
  └──────┘       └──────┘        └──────┘         └──────┘
                                                       │
        ┌──────────────────────────────────────────────┘
        ▼
  STEP 5          STEP 6           STEP 7          STEP 8
  ┌──────┐       ┌──────┐        ┌──────┐         ┌──────┐
  │Admin │       │      │        │ Pay  │          │Report│
  │Appro-│──────►│Assigned       │ Rent │─────────►│Mainte│
  │ ves  │       │ Room │        │(M-Pesa)         │nance │
  │      │       │      │        │      │          │      │
  └──────┘       └──────┘        └──────┘         └──────┘
```

**Step-by-step:**

1. **Open the App** — land on the welcome screen
2. **Create an Account** — enter name, email, password, select "Student" role
3. **Browse Available Rooms** — see room photos, pricing, availability status
4. **Book a Room** — tap "Book Now" on your preferred room
5. **Admin Approves** — the hostel manager approves your booking request
6. **Room Assigned** — your dashboard now shows your assigned room
7. **Pay Monthly Rent** — tap "Pay Rent", enter your M-Pesa number, confirm PIN on your phone
8. **Report Issues** — if something breaks, submit a maintenance request in seconds

---

### 4.2 — Admin Journey

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ADMIN JOURNEY IN SHMS                          │
└─────────────────────────────────────────────────────────────────────┘

  STEP 1          STEP 2           STEP 3          STEP 4
  ┌──────┐       ┌──────┐        ┌──────┐         ┌──────┐
  │ Log  │       │Admin │        │ Add  │          │Appro-│
  │  In  │──────►│Dash- │───────►│/Edit │─────────►│ ve   │
  │(Admin│       │board │        │Rooms │          │Booki-│
  │ Role)│       │      │        │      │          │ ngs  │
  └──────┘       └──────┘        └──────┘         └──────┘
                                                       │
        ┌──────────────────────────────────────────────┘
        ▼
  STEP 5          STEP 6           STEP 7
  ┌──────┐       ┌──────┐        ┌──────┐
  │Track │       │Manage│        │Downl-│
  │Payme-│──────►│Maint-│───────►│oad   │
  │ nts  │       │enance│        │Report│
  │      │       │Reques│        │ PDF  │
  └──────┘       └──────┘        └──────┘
```

---

### 4.3 — Installation & Setup

**Prerequisites:**
- Flutter SDK ≥ 3.0
- Node.js ≥ 18 (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project (`shms-7b88d`)

**Run the App:**
```bash
# Clone and enter the project
cd d:\SHMS\mysmhs

# Install Flutter dependencies
flutter pub get

# Run on Windows Desktop
flutter run -d windows

# Run on Chrome (Web)
flutter run -d chrome

# Build for release
flutter build web
```

**Deploy Cloud Functions:**
```bash
cd d:\SHMS\mysmhs\functions
npm install
firebase deploy --only functions
```

---

## 5. System Architecture

### 5.1 — Big Picture: How Frontend & Backend Talk

```
╔══════════════════════════════════════════════════════════════════════════╗
║                         SHMS SYSTEM ARCHITECTURE                        ║
╚══════════════════════════════════════════════════════════════════════════╝

  ┌─────────────────────────────────┐
  │         FLUTTER APP             │  ← Frontend (Dart/Flutter)
  │  ┌──────────┐  ┌─────────────┐ │
  │  │ Student  │  │    Admin    │ │
  │  │Dashboard │  │  Dashboard  │ │
  │  └────┬─────┘  └──────┬──────┘ │
  │       │               │        │
  │  ┌────▼───────────────▼──────┐ │
  │  │       Services Layer      │ │
  │  │  ConnectivityService      │ │
  │  │  LocalCacheService        │ │
  │  │  SyncManager              │ │
  │  │  MpesaCloudService        │ │
  │  │  RoomSyncService          │ │
  │  │  ReportService            │ │
  │  └────────────┬──────────────┘ │
  └───────────────┼─────────────────┘
                  │  HTTPS / WebSocket
                  │
  ┌───────────────▼─────────────────────────────────────────────────────┐
  │                        FIREBASE BACKEND                             │
  │                                                                     │
  │  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐ │
  │  │  Firebase Auth  │  │   Cloud Firestore │  │ Firebase Storage  │ │
  │  │                 │  │                  │  │                   │ │
  │  │ • Email/Password│  │ • users          │  │ • Room photos     │ │
  │  │ • ID Tokens     │  │ • rooms          │  │ • Compressed imgs │ │
  │  │ • Role stored   │  │ • bookings       │  │                   │ │
  │  │   in Firestore  │  │ • payments       │  └───────────────────┘ │
  │  └─────────────────┘  │ • maintenance_   │                        │
  │                        │   requests      │  ┌───────────────────┐ │
  │                        └──────────────────┘  │  Cloud Functions  │ │
  │                                              │  (Node.js v2)     │ │
  │                                              │                   │ │
  │                                              │ initiateMpesa     │ │
  │                                              │ Payment()         │ │
  │                                              │                   │ │
  │                                              │ checkPayment      │ │
  │                                              │ Status()          │ │
  │                                              │                   │ │
  │                                              │ mpesaCallback()   │ │
  │                                              └────────┬──────────┘ │
  └───────────────────────────────────────────────────────┼────────────┘
                                                          │ HTTPS
                                                          │
  ┌───────────────────────────────────────────────────────▼────────────┐
  │                   SAFARICOM DARAJA API (M-Pesa)                    │
  │                                                                    │
  │   OAuth Token ──► STK Push ──► Callback to Firebase Function      │
  └────────────────────────────────────────────────────────────────────┘
```

---

### 5.2 — Communication Protocols Explained

#### A) Flutter ↔ Firebase Auth
```
Flutter App                           Firebase Auth
    │                                      │
    │── signInWithEmailAndPassword() ─────►│
    │◄─ UserCredential (uid, token) ───────│
    │                                      │
    │── getIdToken(forceRefresh: true) ───►│
    │◄─ JWT Token (Bearer) ────────────────│
```
- Uses Firebase SDK (`firebase_auth` package)
- Token refreshes automatically every hour
- Token is included in every Cloud Function call

#### B) Flutter ↔ Cloud Firestore (Real-Time Streams)
```
Flutter App                           Cloud Firestore
    │                                      │
    │── collection('rooms').snapshots() ──►│
    │                                      │  (WebSocket — persistent connection)
    │◄─ Stream<QuerySnapshot> ─────────────│
    │    (fires every time data changes)   │
    │                                      │
    │── collection('payments').add({}) ───►│  (Write)
    │◄─ DocumentReference ─────────────────│
```
- Real-time WebSocket connection — no polling needed
- `StreamBuilder` widgets rebuild UI when data changes
- Offline persistence built into Firestore SDK

#### C) Flutter ↔ Cloud Functions (M-Pesa Payments)
```
Flutter App                    Cloud Function            Safaricom Daraja
    │                               │                          │
    │── HTTP POST ─────────────────►│                          │
    │   Authorization: Bearer <JWT> │                          │
    │   Body: {data: {phone,        │── GET /oauth/generate ──►│
    │           amount, room}}      │◄─ access_token ──────────│
    │                               │                          │
    │                               │── POST /stkpush ────────►│
    │                               │◄─ CheckoutRequestID ─────│
    │◄─ {success, checkoutID} ──────│                          │
    │                               │          (User enters PIN on phone)
    │                               │◄─ Callback (result) ─────│
    │                               │── Update Firestore ──────►│(Firestore)
    │                               │                          │
    │── Poll Firestore every 6s ───►│(Firestore)               │
    │◄─ status: "completed" ────────│                          │
    │                               │                          │
    │   Show success snackbar        │                          │
```

#### D) Offline → Online Sync Flow
```
OFFLINE MODE                          ONLINE MODE
     │                                     │
     │  Student taps "Pay Rent"            │
     │                                     │
     ▼                                     │
  SyncManager.addAction(                   │
    'mpesa_payment',                       │
    {phone, amount, room}                  │
  )                                        │
     │                                     │
     │  Saved to LocalCacheService         │
     │  (encrypted secure storage)         │
     │                                     │
     │  ── Network restored ─────────────► │
     │                                     │
     │                            SyncManager.flushQueue()
     │                                     │
     │                            For each queued action:
     │                            ── Call Cloud Function ──►
     │                            ◄─ Result ───────────────
     │                            ── Update Firestore ─────►
```

---

### 5.3 — Authentication & Role Routing Flow

```
App Launch
    │
    ▼
LocalCacheService.getUser()
    │
    ├── Cached session found?
    │       │
    │       ├── YES → Route to cached role dashboard immediately
    │       │         (no waiting for Firebase)
    │       │
    │       └── NO  → Show LandingPage → AuthPage
    │
    ▼
Firebase Auth state listener
    │
    ├── User signed in?
    │       │
    │       ├── YES → Fetch users/{uid} from Firestore
    │       │         │
    │       │         ├── role == 'admin' ──► /admin (AdminGate)
    │       │         └── role == 'student' ► /student-dashboard
    │       │
    │       └── NO  → /auth (login page)
    │
    ▼
AdminGate (extra security layer)
    │
    ├── Checks role again from Firestore
    ├── role != 'admin' ──► redirect to /auth
    └── role == 'admin' ──► render AdminDashboardPage
```

---

## 6. App Walkthrough

### 6.1 — Landing Page
The first screen users see. Shows the SHMS brand, a brief value proposition, and two entry points: **Get Started** (sign up) and **Login** (existing users).

```
┌─────────────────────────────────┐
│  ░░░░ SHMS ░░░░░░░░░░░░░░░░░░░ │  ← Blue gradient background
│                                 │
│   Welcome to SHMS               │
│                                 │
│   ✓ Book rooms digitally        │
│   ✓ Pay rent via M-Pesa         │
│   ✓ Report maintenance easily   │
│                                 │
│   ┌─────────────────────────┐   │
│   │      Get Started        │   │
│   └─────────────────────────┘   │
│        Already a user? Login    │
└─────────────────────────────────┘
```

### 6.2 — Auth Page (Login / Sign Up)
- **Login**: Email + password → routes by role
- **Sign Up**: Name, email, password (min 8 chars, 1 uppercase, 1 number), role selection (Student / Admin)
- **Password Reset**: Email-based reset via Firebase Auth

### 6.3 — Student Dashboard
```
┌─────────────────────────────────────────────────────────────┐
│  ≡   Student Dashboard                          🔔          │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │  👤 John Doe                                          │  │
│  │  Room: 200          Booking Status: [APPROVED]        │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Rent Status  │  │ Next Payment │  │   Open Maint │     │
│  │              │  │              │  │              │     │
│  │ Due KES 2,000│  │ 31/03/2026   │  │      1       │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  Available Rooms                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ [photo]  │  │ [photo]  │  │ [photo]  │                 │
│  │ Room 101 │  │ Room 102 │  │ Room 103 │                 │
│  │ KES 2,000│  │ KES 3,000│  │ KES 2,500│                 │
│  │ Available│  │ Occupied │  │ Available│                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 — Pay Rent Page (M-Pesa Integration)
```
┌─────────────────────────────────────────────────────────────┐
│  ←   Pay Rent                                        🕐     │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │  [🟢 Online]                                          │  │
│  │                                                       │  │
│  │  Pay Rent                                             │  │
│  │                                                       │  │
│  │  Phone number              Amount                     │  │
│  │  [0796735714         ]     [2,000           ]         │  │
│  │                                                       │  │
│  │  Room number                                          │  │
│  │  [200                ]                                │  │
│  │                                                       │  │
│  │  ┌─────────────────────────┐  ┌──────────────────┐   │  │
│  │  │    Pay with M-Pesa      │  │ View History     │   │  │
│  │  └─────────────────────────┘  └──────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

After tapping Pay → Confirm Dialog → STK Push sent to phone
→ Phone shows M-Pesa PIN prompt → Enter PIN → Payment confirmed
→ Green snackbar: "Payment of KES 2,000 received successfully!"
```

### 6.5 — Report Maintenance Page
```
┌─────────────────────────────────────────────────────────────┐
│  ←   Report Maintenance                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Issue Type                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Plumbing                                        ▼  │   │
│  └─────────────────────────────────────────────────────┘   │
│   (Options: Plumbing, Electrical, Furniture, Cleaning, Other)│
│                                                             │
│  Description                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  The pipe under the sink is leaking...              │   │
│  │                                              45/500  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Urgency                                                    │
│  ○ Low    ● Medium    ○ High                                │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Submit Report                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 6.6 — Admin Dashboard
```
┌─────────────────────────────────────────────────────────────┐
│  ≡   Admin Dashboard                         📄  logout     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Total Rooms  │  │   Occupied   │                        │
│  │      12      │  │      8       │                        │
│  └──────────────┘  └──────────────┘                        │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │Pending Paymt │  │Open Maintena.│                        │
│  │      3       │  │      2       │                        │
│  └──────────────┘  └──────────────┘                        │
│                                                             │
│  ─── Pending Bookings ─────────────────────────────────    │
│  Room 101 | Student: Jane | [Approve] [Reject]             │
│  Room 205 | Student: Mark | [Approve] [Reject]             │
│                                                             │
│  ─── Pending Payments ─────────────────────────────────    │
│  Room 101 | KES 2,000 | Pending                            │
│                                                             │
│  ─── Maintenance Requests ─────────────────────────────    │
│  Room 200 | Plumbing | 🔴 High | Pipe leaking | [Assign]   │
│  Room 105 | Electrical | 🟡 Medium | Light out | [Assign]  │
└─────────────────────────────────────────────────────────────┘
```

### 6.7 — Admin Room Management
- List of all rooms with quick stats
- Add new room: upload photos, set price, number, description
- Rooms added while offline are stored locally (Hive) and sync when online
- Edit or delete existing rooms

---

## 7. Computations

SHMS performs the following computations automatically:

### 7.1 — Occupancy Rate
```
Formula:
  Occupancy Rate (%) = (Occupied Rooms / Total Rooms) × 100

Example:
  Total Rooms  = 12
  Occupied     = 8
  Occupancy    = (8 / 12) × 100 = 66.7%

Used in: Admin Dashboard metrics cards
Source:  Firestore query — rooms where isOccupied == true
```

### 7.2 — Rent Status Determination
```
Logic:
  IF any payment with status='completed'
     AND completedAt within current calendar month
  THEN → Show "Paid"
  ELSE → Show "Due KES {booking.price}"

Used in: Student Dashboard → Rent Status card
Source:  bookings collection (price field) + payments collection
```

### 7.3 — Next Payment Date
```
Formula:
  Next Payment = Last day of the current month

Example (March 2026):
  endOfMonth = DateTime(2026, 4, 0)  →  31/03/2026

Used in: Student Dashboard → Next Payment card
Note:    Computed in real-time from system clock — always current
```

### 7.4 — M-Pesa STK Push Password
```
Formula (per Safaricom Daraja specification):
  timestamp = YYYYMMDDHHMMSS  (e.g. 20260331021045)
  password  = Base64( shortCode + passkey + timestamp )

This is the security handshake that Safaricom uses to verify
the payment request is from an authenticated registered business.

Computed in: Cloud Function (server-side) on every payment request
```

### 7.5 — Phone Number Normalization
```
Rule:
  Input:   0796735714   (local format)
  Output:  254796735714 (international E.164 format)

  IF phone starts with '0'  → replace '0' with '254'
  IF phone starts with '254' → use as-is

Required by: Safaricom Daraja API (rejects local format)
Computed in: Cloud Function before STK push call
```

### 7.6 — Offline Queue Processing (FIFO with Exponential Backoff)
```
Algorithm:
  For each queued action (in order of creation):
    1. Attempt to execute the action
    2. IF success → remove from queue
    3. IF failure → wait (exponential backoff, max 60s) → retry

Backoff schedule:
  Attempt 1: immediate
  Attempt 2: 2 seconds
  Attempt 3: 4 seconds
  Attempt 4: 8 seconds
  ...up to 60 seconds max

Used for: Queued payments and profile updates
```

### 7.7 — Room Availability Status
```
Logic:
  IF rooms.isOccupied == true
     → Status badge: "Occupied" (red)
  ELSE IF rooms.availability == 'maintenance'
     → Status badge: "Maintenance" (orange)
  ELSE
     → Status badge: "Available" (green)

Used in: Student Dashboard room cards, Room Details page
```

### 7.8 — Urgency Color Coding (Maintenance)
```
Urgency Level → Badge Color:
  "High"   → Red    (immediate attention required)
  "Medium" → Orange (moderate priority)
  "Low"    → Green  (low priority)

Used in: Admin Dashboard → Maintenance Requests list
```

### 7.9 — Image Compression
```
Before uploading room photos to Firebase Storage:
  IF platform == mobile:
    Compress JPEG to quality=85, max 1200×1200px
  IF platform == web:
    Compress PNG in-memory (Uint8List)

Purpose: Reduce storage costs and improve load speed
```

---

## 8. Reports

### 8.1 — PDF Admin Report

Accessible via the **📄 icon** in the Admin Dashboard AppBar.

Generated entirely on-device using the `pdf` and `printing` Flutter packages.

**Report Structure:**
```
╔═══════════════════════════════════════════════════════╗
║          STUDENT HOSTEL MANAGEMENT SYSTEM             ║
║                  Admin Report                         ║
║          Generated: 31 March 2026, 02:11 AM           ║
╠═══════════════════════════════════════════════════════╣
║                                                       ║
║  SECTION 1: OVERVIEW METRICS                          ║
║  ┌───────────────┬───────────────────────────────┐   ║
║  │ Metric        │ Value                         │   ║
║  ├───────────────┼───────────────────────────────┤   ║
║  │ Total Rooms   │ 12                            │   ║
║  │ Occupied      │ 8                             │   ║
║  │ Pending Pymts │ 3                             │   ║
║  │ Open Maint.   │ 2                             │   ║
║  └───────────────┴───────────────────────────────┘   ║
║                                                       ║
║  SECTION 2: OPEN MAINTENANCE REQUESTS (up to 10)      ║
║  ┌──────────┬───────────┬──────────┬────────────┐    ║
║  │ Room     │ Type      │ Urgency  │ Description│    ║
║  ├──────────┼───────────┼──────────┼────────────┤    ║
║  │ 200      │ Plumbing  │ 🔴 High  │ Pipe leak  │    ║
║  │ 105      │ Electrical│ 🟡 Medium│ Light out  │    ║
║  └──────────┴───────────┴──────────┴────────────┘    ║
║                                                       ║
║  SECTION 3: PENDING BOOKINGS (up to 10)               ║
║  ┌──────────┬───────────┬─────────────────────────┐  ║
║  │ Room ID  │ Status    │ Date                    │  ║
║  ├──────────┼───────────┼─────────────────────────┤  ║
║  │ 101      │ Pending   │ 30 Mar 2026             │  ║
║  └──────────┴───────────┴─────────────────────────┘  ║
║                                                       ║
║  SECTION 4: PENDING PAYMENTS (up to 10)               ║
║  ┌──────────┬───────────┬─────────────────────────┐  ║
║  │ Amount   │ Status    │ Date                    │  ║
║  ├──────────┼───────────┼─────────────────────────┤  ║
║  │ KES 2,000│ Pending   │ 29 Mar 2026             │  ║
║  └──────────┴───────────┴─────────────────────────┘  ║
╚═══════════════════════════════════════════════════════╝
```

**Report Features:**
- Unicode font (Noto Sans) — supports Swahili and special characters
- Color-coded urgency badges in the maintenance section
- Timestamped at time of generation
- Can be printed directly or saved as PDF file
- Fully generated offline — fetches data from Firestore then renders locally

### 8.2 — Real-Time Dashboard Metrics (Live Report)

The Admin Dashboard itself functions as a live report that updates in real-time:

| Metric | Data Source | Update Trigger |
|--------|-------------|----------------|
| Total Rooms | `rooms` collection count | Any room added/deleted |
| Occupied Rooms | `rooms` where `isOccupied=true` count | Room status change |
| Pending Payments | `payments` where `status=pending` count | Payment initiated/completed |
| Open Maintenance | `maintenance_requests` where `status=open` count | Request submitted/resolved |

### 8.3 — Student Rent Status Report (Personal)

On the Student Dashboard, each student sees a personal payment summary:

| Field | Source | Computation |
|-------|--------|-------------|
| Rent Status | bookings + payments | Checks if paid this month |
| Amount Due | bookings.price | Direct field read |
| Next Payment | System clock | Last day of current month |
| Open Maintenance | maintenance_requests | Count of open requests by this student |

---

## 9. Data Models

### Firestore Collections Structure

```
Firebase Firestore (shms-7b88d)
│
├── users/
│   └── {uid}/
│       ├── email: string
│       ├── role: "student" | "admin"
│       ├── name: string
│       ├── phone: string
│       ├── assignedRoom: string
│       └── createdAt: timestamp
│
├── rooms/
│   └── {roomId}/
│       ├── roomNumber: string
│       ├── price: number (KES/month)
│       ├── description: string
│       ├── images: string[] (Firebase Storage URLs)
│       ├── availability: "available"|"occupied"|"maintenance"
│       ├── isOccupied: boolean
│       └── createdAt: timestamp
│
├── bookings/
│   └── {bookingId}/
│       ├── studentID: string (user uid)
│       ├── roomID: string
│       ├── roomNumber: string
│       ├── price: number
│       ├── status: "pending"|"approved"|"cancelled"
│       └── createdAt: timestamp
│
├── payments/
│   └── {paymentId}/
│       ├── userId: string
│       ├── roomNumber: string
│       ├── amount: number (KES)
│       ├── phoneNumber: string (254XXXXXXXXX)
│       ├── status: "pending"|"completed"|"failed"
│       ├── checkoutRequestID: string (from Safaricom)
│       ├── mpesaReceiptNumber: string
│       ├── createdAt: timestamp
│       └── completedAt: timestamp
│
└── maintenance_requests/
    └── {requestId}/
        ├── studentID: string
        ├── roomNumber: string
        ├── issueType: "Plumbing"|"Electrical"|"Furniture"|"Cleaning"|"Other"
        ├── description: string
        ├── urgency: "Low"|"Medium"|"High"
        ├── status: "open"|"pending"|"resolved"
        └── createdAt: timestamp
```

---

## 10. Technology Stack

```
╔══════════════════════════════════════════════════════════════╗
║                    SHMS TECHNOLOGY STACK                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  FRONTEND                                                    ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │  Flutter (Dart)  — Cross-platform UI framework         │ ║
║  │  Runs on: Android · Web (Chrome) · Windows Desktop     │ ║
║  │                                                        │ ║
║  │  Key packages:                                         │ ║
║  │  • cloud_firestore    — Real-time database streams     │ ║
║  │  • firebase_auth      — User authentication            │ ║
║  │  • firebase_storage   — Room image uploads             │ ║
║  │  • connectivity_plus  — Online/offline detection        │ ║
║  │  • hive               — Local offline database          │ ║
║  │  • flutter_secure_storage — Encrypted session cache    │ ║
║  │  • cached_network_image   — Room photo carousel        │ ║
║  │  • pdf + printing     — Report generation              │ ║
║  │  • http               — Cloud Functions HTTP calls     │ ║
║  │  • intl               — Date & currency formatting     │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  BACKEND (Firebase Platform)                                 ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │  Firebase Auth        — Identity & session management  │ ║
║  │  Cloud Firestore      — NoSQL real-time database       │ ║
║  │  Firebase Storage     — Image file storage             │ ║
║  │  Cloud Functions v2   — Serverless Node.js backend     │ ║
║  │    (Node.js 24, firebase-functions v7)                 │ ║
║  │    • initiateMpesaPayment — STK Push trigger           │ ║
║  │    • checkPaymentStatus   — Payment status query       │ ║
║  │    • mpesaCallback        — Safaricom webhook receiver │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  PAYMENT GATEWAY                                             ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │  Safaricom Daraja API (M-Pesa)                         │ ║
║  │  • Environment: Sandbox (development)                  │ ║
║  │  • STK Push (Lipa Na M-Pesa Online)                   │ ║
║  │  • OAuth 2.0 client credentials flow                   │ ║
║  │  • Webhook callback to Firebase Functions              │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  OFFLINE STORAGE                                             ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │  Hive          — Room sync queue (local DB)            │ ║
║  │  SecureStorage — Encrypted user session + action queue │ ║
║  │  Firestore SDK — Built-in offline cache                │ ║
║  └────────────────────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Summary for Presentation

| Aspect | Detail |
|--------|--------|
| **Platform** | Flutter (Android, Web, Windows) |
| **Backend** | Firebase (Auth, Firestore, Storage, Functions) |
| **Payment** | Safaricom Daraja API — M-Pesa STK Push |
| **Architecture** | Offline-first, real-time streaming, role-based access |
| **Users** | Students + Admin (dual-role system) |
| **Key Problem Solved** | Digitises manual hostel management: booking, payments, maintenance |
| **Unique Features** | M-Pesa integration, offline queue, real-time dashboard, PDF reports, cross-platform |
| **Database** | Cloud Firestore — 5 collections: users, rooms, bookings, payments, maintenance_requests |
| **Reports** | PDF admin report + live dashboard metrics |
| **Computations** | Occupancy rate, rent status, payment password, phone normalization, offline backoff |

---

*Generated for SHMS Final Year Project Presentation*
*Project: Student Hostel Management System | Firebase Project: shms-7b88d*
