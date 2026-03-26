# Firestore Security Rules & Indexes Guide

## 📋 Overview

This guide explains the Firestore security rules and indexes for HeatBubble app.

## 🔐 Security Rules

### Files Created
- `firestore.rules` - Firestore database security rules
- `storage.rules` - Firebase Storage security rules
- `firestore.indexes.json` - Database indexes for query optimization

### Rule Philosophy

**Core Principle:** Users can only access their own data.

```
✅ Users CAN:
- Read their own profile
- Write their own profile
- Read their own temperature readings
- Create new temperature readings
- Delete their own readings
- Read their own subscription status
- Upload files to their own storage folder

❌ Users CANNOT:
- Access other users' data
- Modify subscription status (backend only)
- Update existing readings (immutable)
- Access files outside their folder
```

---

## 📁 Firestore Rules Breakdown

### 1. Users Collection (`/users/{userId}`)

**Purpose:** Store user profile data

**Rules:**
```javascript
allow read: if isOwner(userId);
allow create: if isOwner(userId) && isValidUser();
allow update: if isOwner(userId) && isValidUser();
allow delete: if isOwner(userId);
```

**Data Structure:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Validation:**
- Must be signed in
- Must be the owner (userId matches auth.uid)
- Must include `updatedAt` timestamp
- `updatedAt` must be server timestamp

---

### 2. Readings Collection (`/readings/{readingId}`)

**Purpose:** Store temperature readings

**Rules:**
```javascript
allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
allow create: if isValidReading();
allow update: if false; // Immutable
allow delete: if isSignedIn() && resource.data.userId == request.auth.uid;
```

**Data Structure:**
```json
{
  "userId": "user123",
  "temperature": 36.5,
  "rawTemp": 36.2,
  "timestamp": "2024-01-01T12:00:00Z",
  "createdAt": "2024-01-01T12:00:00Z"
}
```

**Validation:**
- Must be signed in
- `userId` must match authenticated user
- `temperature` and `rawTemp` must be numbers
- `timestamp` must be a timestamp
- `createdAt` must be server timestamp
- Readings are immutable (cannot be updated)

---

### 3. Subscriptions Collection (`/subscriptions/{userId}`)

**Purpose:** Store subscription status

**Rules:**
```javascript
allow read: if isOwner(userId);
allow write: if false; // Backend only
```

**Data Structure:**
```json
{
  "userId": "user123",
  "isPremium": true,
  "purchaseId": "purchase_123",
  "productId": "premium_onetime",
  "expiryDate": null,
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Security:**
- Users can READ their own subscription
- Only backend can WRITE (prevents fraud)
- If you want app to write (less secure):
  - Uncomment the alternative rule in `firestore.rules`
  - Add proper validation

---

## 📊 Firestore Indexes

### Why Indexes?

Indexes improve query performance for complex queries.

### Index 1: User Readings by Timestamp (Descending)

**Purpose:** Get user's recent readings efficiently

**Query:**
```dart
readings
  .where('userId', isEqualTo: userId)
  .orderBy('timestamp', descending: true)
  .limit(100)
```

**Index:**
```json
{
  "collectionGroup": "readings",
  "fields": [
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

---

### Index 2: User Readings by Creation Date

**Purpose:** Get readings by creation order

**Query:**
```dart
readings
  .where('userId', isEqualTo: userId)
  .orderBy('createdAt', descending: true)
```

**Index:**
```json
{
  "collectionGroup": "readings",
  "fields": [
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

---

### Index 3: Users by Email and Creation Date

**Purpose:** Admin queries for user management

**Query:**
```dart
users
  .where('email', isEqualTo: email)
  .orderBy('createdAt', descending: true)
```

**Index:**
```json
{
  "collectionGroup": "users",
  "fields": [
    {"fieldPath": "email", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

---

## 🗄️ Storage Rules

### File Structure
```
users/
├── {userId}/
│   ├── profile.jpg          (max 5MB)
│   ├── charts/
│   │   ├── chart_123.png    (max 2MB)
│   │   └── chart_456.png
│   └── exports/
│       ├── data.csv         (max 10MB)
│       └── data.json
```

### Rules Breakdown

**Profile Pictures:**
```javascript
match /users/{userId}/profile.jpg {
  allow read: if isOwner(userId);
  allow write: if isOwner(userId) && 
                  isImage() && 
                  isValidSize(5); // 5MB max
}
```

**Charts:**
```javascript
match /users/{userId}/charts/{chartId} {
  allow read: if isOwner(userId);
  allow write: if isOwner(userId) && 
                  isImage() && 
                  isValidSize(2); // 2MB max
}
```

**Exports:**
```javascript
match /users/{userId}/exports/{fileName} {
  allow read: if isOwner(userId);
  allow write: if isOwner(userId) && 
                  isValidSize(10); // 10MB max
}
```

---

## 🚀 Deployment

### Quick Deploy

**Windows:**
```powershell
.\deploy_firestore_rules.ps1
```

**Linux/Mac:**
```bash
chmod +x deploy_firestore_rules.sh
./deploy_firestore_rules.sh
```

### Manual Deploy

**1. Login to Firebase:**
```bash
firebase login
```

**2. Select Project:**
```bash
firebase use <project-id>
```

**3. Deploy Rules:**
```bash
firebase deploy --only firestore:rules
```

**4. Deploy Indexes:**
```bash
firebase deploy --only firestore:indexes
```

**5. Deploy Storage Rules:**
```bash
firebase deploy --only storage
```

**6. Deploy All at Once:**
```bash
firebase deploy --only firestore,storage
```

---

## 🧪 Testing Rules

### Test in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Firestore → Rules
4. Click "Rules Playground"
5. Test different scenarios

### Test Scenarios

**Scenario 1: User reads own data**
```
Location: /users/user123
Auth: user123
Operation: get
Expected: ✅ Allow
```

**Scenario 2: User reads other's data**
```
Location: /users/user456
Auth: user123
Operation: get
Expected: ❌ Deny
```

**Scenario 3: User creates reading**
```
Location: /readings/reading123
Auth: user123
Data: {userId: "user123", temperature: 36.5, ...}
Operation: create
Expected: ✅ Allow
```

**Scenario 4: User updates reading**
```
Location: /readings/reading123
Auth: user123
Operation: update
Expected: ❌ Deny (immutable)
```

---

## 🔍 Monitoring

### Check Rule Usage

1. Go to Firebase Console
2. Firestore → Usage
3. Check "Reads" and "Writes"
4. Monitor for unusual patterns

### Check Index Usage

1. Go to Firebase Console
2. Firestore → Indexes
3. Check "Status" column
4. Look for "Building" or "Error" states

### Common Issues

**Issue: "Missing index" error**
```
Solution: Deploy indexes with:
firebase deploy --only firestore:indexes
```

**Issue: "Permission denied" error**
```
Solution: Check rules allow the operation:
1. Verify user is authenticated
2. Verify userId matches auth.uid
3. Check data validation rules
```

**Issue: Slow queries**
```
Solution: Add appropriate indexes:
1. Check Firestore logs for index suggestions
2. Add to firestore.indexes.json
3. Deploy indexes
```

---

## 📈 Performance Tips

### 1. Use Indexes
✅ Always create indexes for compound queries
✅ Deploy indexes before running queries
✅ Monitor index build status

### 2. Limit Query Results
✅ Use `.limit()` to cap results
✅ Paginate large result sets
✅ Don't fetch all data at once

### 3. Optimize Rules
✅ Keep rules simple
✅ Avoid complex calculations
✅ Cache rule results when possible

### 4. Batch Operations
✅ Use batch writes for multiple operations
✅ Reduces rule evaluations
✅ Improves performance

---

## 🔒 Security Best Practices

### 1. Never Trust Client
❌ Don't rely on client-side validation
✅ Always validate in security rules
✅ Assume clients are malicious

### 2. Principle of Least Privilege
❌ Don't give more access than needed
✅ Only allow what's necessary
✅ Deny by default

### 3. Validate All Data
✅ Check data types
✅ Validate required fields
✅ Use server timestamps

### 4. Protect Sensitive Data
✅ Subscription status (backend only)
✅ Payment information (never store)
✅ Personal data (encrypt if needed)

---

## 📝 Maintenance

### Regular Tasks

**Weekly:**
- [ ] Check Firestore usage metrics
- [ ] Review error logs
- [ ] Monitor index status

**Monthly:**
- [ ] Review security rules
- [ ] Optimize slow queries
- [ ] Clean up unused indexes

**Quarterly:**
- [ ] Security audit
- [ ] Performance review
- [ ] Cost optimization

---

## 🆘 Troubleshooting

### Problem: Rules not updating

**Solution:**
```bash
# Force deploy
firebase deploy --only firestore:rules --force

# Clear cache
firebase deploy --only firestore:rules --debug
```

### Problem: Indexes not building

**Solution:**
1. Check Firebase Console for errors
2. Verify index definition is valid
3. Wait (can take several minutes)
4. Redeploy if stuck

### Problem: Permission denied errors

**Solution:**
1. Check user is authenticated
2. Verify userId matches
3. Test in Rules Playground
4. Check data validation

---

## 📚 Resources

- [Firestore Security Rules Docs](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Security Rules Docs](https://firebase.google.com/docs/storage/security)
- [Firestore Indexes Docs](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Rules Playground](https://console.firebase.google.com/)

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] Review all security rules
- [ ] Test rules in playground
- [ ] Deploy indexes first
- [ ] Deploy rules second
- [ ] Test from app
- [ ] Monitor for errors
- [ ] Verify performance
- [ ] Document any changes

---

**Status:** ✅ Ready for Deployment

**Last Updated:** March 25, 2026

**Version:** 1.0.0
