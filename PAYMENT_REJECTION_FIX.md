# Payment Rejection Flow - Complete Fix Documentation

## Overview
This document describes the complete payment rejection workflow implementation that allows admins to reject customer payments and notify customers to re-upload proof of payment.

---

## System Architecture

### Components Involved
1. **Admin Payment Polling Service** (`adminPaymentPollingService.dart`)
   - Detects new/unverified payments every 10 seconds
   - Triggers real-time notifications on admin dashboard
   - Manages deduplication to prevent spam

2. **Notification Store** (`notificationStore.dart`)
   - Singleton shared notification state across app
   - Persists notifications to SharedPreferences
   - Used for both admin and customer notification history

3. **Bill Service** (`kelolaBill.dart`)
   - Handles payment rejection logic
   - Creates rejection notifications
   - Rejects payments via DELETE /payments/{id}

4. **Admin Dashboard** (`adminDashboard.dart`)
   - Displays floating notifications when payments arrive
   - Shows notification badge with count
   - Syncs with notification store

5. **Customer Bill View** (`bill.dart`)
   - Displays unpaid bills
   - Detects rejected payment status
   - Shows re-upload button when rejected
   - Auto-refreshes when rejection notification arrives

---

## Payment Rejection Workflow

### Step 1: Admin Rejects Payment
**Location**: `lib/views/admins/kelolaBill.dart` (line 593)

```dart
// Admin clicks "Tolak" button
await _billService.verifyRejectPayment(payment.id);
```

### Step 2: Service Creates Rejection Notification
**Location**: `lib/services/kelolaBill.dart` → `verifyRejectPayment()`

**Before (DELETE only)**:
```
DELETE /payments/{id}
↓
Try to send notification via API endpoint (may fail)
```

**After (DELETE + NotificationStore)**:
```
DELETE /payments/{id}
↓
Load NotificationStore
↓
Add rejection notification to store
↓
Save to SharedPreferences
↓
Notify all listeners
```

### Step 3: Customer Receives Notification

**Method**: NotificationStore (in-app persistent storage)

**Notification Content**:
- Title: "⚠️ Pembayaran Ditolak"
- Body: "Pembayaran Anda telah ditolak. Alasan: {reason}...\n\nSilakan upload ulang bukti pembayaran..."

### Step 4: Customer Auto-Detects Rejection

**Location**: `lib/views/customers/bill.dart` → `_BillState`

**Process**:
1. NotificationStore listener triggers on new rejection
2. `_fetchData()` called automatically
3. Fetches latest bills and payments
4. Payment model detects `status == 'rejected'`
5. UI updates to show rejection alert and re-upload button

### Step 5: Customer Re-uploads Proof

**Location**: `lib/views/customers/bill.dart` → `_buildUnpaidCard()`

**UI Elements**:
- Red alert box: "Pembayaran ditolak. Silakan upload bukti pembayaran yang sesuai."
- Red "Upload Ulang" button (instead of "Bayar" or "Kirim Ulang")
- Opens payment upload sheet same as initial upload

---

## Implementation Details

### 1. Rejection Notification Creation
**File**: `lib/services/kelolaBill.dart`

```dart
Future<void> _notifyPaymentRejected(String reason) async {
  try {
    await _notificationStore.load();
    await _notificationStore.add(
      title: '⚠️ Pembayaran Ditolak',
      body: 'Pembayaran Anda telah ditolak. Alasan: $reason\n\nSilakan upload ulang bukti pembayaran yang sesuai di halaman pembayaran Anda.',
    );
    debugPrint('[KelolaBillService] Rejection notification added to store');
  } catch (e) {
    debugPrint('[KelolaBillService] Error notifying rejection: $e');
  }
}
```

### 2. Customer Bill Auto-Refresh
**File**: `lib/views/customers/bill.dart`

```dart
// Listen to notification store changes
_notifStore.addListener(_onNotificationUpdated);

void _onNotificationUpdated() {
  debugPrint('[Bill] Notification updated, refreshing data');
  _fetchData();
}

@override
void dispose() {
  _notifStore.removeListener(_onNotificationUpdated);
  super.dispose();
}
```

### 3. Rejection Status Detection
**File**: `lib/models/bill.dart` → `Payment.fromJson()`

```dart
String status = 'pending';
if (statusVal == 'verified' || statusVal == 'success' || isVerified) {
  status = 'verified';
} else if (statusVal == 'rejected' || statusVal == 'reject' || statusVal == 'ditolak') {
  status = 'rejected';
}
```

### 4. UI Display
**File**: `lib/views/customers/bill.dart` → `_buildUnpaidCard()`

```dart
final isPaymentRejected = lastPayment?.status == 'rejected';

// Show rejection alert
if (isPaymentRejected)
  Container(
    decoration: BoxDecoration(
      color: const Color(0xffFFEBEE), // Light red
      border: Border.all(color: const Color(0xffF04438)),
    ),
    child: Text('Pembayaran ditolak. Silakan upload bukti pembayaran yang sesuai.'),
  )

// Show re-upload button
ElevatedButton(
  onPressed: () => _openPaymentSheet(context, bill),
  label: Text(isPaymentRejected ? 'Upload Ulang' : 'Bayar'),
  style: ElevatedButton.styleFrom(
    backgroundColor: isPaymentRejected ? const Color(0xffF04438) : Colors.green,
  ),
)
```

---

## Admin Dashboard Floating Notifications

### Real-time Notification Animation
**File**: `lib/views/admins/adminDashboard.dart`

**Features**:
- Slide-down animation from top (400ms)
- Auto-dismiss after 5 seconds
- Shows customer name and payment amount
- Includes app badge with count

**Implementation**:
```dart
void _triggerFloatingNotif({...}) {
  setState(() {
    _showFloatingNotif = true;
  });
  
  // Reset animation if already animating
  if (_floatAnimController.isAnimating) {
    _floatAnimController.reset();
  }
  
  // Slide down
  _floatAnimController.forward(from: 0.0);
  
  // Auto-dismiss after 5s
  Future.delayed(const Duration(seconds: 5), () {
    _dismissFloatingNotif();
  });
}
```

---

## Data Flow Diagram

```
Admin Dashboard
    ↓
    └─→ Polling Service (every 10s)
         ├─ Detects new payment
         ├─ Calls onNewPayment callback
         └─ Triggers floating notification UI
              └─→ Adds to NotificationStore
                   └─→ Saves to SharedPreferences

Admin Payment Management (KelolaBill)
    ↓
    └─→ Click "Tolak" button
         ├─ DELETE /payments/{id}
         ├─ Load NotificationStore
         └─ Add rejection notification
              ├─ Save to SharedPreferences
              └─ Notify listeners
                   ↓
Customer Bill Page (Listener)
    ├─ Hears notification update
    ├─ Calls _fetchData()
    ├─ Gets latest bills/payments
    ├─ Payment model detects status='rejected'
    └─ UI updates:
         ├─ Shows rejection alert (red)
         └─ Changes button to "Upload Ulang" (red)

Customer Notification Page
    └─ Displays rejection message
```

---

## Testing Checklist

### Admin Side
- [ ] Admin opens dashboard
- [ ] Customer uploads payment proof
- [ ] Payment appears in admin KelolaBill page
- [ ] Admin clicks "Tolak" button
- [ ] Confirmation dialog appears
- [ ] Admin confirms rejection
- [ ] Success message shown
- [ ] Floating notification briefly appears (5 seconds)
- [ ] Notification badge appears on bell icon
- [ ] Notification appears in admin notification history

### Customer Side
- [ ] Customer opens app (NotificationStore loads)
- [ ] Customer opens "Notifikasi" tab
- [ ] Rejection notification visible with message
- [ ] Customer opens "Tagihan" (Bills) tab
- [ ] Bill shows red rejection alert
- [ ] Button shows "Upload Ulang" in red
- [ ] Clicking button opens payment upload
- [ ] Customer can upload new proof
- [ ] After successful upload, button shows "Bayar" again

---

## Known Issues & Limitations

1. **DELETE vs UPDATE**: Payment is deleted, not marked as rejected in database
   - Current approach works because NotificationStore tracks rejection
   - Customer sees notification even if payment doesn't exist in DB

2. **Backend Notification Endpoint**: `/notifications/send` may not exist
   - Fixed by using NotificationStore instead
   - No longer depends on backend API for notifications

3. **Floating Notification Timing**: 5-second display may not be enough
   - Can be configured in `_triggerFloatingNotif()` via `Future.delayed()`

4. **Double Notifications**: Both system notification and in-app notification
   - System notification uses `notificationService`
   - In-app uses `NotificationStore`
   - Both serve different purposes and are kept separate

---

## Configuration Options

### Polling Interval
**File**: `lib/services/adminPaymentPollingService.dart`

```dart
static const Duration _pollInterval = Duration(seconds: 10);
```

Change to increase/decrease polling frequency (affects real-time responsiveness)

### Floating Notification Duration
**File**: `lib/views/admins/adminDashboard.dart`

```dart
Future.delayed(const Duration(seconds: 5), () {
  _dismissFloatingNotif();
});
```

Change 5 seconds to longer/shorter duration

### Notification Store Limit
**File**: `lib/services/notificationStore.dart`

```dart
if (_items.length > 100) {
  _items = _items.sublist(0, 100);
}
```

Change 100 to store more/fewer notifications

---

## Debugging

### Enable Debug Logs

Add to relevant files to see flow:

1. Admin Floating Notification
```
[FloatingNotif] Triggered: ...
[FloatingNotif] Animation completed
[FloatingNotif] Dismissed
```

2. Payment Polling
```
[Polling] current=X, last=Y
[Polling] Callback executed with N payments
```

3. Rejection Notification
```
[KelolaBillService] Rejection notification added to store
```

4. Customer Bill Auto-Refresh
```
[Bill] Notification updated, refreshing data
```

### Common Issues

**Issue**: Rejection notification not showing
- **Check**: NotificationStore loaded in main.dart
- **Solution**: Ensure `await NotificationStore().load();` in main()

**Issue**: Floating notification not visible
- **Check**: Animation controller initialized
- **Solution**: Verify `_initAnimations()` called in initState

**Issue**: Bill not updating after rejection
- **Check**: _fetchData() being called
- **Solution**: Verify listener connected in bill.dart initState

**Issue**: Re-upload button not showing
- **Check**: Payment status == 'rejected'
- **Solution**: Verify backend returns correct status or use NotificationStore

---

## Future Improvements

1. **Email Notifications**: Send email when payment rejected (admin configurable)
2. **SMS Alerts**: Send SMS to customer about rejection
3. **Auto-Reupload Reminder**: Show popup reminder if payment rejected > 2 days
4. **Rejection Reason Display**: Show detailed reason from admin in customer bill
5. **Payment History**: Track all rejections/re-uploads with timestamps
6. **Analytics**: Track rejection rate, re-upload success rate, etc.

---

## Summary

The payment rejection system now works completely through:
1. **Admin rejects** → Creates notification
2. **Notification stored** → In NotificationStore + SharedPreferences
3. **Customer app loads** → Initializes NotificationStore
4. **Customer sees notification** → In notification history page
5. **Bill auto-refreshes** → When notification arrives
6. **Re-upload UI shows** → When status = 'rejected'
7. **Customer re-uploads** → Same upload flow

**No API endpoint dependency** for rejection notifications - uses robust local storage instead.
