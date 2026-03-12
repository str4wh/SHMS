# Quick Error Diagnosis Reference

## 🎯 Quick Issue Identifier

Run this checklist to quickly identify what's wrong:

### ✅ Admin Routing Issue

**Symptom:** Admin goes to student dashboard instead of admin dashboard

**Quick Check:**

1. Open browser console during login
2. Look for: `🏠 StudentDashboard build` when admin logs in → **BUG CONFIRMED**
3. Should see: `🏠 AdminDashboard build` → **WORKING CORRECTLY**

**Quick Fix Applied:**

- Fixed race condition in auth flow
- Role now cached immediately before navigation

---

### ✅ Data Loading Issue

**Symptom:** "Failed to load profile", "Failed to load rooms", "Error" in Rent Status

**Quick Check:**

1. Open browser console
2. Look for these specific errors:

#### Error Type 1: Permission Denied ⚠️

```
FirebaseError: Missing or insufficient permissions
code: permission-denied
```

**Cause:** Firestore rules not deployed  
**Fix:** Run `firebase deploy --only firestore:rules`

#### Error Type 2: Field Not Found

```
❌ No bookings found for studentID: [uid]
```

**Cause:** Wrong field name in Firestore (using `student_id` instead of `studentID`)  
**Fix:** Update Firestore documents to use `studentID` (camelCase)

#### Error Type 3: Index Missing

```
The query requires an index
```

**Cause:** Composite index not created  
**Fix:** Click the link in error message or manually create index

#### Error Type 4: User Document Missing

```
❌ User profile error: Document does not exist
```

**Cause:** User document not created in Firestore  
**Fix:** Ensure signup creates user document with `role` field

---

## 🔍 Console Commands for Debugging

### Check if user is authenticated:

```javascript
console.log("Current User:", firebase.auth().currentUser);
```

### Check user's role in Firestore:

```javascript
const uid = firebase.auth().currentUser?.uid;
firebase
  .firestore()
  .collection("users")
  .doc(uid)
  .get()
  .then((doc) => {
    console.log("User exists:", doc.exists);
    console.log("User role:", doc.data()?.role);
  });
```

### Check if bookings exist:

```javascript
const uid = firebase.auth().currentUser?.uid;
firebase
  .firestore()
  .collection("bookings")
  .where("studentID", "==", uid)
  .get()
  .then((snap) => {
    console.log("Bookings count:", snap.size);
    snap.docs.forEach((doc) => console.log("Booking:", doc.data()));
  });
```

### Check Firestore rules status:

```bash
firebase firestore:rules:get
```

---

## 🚦 Expected Console Output (Working System)

### During Login (Admin):

```
firebase: Firebase Core initialized
Auth state changed: user logged in
Role cached: admin
🏠 AdminDashboard build
   Current user email: admin@example.com
```

### During Login (Student):

```
firebase: Firebase Core initialized
Auth state changed: user logged in
Role cached: student
🏠 StudentDashboard build
   Current user email: student@example.com
   Current UID: [uid]
📊 Bookings query created for studentID: [uid]
```

### Student Dashboard (Successful Load):

```
🏠 StudentDashboard build
📊 Bookings query created for studentID: abc123
📊 Booking status stream update:
   Current UID (query filter): abc123
   Has error: false
   Connection state: ConnectionState.active
   Docs count: 1
   ✅ Latest booking found:
      Booking ID: booking123
      Status (raw): "pending"
      Status (processed): "pending"
      Room Number: 101
```

---

## ⚡ Quick Fixes

### Clear all cached data:

```dart
// Add temporarily to main() before runApp():
await LocalCacheService.instance.clearCache();
await FirebaseAuth.instance.signOut();
```

### Force rule reload:

```bash
firebase deploy --only firestore:rules
```

### Reset and test:

1. Clear browser cache (Ctrl+Shift+Delete)
2. Sign out from app
3. Sign in again
4. Check console for errors

---

## 🎯 Success Indicators

✅ **Admin routing working:**

- Admin login → Redirects to `/admin`
- Console shows: `🏠 AdminDashboard build`
- Drawer shows "Admin Panel"

✅ **Student dashboard working:**

- Student login → Redirects to `/student-dashboard`
- Profile name displays (not "Failed to load profile")
- Room assignment shows (not "—")
- Rent Status shows amount or "Paid" (not "Error")
- Available Rooms grid displays (not "Failed to load rooms")
- Room images load

✅ **No errors:**

- No red errors in browser console
- No permission-denied errors
- No "Failed to load" cards in UI

---

## 🆘 Emergency Checks

If nothing works, verify these in order:

1. **Firebase connection:**

   ```javascript
   console.log("Firebase App:", firebase.app().name); // Should print "[DEFAULT]"
   ```

2. **User authenticated:**

   ```javascript
   console.log("Auth user:", firebase.auth().currentUser?.email); // Should show email
   ```

3. **User doc exists:**

   ```javascript
   firebase
     .firestore()
     .collection("users")
     .doc(firebase.auth().currentUser.uid)
     .get()
     .then((doc) =>
       console.log("User doc exists:", doc.exists, "Role:", doc.data()?.role),
     );
   ```

4. **Rules deployed:**

   ```bash
   firebase firestore:rules:get
   # Should show the new rules with isAdmin() function
   ```

5. **Field names correct:**
   Check one booking document:
   ```javascript
   firebase
     .firestore()
     .collection("bookings")
     .limit(1)
     .get()
     .then((snap) =>
       snap.docs.forEach((doc) =>
         console.log("Booking fields:", Object.keys(doc.data())),
       ),
     );
   // Should include "studentID" not "student_id"
   ```

---

## 📋 Files Modified

| File                              | Purpose                                  |
| --------------------------------- | ---------------------------------------- |
| `lib/authpage.dart`               | Fixed admin routing race condition       |
| `lib/student_dashboard_page.dart` | Enhanced error messages for debugging    |
| `firestore.rules`                 | NEW - Security rules for all collections |
| `FIX_SUMMARY.md`                  | Complete documentation of changes        |
| `ERROR_QUICK_REFERENCE.md`        | This file - quick debugging guide        |
