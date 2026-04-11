    # Account Deletion Implementation Guide

## 🚀 Deployment Instructions

### 1. Deploy the Supabase Edge Function

Navigate to your project root and run:

```bash
# Deploy the edge function
supabase functions deploy delete-user-account

# Verify deployment
supabase functions list
```

### 2. Set up Environment Variables

The function uses these environment variables (automatically available):
- `SUPABASE_URL`: Your project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key with admin privileges

### 3. Test the Function

Test with curl (replace with your actual values):

```bash
# Get a user JWT token first by signing in through your app
# Then test the deletion function
curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/delete-user-account \
  -H "Authorization: Bearer YOUR_USER_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

## 🏗️ Implementation Overview

### Backend (Supabase Edge Function)
- **Location**: `supabase/functions/delete-user-account/index.ts`
- **Security**: Uses service role key for admin operations
- **Process**: Deletes all user data then deletes auth account
- **Tables cleaned**: All user-related tables in correct order

### iOS App Integration
- **AuthManager**: Added `deleteAccount()` method with secure edge function call
- **SettingsSheet**: Updated with proper error handling and user feedback
- **Error Handling**: Comprehensive error types for different failure scenarios
- **Navigation**: Automatic redirect to login/onboarding after successful deletion

## 📊 Data Deletion Order

The function deletes data in this order to respect foreign key constraints:

1. `user_question_completions`
2. `daily_question_sets`
3. `user_daily_practice_sessions`
4. `user_daily_practice_streaks`
5. `user_practice_progress`
6. `user_lesson_progress`
7. `user_profiles` (if exists)
8. Auth user account (final step)

## ✅ Security Features

- **JWT Verification**: Edge function verifies user identity from JWT token
- **Admin Privileges**: Uses service role key for secure deletions
- **Data Integrity**: Deletes all related data before auth account
- **Error Recovery**: Comprehensive error handling and logging
- **CORS Support**: Proper CORS headers for web/mobile requests

## 🔧 Troubleshooting

### Common Issues

1. **Function not found**: Ensure function is deployed correctly
2. **Permission denied**: Verify service role key has admin privileges
3. **Network errors**: Check internet connection and Supabase status
4. **Invalid token**: User session may have expired

### Debug Logs

Enable debug mode in your app to see detailed logs:
- Edge function execution status
- Data deletion progress
- Error messages and stack traces
- Navigation flow after deletion

## 📱 User Experience Flow

1. User opens Settings → Taps "Delete Account"
2. Confirmation dialog appears
3. User confirms deletion
4. App calls AuthManager.deleteAccount()
5. Edge function deletes all data securely
6. App clears local data and updates auth state
7. User automatically redirected to login/onboarding
8. Account and all data permanently removed

The implementation follows security best practices and provides a smooth user experience with proper error handling.
