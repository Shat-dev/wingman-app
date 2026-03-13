# Deployment Configuration for Supabase Edge Function

## To deploy this function to your Supabase project:

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link to your project:
```bash
supabase link --project-ref bnckmgnysfliiypvxxii
```

4. Deploy the function:
```bash
supabase functions deploy delete-user-account
```

## Environment Variables Required:
- SUPABASE_URL: Your Supabase project URL
- SUPABASE_SERVICE_ROLE_KEY: Your service role key (not anon key)

These are automatically available in Edge Functions.

## Function URL:
After deployment, the function will be available at:
https://YOUR_PROJECT_ID.supabase.co/functions/v1/delete-user-account

## Testing:
You can test the function using curl:
```bash
curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/delete-user-account \
  -H "Authorization: Bearer YOUR_USER_JWT_TOKEN" \
  -H "Content-Type: application/json"
```
