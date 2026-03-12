# 🐛 Booking Status Debug Guide

## Problem Summary

- **Student 1** (student1@gmail.com): Shows "Active" status ✅ **CORRECT**
- **Student 2** (has booked a room): Shows "No booking" ❌ **WRONG**
- Booking exists in Firestore but isn't being fetched

---

## 🔍 Step 1: Run the App with Debug Logging

### Open the app in debug mode:

```powershell
cd "d:\SHMS\mysmhs"
flutter run -d chrome
```

### Watch for these logs in the console:

**When page loads:**

```
════════════════════════════════════════
🏠 StudentDashboard build
   Current user email: [email]
   Current UID: [uid]
════════════════════════════════════════
📊 Bookings query created for studentID: [uid]
```

**When StreamBuilder updates:**

```
📊 Booking status stream update:
   Current UID (query filter): [uid]
   Current user email: [email]
   Has error: false
   Connection state: ConnectionState.active
   Docs count: 0 or 1
```

**If booking found:**

```
   ✅ Latest booking found:
      Booking ID: [docId]
      studentID field: [value from Firestore]
      Current UID match: true or false  ← CRITICAL!
      Status: approved
      Room Number: 101
      Room ID: [roomDocId]
      All booking fields: [list of fields]
```

**If no booking found:**

```
   ℹ️ No bookings found
```

---

## 🎯 Step 2: Identify the Issue

### Test with Student 1 (WORKING):

1. Log in as `student1@gmail.com`
2. Check console logs
3. **Record these values:**
   ```
   Current user email: student1@gmail.com
   Current UID: ___________________
   Docs count: 1
   studentID field: ___________________
   Current UID match: true ← Should be TRUE
   ```

### Test with Student 2 (NOT WORKING):

1. Log out
2. Log in as the second student
3. Check console logs
4. **Record these values:**
   ```
   Current user email: ___________________
   Current UID: ___________________
   Docs count: 0 or 1
   studentID field: ___________________
   Current UID match: ??? ← KEY INDICATOR
   ```

---

## 🔎 Step 3: Compare Results

### Scenario A: `Docs count: 0` (Query returns nothing)

**Possible causes:**

1. **Field name mismatch in Firestore**

   - Go to Firebase Console → Firestore → `bookings` collection
   - Open Student 2's booking document
   - Check if the field is named exactly: `studentID` (capital I, capital D)
   - Common mistakes:
     - ❌ `studentId` (lowercase 'd')
     - ❌ `userId`
     - ❌ `uid`
     - ❌ `StudentID` (capital S)

2. **Wrong UID stored in booking**

   - The `studentID` field might contain the wrong UID
   - Compare the value in Firestore with the "Current UID" in logs

3. **Missing composite index**
   - Check browser console for: "The query requires an index"
   - If present, click the link to create the index
   - Wait 1-2 minutes for it to build

**Fix for Scenario A:**

```dart
// If Firestore uses 'studentId' instead of 'studentID':
final bookingsStream = FirebaseFirestore.instance
    .collection('bookings')
    .where('studentId', isEqualTo: uid) // ← Change to match Firestore
    .orderBy('bookingDate', descending: true)
    .limit(1)
    .snapshots();
```

---

### Scenario B: `Docs count: 1` but `Current UID match: false`

**This means:**

- Query returned a booking
- But the `studentID` in that booking doesn't match the current user's UID
- **This is a data integrity issue**

**Possible causes:**

1. **Wrong UID was stored when creating booking**

   - Check `room_details_page.dart` where bookings are created
   - Ensure: `'studentID': uid` uses the correct user ID

2. **User logged in with different account than booking was created for**
   - Verify the user email matches the one used to create the booking

**How to verify in Firestore Console:**

1. Go to Firestore → `bookings` collection
2. Find Student 2's booking document
3. Click on it to view fields
4. Check `studentID` field value
5. Go to Authentication tab
6. Find Student 2's account
7. Copy their UID
8. Compare: **Booking's studentID** vs **User's UID**
   - If they don't match → Data was corrupted during booking creation
   - If they match → UID from `FirebaseAuth.instance.currentUser?.uid` is wrong

---

### Scenario C: `Docs count: 1` and `Current UID match: true`

**This means:**

- Query is working correctly
- The issue is in the UI display logic

**Check:**

1. Status field value: `${bookingData['status']}`
2. Should be one of: `approved`, `pending`, `cancelled`, `expired`
3. If it's something else, the status switch case won't match

---

## 🛠️ Step 4: Apply the Fix

### Fix 1: Field Name Mismatch

If Firestore uses a different field name (e.g., `studentId`):

```dart
// In student_dashboard_page.dart, line ~60
final bookingsStream = FirebaseFirestore.instance
    .collection('bookings')
    .where('studentId', isEqualTo: uid) // ← Update field name
    .orderBy('bookingDate', descending: true)
    .limit(1)
    .snapshots();

// Also update these queries:
final paymentsStream = FirebaseFirestore.instance
    .collection('payments')
    .where('studentId', isEqualTo: uid) // ← Update field name
    .orderBy('dueDate', descending: false)
    .snapshots();

final maintenanceStream = FirebaseFirestore.instance
    .collection('maintenance_requests')
    .where('studentId', isEqualTo: uid) // ← Update field name
    .where('status', whereIn: ['open', 'pending'])
    .snapshots();
```

### Fix 2: Data Integrity Issue

If the booking has the wrong `studentID`:

**Option A: Fix manually in Firestore Console**

1. Go to the booking document
2. Edit the `studentID` field
3. Set it to the correct user's UID

**Option B: Delete and recreate the booking**

1. Delete the incorrect booking
2. Log in as Student 2
3. Book a new room
4. Verify the UID is stored correctly

### Fix 3: Composite Index Missing

If browser console shows index error:

1. Click the provided Firebase link
2. Wait 1-2 minutes for index to build
3. Refresh the app

---

## ✅ Step 5: Test All Scenarios

After applying the fix:

### Test 1: Student with Active Booking

- Log in as student1@gmail.com
- **Expected:** "Active" badge (green) ✅

### Test 2: Student with Different Booking

- Log in as student2
- **Expected:** "Active" or "Pending" badge ✅

### Test 3: New Student (No Booking)

- Create new account (student3@gmail.com)
- Don't book a room
- **Expected:** "No booking" badge (gray) ✅

### Test 4: Student with Cancelled Booking

- Cancel a booking in Firestore (set status to 'cancelled')
- **Expected:** "Cancelled" badge (red) ✅

---

## 📊 Expected Console Output (Success)

### For Student with Booking:

```
════════════════════════════════════════
🏠 StudentDashboard build
   Current user email: student2@gmail.com
   Current UID: xyz123abc456
════════════════════════════════════════
📊 Bookings query created for studentID: xyz123abc456

📊 Booking status stream update:
   Current UID (query filter): xyz123abc456
   Current user email: student2@gmail.com
   Has error: false
   Connection state: ConnectionState.active
   Docs count: 1
   ✅ Latest booking found:
      Booking ID: abc123
      studentID field: xyz123abc456
      Current UID match: true  ← MUST BE TRUE
      Status: approved
      Room Number: 102
      Room ID: room_abc123
      All booking fields: [studentID, roomID, roomNumber, status, price, bookingDate, startDate, endDate]
```

### For Student without Booking:

```
════════════════════════════════════════
🏠 StudentDashboard build
   Current user email: student3@gmail.com
   Current UID: def789ghi012
════════════════════════════════════════
📊 Bookings query created for studentID: def789ghi012

📊 Booking status stream update:
   Current UID (query filter): def789ghi012
   Current user email: student3@gmail.com
   Has error: false
   Connection state: ConnectionState.active
   Docs count: 0
   ℹ️ No bookings found
```

---

## 🚨 Common Errors to Look For

### Error 1: Index Required

**Console shows:**

```
The query requires an index. You can create it here: https://...
```

**Solution:** Click the link, wait 2 minutes, refresh app

### Error 2: Permission Denied

**Console shows:**

```
❌ Stream error: [firebase_firestore/permission-denied] The caller does not have permission
```

**Solution:** Check Firestore security rules

### Error 3: UID is null

**Console shows:**

```
Current UID: null
```

**Solution:** User is not authenticated, redirect to login

---

## 📋 Debugging Checklist

- [ ] Run app in debug mode
- [ ] Log in as Student 1 → Record UID and console output
- [ ] Log in as Student 2 → Record UID and console output
- [ ] Check Firestore Console → Verify `studentID` field exists
- [ ] Compare UIDs: Current user vs. Booking document
- [ ] Check `Current UID match` value in logs
- [ ] Verify status field value: `approved`, `pending`, etc.
- [ ] Test fix with multiple users
- [ ] Verify "No booking" shows for new users

---

## 🎓 Next Steps

1. **Run the app** with the updated logging
2. **Copy the console output** for both students
3. **Share the logs** if you need help identifying the issue
4. **Apply the appropriate fix** based on the scenario
5. **Test thoroughly** with all users

The enhanced logging will clearly show you which scenario you're dealing with and guide you to the exact fix needed!
