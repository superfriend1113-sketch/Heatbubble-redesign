# Firebase Deployment Commands - Quick Reference

## 🚀 Quick Deploy (Recommended)

### Windows
```powershell
.\deploy_firestore_rules.ps1
```

### Linux/Mac
```bash
chmod +x deploy_firestore_rules.sh
./deploy_firestore_rules.sh
```

---

## 📋 Manual Commands

### 1. Login to Firebase
```bash
firebase login
```

### 2. List Projects
```bash
firebase projects:list
```

### 3. Select Project
```bash
firebase use <project-id>

# Or interactively
firebase use
```

### 4. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 5. Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```

### 6. Deploy Storage Rules
```bash
firebase deploy --only storage
```

### 7. Deploy Everything
```bash
firebase deploy --only firestore,storage
```

---

## 🧪 Testing Commands

### Test Rules Locally
```bash
# Install emulator
firebase init emulators

# Start emulator
firebase emulators:start

# Test with emulator
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

### Validate Rules
```bash
# Check syntax
firebase deploy --only firestore:rules --dry-run
```

---

## 📊 Monitoring Commands

### View Firestore Usage
```bash
firebase firestore:usage
```

### View Indexes Status
```bash
firebase firestore:indexes
```

### View Logs
```bash
firebase functions:log
```

---

## 🔧 Troubleshooting Commands

### Force Deploy
```bash
firebase deploy --only firestore:rules --force
```

### Debug Deploy
```bash
firebase deploy --only firestore:rules --debug
```

### Clear Cache
```bash
firebase logout
firebase login
```

---

## 📁 File Structure

```
project/
├── firestore.rules              ← Firestore security rules
├── firestore.indexes.json       ← Database indexes
├── storage.rules                ← Storage security rules
├── firebase.json                ← Firebase configuration
├── deploy_firestore_rules.sh    ← Deployment script (Linux/Mac)
├── deploy_firestore_rules.ps1   ← Deployment script (Windows)
└── FIRESTORE_RULES_GUIDE.md     ← This guide
```

---

## ✅ Deployment Checklist

- [ ] Login: `firebase login`
- [ ] Select project: `firebase use <project-id>`
- [ ] Deploy indexes: `firebase deploy --only firestore:indexes`
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Deploy Storage rules: `firebase deploy --only storage`
- [ ] Verify in console
- [ ] Test from app

---

## 🎯 Common Workflows

### First Time Setup
```bash
# 1. Login
firebase login

# 2. Initialize (if not done)
firebase init firestore
firebase init storage

# 3. Deploy
firebase deploy --only firestore,storage
```

### Update Rules
```bash
# 1. Edit firestore.rules or storage.rules
# 2. Deploy
firebase deploy --only firestore:rules
# or
firebase deploy --only storage
```

### Add New Index
```bash
# 1. Edit firestore.indexes.json
# 2. Deploy
firebase deploy --only firestore:indexes
```

### Full Redeploy
```bash
firebase deploy --only firestore,storage --force
```

---

## 🔗 Quick Links

- [Firebase Console](https://console.firebase.google.com/)
- [Firestore Rules Docs](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Rules Docs](https://firebase.google.com/docs/storage/security)
- [CLI Reference](https://firebase.google.com/docs/cli)

---

**Pro Tip:** Use the automated scripts for consistent, error-free deployments!
