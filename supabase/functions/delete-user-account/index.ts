import { serve } from "https://deno.land/std@0.220.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-posthog-distinct-id, x-posthog-session-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

console.log("Delete User Account function loaded")

// MARK: - PostHog
//
// Account deletion is the one churn event that cannot be captured client-side.
// By the time it succeeds the app has torn down its session and called
// PostHogSDK.reset(), so anything the client fired would either be lost in the
// flush or attributed to the wrong person. The server is the only participant
// still alive at the end, so it reports the outcome.
//
// Keys come from the function's environment (`supabase secrets set`), never
// from source.
const POSTHOG_PROJECT_TOKEN = Deno.env.get('POSTHOG_PROJECT_TOKEN')
const POSTHOG_HOST = Deno.env.get('POSTHOG_HOST') ?? 'https://us.i.posthog.com'

/**
 * Send one event to PostHog's capture endpoint.
 *
 * Deliberately swallows every failure. This function's job is to delete an
 * account; an analytics outage, a missing secret or a network blip must never
 * turn a successful deletion into a 500 the user sees — and must never leave
 * the caller thinking their data survived when it did not.
 *
 * `distinctId` should be the value the client sent in X-POSTHOG-DISTINCT-ID.
 * Falling back to the Supabase user id is a last resort and is marked as such
 * in the properties: Postgres returns lowercase UUIDs while the iOS client
 * identifies with Swift's uppercase `uuidString`, so the fallback lands on a
 * different person and the event will not join to that user's history.
 */
async function capturePostHog(
  event: string,
  distinctId: string,
  properties: Record<string, unknown>,
  sessionId?: string | null,
): Promise<void> {
  if (!POSTHOG_PROJECT_TOKEN) {
    console.warn('POSTHOG_PROJECT_TOKEN not set — skipping capture of', event)
    return
  }

  try {
    const response = await fetch(`${POSTHOG_HOST}/i/v0/e/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: POSTHOG_PROJECT_TOKEN,
        event,
        distinct_id: distinctId,
        properties: {
          ...properties,
          // Matches the super-property the iOS client registers at launch, so
          // these events survive the same `environment = "prod"` filter every
          // existing insight already applies.
          environment: 'prod',
          $lib: 'supabase-edge-function',
          // Stitches the event into the client's session replay when the
          // client supplied one.
          ...(sessionId ? { $session_id: sessionId } : {}),
        },
        timestamp: new Date().toISOString(),
      }),
    })

    if (!response.ok) {
      console.error(`PostHog capture of ${event} returned ${response.status}`)
    } else {
      console.log(`📊 PostHog: captured ${event}`)
    }
  } catch (phError) {
    console.error(`PostHog capture of ${event} failed:`, phError)
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Read outside the try so the outermost catch can still attribute a failure
  // to the right person.
  const phDistinctId = req.headers.get('x-posthog-distinct-id')
  const phSessionId = req.headers.get('x-posthog-session-id')

  try {
    console.log(`Processing ${req.method} request for account deletion`)

    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Method not allowed. Use POST.',
          deletedUserId: null,
          error: 'Method not allowed. Use POST.'
        }),
        {
          status: 405,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Get the authorization header
    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      console.error('No authorization header provided')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Missing authorization header',
          deletedUserId: null,
          error: 'Missing authorization header'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Extract JWT token
    const jwt = authHeader.replace('Bearer ', '')
    console.log(`Processing deletion request with JWT: ${jwt.substring(0, 20)}...`)
    
    // Import Supabase client dynamically
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
    
    // Create Supabase admin client for deletion operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Create regular client to verify the user's JWT token
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Verify the JWT token is valid and get user info
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser(jwt)
    
    if (userError || !user) {
      console.error('Invalid JWT token:', userError?.message)
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Invalid or expired token',
          deletedUserId: null,
          error: 'Invalid or expired token'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const userId = user.id
    console.log(`Verified user for deletion: ${userId} (${user.email})`)

    // Begin comprehensive user data deletion
    console.log('Starting comprehensive user data deletion...')

    // The client's distinct ID if it sent one, else the raw user id — see the
    // caveat on capturePostHog about the two not being interchangeable.
    const distinctId = phDistinctId ?? userId

    // Steps 1-8 log their errors and carry on by design (a missing optional
    // table must not abort the deletion), which means a partial wipe currently
    // returns a 200 and looks identical to a clean one. Collecting the names
    // makes that difference visible.
    const tablesWithErrors: string[] = []
    let currentStep = 'question_completions'

    try {
      // Step 1: Delete user question completions
      console.log('Deleting user question completions...')
      const { error: completionsError } = await supabaseAdmin
        .from('user_question_completions')
        .delete()
        .eq('user_id', userId)
      
      if (completionsError) {
        console.error('Error deleting question completions:', completionsError)
        tablesWithErrors.push('user_question_completions')
      } else {
        console.log('✅ Question completions deleted')
      }

      // Step 2: Delete daily question sets
      currentStep = 'daily_question_sets'
      console.log('Deleting daily question sets...')
      const { error: questionSetsError } = await supabaseAdmin
        .from('daily_question_sets')
        .delete()
        .eq('user_id', userId)
      
      if (questionSetsError) {
        console.error('Error deleting daily question sets:', questionSetsError)
        tablesWithErrors.push('daily_question_sets')
      } else {
        console.log('✅ Daily question sets deleted')
      }

      // Step 3: Delete daily practice sessions
      currentStep = 'daily_practice_sessions'
      console.log('Deleting daily practice sessions...')
      const { error: practiceSessionsError } = await supabaseAdmin
        .from('user_daily_practice_sessions')
        .delete()
        .eq('user_id', userId)
      
      if (practiceSessionsError) {
        console.error('Error deleting daily practice sessions:', practiceSessionsError)
        tablesWithErrors.push('user_daily_practice_sessions')
      } else {
        console.log('✅ Daily practice sessions deleted')
      }

      // Step 4: Delete daily practice streaks
      currentStep = 'daily_practice_streaks'
      console.log('Deleting daily practice streaks...')
      const { error: streaksError } = await supabaseAdmin
        .from('user_daily_practice_streaks')
        .delete()
        .eq('user_id', userId)
      
      if (streaksError) {
        console.error('Error deleting practice streaks:', streaksError)
        tablesWithErrors.push('user_daily_practice_streaks')
      } else {
        console.log('✅ Daily practice streaks deleted')
      }

      // Step 5: Delete practice progress (scenarios/games)
      currentStep = 'practice_progress'
      console.log('Deleting practice progress...')
      const { error: progressError } = await supabaseAdmin
        .from('user_practice_progress')
        .delete()
        .eq('user_id', userId)
      
      if (progressError) {
        console.error('Error deleting practice progress:', progressError)
        tablesWithErrors.push('user_practice_progress')
      } else {
        console.log('✅ Practice progress deleted')
      }

      // Step 6: Delete lesson progress
      currentStep = 'lesson_progress'
      console.log('Deleting lesson progress...')
      const { error: lessonProgressError } = await supabaseAdmin
        .from('user_lesson_progress')
        .delete()
        .eq('user_id', userId)
      
      if (lessonProgressError) {
        console.error('Error deleting lesson progress:', lessonProgressError)
        tablesWithErrors.push('user_lesson_progress')
      } else {
        console.log('✅ Lesson progress deleted')
      }

      // Step 7: Delete approach logs (if exists)
      currentStep = 'approach_logs'
      console.log('Deleting approach logs...')
      const { error: approachLogsError } = await supabaseAdmin
        .from('approach_logs')
        .delete()
        .eq('user_id', userId)
      
      if (approachLogsError && !approachLogsError.message.includes('does not exist')) {
        console.error('Error deleting approach logs:', approachLogsError)
        tablesWithErrors.push('approach_logs')
      } else {
        console.log('✅ Approach logs deleted (if table exists)')
      }

      // Step 8: Delete user profiles (check both id and user_id columns)
      currentStep = 'user_profiles'
      console.log('Deleting user profiles...')
      
      // Try deleting with 'id' column first (common pattern)
      const { error: profilesError1 } = await supabaseAdmin
        .from('user_profiles')
        .delete()
        .eq('id', userId)
      
      // Try deleting with 'user_id' column as backup
      const { error: profilesError2 } = await supabaseAdmin
        .from('user_profiles')
        .delete()
        .eq('user_id', userId)
      
      if (profilesError1 && profilesError2 &&
          !profilesError1.message.includes('does not exist') &&
          !profilesError2.message.includes('does not exist')) {
        console.error('Error deleting user profiles:', profilesError1, profilesError2)
        tablesWithErrors.push('user_profiles')
      } else {
        console.log('✅ User profiles deleted (if table exists)')
      }

      console.log('All user data successfully deleted from database tables')

      // Step 9: Delete the auth user account (THIS MUST BE LAST)
      currentStep = 'auth_user'
      console.log('Deleting auth user account...')
      const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(userId)
      
      if (deleteUserError) {
        console.error('Critical error deleting auth user:', deleteUserError)
        throw new Error(`Failed to delete auth user: ${deleteUserError.message}`)
      }

      console.log('✅ Auth user account deleted successfully')

      // The definitive churn event. Awaited rather than fired-and-forgotten:
      // Deno tears the isolate down once the response is returned, so an
      // un-awaited fetch would be cancelled mid-flight and the event lost.
      await capturePostHog(
        'account_deletion_completed',
        distinctId,
        {
          deleted_user_id: userId,
          tables_with_errors: tablesWithErrors,
          had_partial_errors: tablesWithErrors.length > 0,
          used_fallback_distinct_id: phDistinctId === null,
        },
        phSessionId,
      )

      // Success response - matches your Swift AccountDeletionResponse model perfectly
      console.log(`🎉 Account deletion completed successfully for user: ${userId}`)

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Account and all associated data deleted successfully',
          deletedUserId: userId,
          error: null
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )

    } catch (deletionError) {
      console.error('Critical error during data deletion process:', deletionError)

      // The state worth catching here is `failed_step === 'auth_user'`: Steps
      // 1-8 have already destroyed the user's content and only the auth
      // account survives, leaving an orphaned login with nothing behind it.
      // Until now that outcome existed solely in the Deno console logs.
      await capturePostHog(
        'account_deletion_failed',
        distinctId,
        {
          deleted_user_id: userId,
          failed_step: currentStep,
          tables_with_errors: tablesWithErrors,
          error_message: deletionError instanceof Error
            ? deletionError.message
            : String(deletionError),
          used_fallback_distinct_id: phDistinctId === null,
        },
        phSessionId,
      )

      return new Response(
        JSON.stringify({
          success: false,
          message: `Account deletion failed: ${deletionError.message}`,
          deletedUserId: null,
          error: deletionError.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

  } catch (error) {
    console.error('Unexpected error in delete-user-account function:', error)

    // Reached before the user is resolved (bad JWT, client import failure), so
    // there is no user id to fall back to. Only reportable when the client
    // supplied its distinct ID — which is the case for every real caller.
    if (phDistinctId) {
      await capturePostHog(
        'account_deletion_failed',
        phDistinctId,
        {
          failed_step: 'request_setup',
          error_message: error instanceof Error ? error.message : String(error),
          used_fallback_distinct_id: false,
        },
        phSessionId,
      )
    }

    return new Response(
      JSON.stringify({
        success: false,
        message: 'Internal server error during account deletion',
        deletedUserId: null,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
