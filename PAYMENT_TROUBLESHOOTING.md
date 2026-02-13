# 🔧 PAYMENT EXCEPTION TROUBLESHOOTING GUIDE

## **🚨 When You See "Payment Exception":**

### **Step 1: Check Game Status**
```bash
# In Firebase Console, check:
games/{gameId}/status = "pending"
```
**If not "pending":**
- Game has started → Cannot purchase cards
- Solution: Join a different pending game

### **Step 2: Check Player Balance**
```bash
# In Firebase Console, check:
players/{playerId}/balance = number
```
**Common Issues:**
- Balance is null → Set balance manually
- Balance is string → Convert to number
- Balance < cost → Add funds

### **Step 3: Check Firebase Rules**
```javascript
// In Firestore rules, ensure:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /players/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /games/{gameId} {
      allow read, write: if request.auth != null;
    }
    match /games/{gameId}/playerData/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### **Step 4: Check Network Connection**
- Ensure stable internet connection
- Try different network (WiFi/Mobile)
- Check Firebase status: https://status.firebase.google.com/

---

## **🔍 Debug Console Messages:**

### **Look for These Specific Messages:**

#### **✅ Success Messages:**
```
=== LEGACY PAYMENT METHOD CALLED ===
Game ID: [game_id]
Player ID: [player_id]  
Number of Cards: [number]
Card Cost: [cost]

=== PAYMENT DEBUG START ===
Running pre-checks...
✅ Player found
✅ Balance parsed as number: [amount]
✅ Game status: pending
✅ All pre-checks passed, starting transaction...
✅ Payment SUCCESS
```

#### **❌ Error Messages:**
```
❌ Player not found → Player document missing
❌ Balance value is null → No balance field
❌ Invalid balance type → Balance format wrong
❌ Insufficient balance → Not enough money
❌ Game not found → Game deleted
❌ Game is not pending → Game started
❌ Player already has cards → Duplicate purchase
```

---

## **🛠️ QUICK FIXES:**

### **Fix 1: Set Player Balance**
```javascript
// In Firebase Console → Players → Select player → Add field:
balance: 100.0
```

### **Fix 2: Create Test Game**
```javascript
// In Firebase Console → Games → Add document:
{
  "gameName": "Test Game",
  "status": "pending",
  "entryFee": 10.0,
  "maxPlayers": 4,
  "players": [],
  "winningPattern": "Any Line",
  "calledNumbers": [],
  "totalCardsSold": 0,
  "createdAt": timestamp
}
```

### **Fix 3: Update Game Status**
```javascript
// If game status is wrong, update:
status: "pending"
```

---

## **🧪 Test Steps:**

1. **Run Payment Debug Helper**
   - Navigate to `PaymentDebugHelper`
   - Click "Test Payment Flow"
   - Check console for exact error

2. **Check Firebase Console**
   - Verify player document exists
   - Verify balance is correct number
   - Verify game is pending

3. **Test Payment in App**
   - Try purchasing 1 card
   - Monitor console logs
   - Check specific error message

---

## **📱 Common Error Solutions:**

| Error Message | Cause | Solution |
|-------------|--------|----------|
| "Player not found" | Player doc missing | Create player document |
| "Insufficient balance" | Not enough funds | Add balance field |
| "Game not pending" | Game started | Join different game |
| "Permission denied" | Firebase rules | Update security rules |
| "Deadline exceeded" | Network timeout | Check connection |

---

## **🎯 If All Else Fails:**

### **Use the Debug Tools:**
1. `PaymentDebugHelper` - Tests exact payment flow
2. `QuickPaymentTest` - Simple payment test  
3. Console logs - Step-by-step debugging

### **Check These Files:**
- `lib/services/firebase_service.dart` - Payment logic
- `lib/models/player.dart` - Player balance handling
- `lib/screens/player/player_card_selection_screen.dart` - UI payment call

---

## **🚀 Expected Result:**

After following this guide, you should see:
```
✅ Payment flow test successful
✅ All debug checks passed
✅ Payment completes without exceptions
```

**The payment exception should be completely resolved!** 🎉
