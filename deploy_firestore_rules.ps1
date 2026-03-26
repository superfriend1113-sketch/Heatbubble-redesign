# Deploy Firestore Rules and Indexes to Firebase (PowerShell)
# This script deploys security rules and database indexes

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔥 Deploying Firestore Rules and Indexes" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI not found!" -ForegroundColor Red
    Write-Host "📦 Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""

# Check if user is logged in
Write-Host "🔐 Checking Firebase authentication..." -ForegroundColor Yellow
firebase projects:list > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Firebase" -ForegroundColor Red
    Write-Host "🔑 Logging in..." -ForegroundColor Yellow
    firebase login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Login failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Authenticated" -ForegroundColor Green
Write-Host ""

# List available projects
Write-Host "📋 Available Firebase projects:" -ForegroundColor Yellow
firebase projects:list
Write-Host ""

# Ask user to confirm project
Write-Host "⚠️  Make sure you're deploying to the correct project!" -ForegroundColor Yellow
Write-Host "   Check the project ID in .firebaserc or run 'firebase use' to select" -ForegroundColor White
Write-Host ""
$confirmation = Read-Host "Continue with deployment? (y/n)"

if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📤 Deploying Firestore Rules..." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
firebase deploy --only firestore:rules

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Firestore rules" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📤 Deploying Firestore Indexes..." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
firebase deploy --only firestore:indexes

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Firestore indexes" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📤 Deploying Storage Rules..." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
firebase deploy --only storage

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Storage rules" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Verify deployment:" -ForegroundColor Yellow
Write-Host "   1. Go to Firebase Console: https://console.firebase.google.com/" -ForegroundColor White
Write-Host "   2. Select your project" -ForegroundColor White
Write-Host "   3. Check Firestore → Rules" -ForegroundColor White
Write-Host "   4. Check Firestore → Indexes" -ForegroundColor White
Write-Host "   5. Check Storage → Rules" -ForegroundColor White
Write-Host ""
Write-Host "🧪 Test your rules:" -ForegroundColor Yellow
Write-Host "   1. Try reading/writing data from your app" -ForegroundColor White
Write-Host "   2. Check that unauthorized access is blocked" -ForegroundColor White
Write-Host "   3. Verify indexes are being used (check Firestore logs)" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
