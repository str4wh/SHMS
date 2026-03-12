# Room Switching Transaction Fix - Debug Guide

## Summary of Changes

The `_handleBook` method in `room_details_page.dart` has been completely refactored with comprehensive error logging, validation, and proper transaction handling to fix room switching issues.

---

## Key Fixes Applied

### 1. **Comprehensive Debug Logging**

Every step now logs detailed information when running in debug mode:

- Transaction start/end
- Document reads with field values
- Write operations being queued
- Error details with stack traces
- Field type conversions

**How to view logs:**

- Run app in debug mode
- Watch console for emoji-prefixed messages:
  - 🔵 Function entry
  - 🔍 Checking/querying
  - 📋 Data retrieved
  - ✅ Success
  - ❌ Error
  - ⚠️ Warning
  - 🔄 Transaction operations
  - 📖 Reading documents
  - 📝 Writing documents

### 2. **Same Room Rebooking Detection**

**Problem:** User could try to book the same room they already have
**Fix:** Added check `if (oldRoomID == roomId)` before room switch dialog

### 3. **Proper Transaction Structure**

**Problem:** Firebase transactions require all reads before any writes
**Fix:** Restructured transaction to:

1. Read all documents first (new room, old booking, old room, user)
2. Log all read data for verification
3. Perform all writes after reads complete
4. Queue all writes before transaction commits

### 4. **Type Consistency Validation**

**Firestore Schema:**

```
bookings.roomNumber: string  (e.g., "2004")
users.assignedRoom: number   (e.g., 2004)
bookings.price: number (double)
```

**Conversions applied:**

```dart
// For bookings - keep as string
final roomNumber = roomData['roomNumber']?.toString() ?? '';

// For users - convert to int
final roomNumberInt = int.tryParse(roomNumber) ?? 0;

// For price - ensure double
final price = (roomData['price'] as num?)?.toDouble() ?? 0.0;
```

### 5. **Field Name Validation**

Verified case-sensitive field names:

- `studentID` (not studentId or StudentID)
- `roomID` (not roomId)
- `occupiedBy` (properly deleted with `FieldValue.delete()`)

### 6. **Better Error Messages**

**Before:** Generic "Failed to switch rooms"
**After:** Detailed messages showing:

- Firebase error codes
- Specific validation failures
- Helpful suggestions to contact support

### 7. **Edge Cases Handled**

- Empty room numbers
- Missing room documents
- Room already occupied
- Failed type conversions
- Network errors during query
- Transaction rollback on any failure

---

## Debug Workflow

### When a student reports booking issues:

1. **Enable Debug Mode**

   - Run app in debug mode
   - Ask student to reproduce issue
   - Watch console logs

2. **Check Initial Query**

   ```
   🔍 Checking for existing bookings...
   Found X existing booking(s)
   ```

   - Verify `studentID` matches user UID
   - Confirm existing booking is found

3. **Monitor Transaction**

   ```
   🔄 Starting room switch transaction...
   📖 Transaction started - Reading documents...
   ```

   - All reads should complete successfully
   - Check field values in logs

4. **Verify Writes**

   ```
   📝 Cancelling old booking: [bookingId]
   📝 Freeing old room: [oldRoomId]
   📝 Creating new booking: [details]
   📝 Marking new room as occupied: [roomId]
   📝 Updating user document: [details]
   ✅ All writes queued successfully
   ```

5. **Check Commit**
   ```
   ✅ Transaction committed successfully
   ```

### Common Issues to Look For:

**Issue 1: Query returns no bookings**

```
Found 0 existing booking(s)
```

**Possible causes:**

- Field name mismatch (`studentID` vs `studentId`)
- Wrong status values in query
- User actually has no bookings

**Issue 2: Room not available**

```
❌ New room not available: occupied
```

**Possible causes:**

- Room was booked by another user
- Previous transaction didn't complete
- Room status not properly freed

**Issue 3: Type conversion fails**

```
⚠️ Warning: Could not parse room number "ABC" to int
```

**Possible causes:**

- roomNumber contains non-numeric characters
- Firestore schema has inconsistent types

**Issue 4: Transaction fails**

```
❌ FirebaseException during switch:
   Code: permission-denied
   Message: Missing or insufficient permissions
```

**Possible causes:**

- Firestore security rules blocking operation
- User not authenticated properly
- Missing required fields

---

## Testing Checklist

### Normal Booking Flow

- [ ] Student books available room
- [ ] Room status changes to occupied
- [ ] User document updated with assignedRoom (int) and roomId
- [ ] Booking created with correct status

### Room Switching Flow

- [ ] Student with existing booking tries new room
- [ ] Confirmation dialog shows old room number
- [ ] Old booking cancelled (status = 'cancelled')
- [ ] Old room freed (availability = 'available', occupiedBy deleted)
- [ ] New booking created
- [ ] New room occupied
- [ ] User document updated with new room info

### Same Room Rebooking

- [ ] Student tries to book same room
- [ ] Special message: "You already have an active booking"
- [ ] No transaction executed

### Edge Cases

- [ ] Room becomes unavailable during booking (race condition)
- [ ] Network error during transaction
- [ ] Invalid room number format
- [ ] Missing price field

---

## Firestore Security Rules Recommendations

Ensure your Firestore rules allow these operations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Bookings collection
    match /bookings/{bookingId} {
      // Users can read their own bookings
      allow read: if request.auth != null
        && resource.data.studentID == request.auth.uid;

      // Users can create bookings for themselves
      allow create: if request.auth != null
        && request.resource.data.studentID == request.auth.uid;

      // Users can update their own bookings (for cancellation)
      allow update: if request.auth != null
        && resource.data.studentID == request.auth.uid;
    }

    // Rooms collection
    match /rooms/{roomId} {
      // Everyone can read rooms
      allow read: if true;

      // Only authenticated users can update room status during booking
      allow update: if request.auth != null;
    }

    // Users collection
    match /users/{userId} {
      // Users can read/update their own document
      allow read, update: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

---

## Performance Monitoring

### Monitor these metrics:

1. **Transaction success rate** - Should be > 95%
2. **Query performance** - Existing booking check < 1s
3. **Transaction duration** - Room switch < 3s
4. **Error frequency** - Check for patterns in error logs

### Add analytics events (optional):

```dart
// Track booking attempts
FirebaseAnalytics.instance.logEvent(
  name: 'booking_attempt',
  parameters: {'room_id': roomId, 'user_id': uid},
);

// Track successes
FirebaseAnalytics.instance.logEvent(
  name: 'booking_success',
  parameters: {'room_id': roomId, 'booking_type': 'switch'},
);

// Track failures
FirebaseAnalytics.instance.logEvent(
  name: 'booking_failed',
  parameters: {'error': e.toString(), 'room_id': roomId},
);
```

---

## Next Steps

1. **Test thoroughly** in debug mode
2. **Monitor logs** for the emoji-prefixed debug messages
3. **Verify** transactions complete successfully
4. **Check Firestore** documents to confirm field types match schema
5. **Update security rules** if permission errors occur

---

## Support Contacts

If issues persist after implementing these fixes:

1. Check console logs for specific error messages
2. Verify Firestore security rules
3. Confirm field names match exactly (case-sensitive)
4. Test with a fresh user account
5. Check Firebase console for any service disruptions
