#!/bin/bash

# Deploy Firestore Rules and Indexes to Firebase
# This script deploys security rules and database indexes

echo "═══════════════════════════════════════════════════════"
echo "🔥 Deploying Firestore Rules and Indexes"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "📦 Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Check if user is logged in
echo "🔐 Checking Firebase authentication..."
firebase projects:list > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Not logged in to Firebase"
    echo "🔑 Logging in..."
    firebase login
    if [ $? -ne 0 ]; then
        echo "❌ Login failed"
        exit 1
    fi
fi

echo "✅ Authenticated"
echo ""

# List available projects
echo "📋 Available Firebase projects:"
firebase projects:list
echo ""

# Ask user to confirm project
echo "⚠️  Make sure you're deploying to the correct project!"
echo "   Check the project ID in .firebaserc or run 'firebase use' to select"
echo ""
read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "📤 Deploying Firestore Rules..."
echo "═══════════════════════════════════════════════════════"
firebase deploy --only firestore:rules

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Firestore rules"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "📤 Deploying Firestore Indexes..."
echo "═══════════════════════════════════════════════════════"
firebase deploy --only firestore:indexes

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Firestore indexes"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "📤 Deploying Storage Rules..."
echo "═══════════════════════════════════════════════════════"
firebase deploy --only storage

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Storage rules"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ Deployment Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📊 Verify deployment:"
echo "   1. Go to Firebase Console: https://console.firebase.google.com/"
echo "   2. Select your project"
echo "   3. Check Firestore → Rules"
echo "   4. Check Firestore → Indexes"
echo "   5. Check Storage → Rules"
echo ""
echo "🧪 Test your rules:"
echo "   1. Try reading/writing data from your app"
echo "   2. Check that unauthorized access is blocked"
echo "   3. Verify indexes are being used (check Firestore logs)"
echo ""
echo "═══════════════════════════════════════════════════════"
