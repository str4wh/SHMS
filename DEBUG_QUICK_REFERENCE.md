# 🔍 Quick Debug Reference Card

## How to Use Enhanced Debug Logging

### 1️⃣ Start the App

```powershell
cd "d:\SHMS\mysmhs"
flutter run -d chrome
```

### 2️⃣ Watch Console for These Key Indicators

#### ✅ **CORRECT Output (Booking Found)**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏠 StudentDashboard build
   Current user email: student2@gmail.com
   Current UID: xyz123abc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Booking status stream update:
   Current UID (query filter): xyz123abc
   Current user email: student2@gmail.com
   Docs count: 1
   ✅ Latest booking found:
      studentID field: xyz123abc
      Current UID match: true ← THIS MUST BE TRUE!
      Status: approved
```

#### ❌ **PROBLEM: No Booking Found**

```
📊 Booking status stream update:
   Docs count: 0
   ℹ️ No bookings found
```

**→ Go to Firestore and check if booking exists for this UID**

#### ⚠️ **PROBLEM: UID Mismatch**

```
📊 Booking status stream update:
   Docs count: 1
   ✅ Latest booking found:
      studentID field: abc789xyz
      Current UID match: false ← WRONG UID IN BOOKING!
```

**→ Booking exists but has wrong studentID**

---

## 3️⃣ Quick Fixes

### Fix A: Field Name Wrong

If logs show `Docs count: 0` but booking exists in Firestore:

**Check:** Is the field in Firestore called `studentID` or `studentId`?

**Update line ~60 in student_dashboard_page.dart:**

```dart
.where('studentId', isEqualTo: uid) // Change to match Firestore
```

### Fix B: Wrong UID Stored

If logs show `Current UID match: false`:

1. Go to Firestore → bookings collection
2. Find the booking document
3. Edit `studentID` field to correct UID
4. Or delete and recreate booking

### Fix C: Missing Index

If browser console shows "requires an index":

1. Click the Firebase link in error
2. Wait 2 minutes
3. Refresh app

---

## 4️⃣ Testing Checklist

After fixing:

- [ ] Student 1 shows "Active" ✅
- [ ] Student 2 shows "Active" or "Pending" ✅
- [ ] New student shows "No booking" ✅
- [ ] Console logs show `Current UID match: true` ✅

---

## 📞 Report Issue Format

If still not working, copy this and fill in:

```
Current user email: _________________
Current UID: _________________
Docs count: _________________
studentID field (from booking): _________________
Current UID match: _________________
Firestore field name: studentID or studentId?
Status field value: _________________
```
