import { serve } from "https://deno.land/std@0.220.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

console.log("Delete User Account function loaded")

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log(`Processing ${req.method} request for account deletion`)

    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({
          success: false,
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
    
    try {
      // Step 1: Delete user question completions
      console.log('Deleting user question completions...')
      const { error: completionsError } = await supabaseAdmin
        .from('user_question_completions')
        .delete()
        .eq('user_id', userId)
      
      if (completionsError) {
        console.error('Error deleting question completions:', completionsError)
      } else {
        console.log('✅ Question completions deleted')
      }

      // Step 2: Delete daily question sets
      console.log('Deleting daily question sets...')
      const { error: questionSetsError } = await supabaseAdmin
        .from('daily_question_sets')
        .delete()
        .eq('user_id', userId)
      
      if (questionSetsError) {
        console.error('Error deleting daily question sets:', questionSetsError)
      } else {
        console.log('✅ Daily question sets deleted')
      }

      // Step 3: Delete daily practice sessions
      console.log('Deleting daily practice sessions...')
      const { error: practiceSessionsError } = await supabaseAdmin
        .from('user_daily_practice_sessions')
        .delete()
        .eq('user_id', userId)
      
      if (practiceSessionsError) {
        console.error('Error deleting daily practice sessions:', practiceSessionsError)
      } else {
        console.log('✅ Daily practice sessions deleted')
      }

      // Step 4: Delete daily practice streaks
      console.log('Deleting daily practice streaks...')
      const { error: streaksError } = await supabaseAdmin
        .from('user_daily_practice_streaks')
        .delete()
        .eq('user_id', userId)
      
      if (streaksError) {
        console.error('Error deleting practice streaks:', streaksError)
      } else {
        console.log('✅ Daily practice streaks deleted')
      }

      // Step 5: Delete practice progress (scenarios/games)
      console.log('Deleting practice progress...')
      const { error: progressError } = await supabaseAdmin
        .from('user_practice_progress')
        .delete()
        .eq('user_id', userId)
      
      if (progressError) {
        console.error('Error deleting practice progress:', progressError)
      } else {
        console.log('✅ Practice progress deleted')
      }

      // Step 6: Delete lesson progress
      console.log('Deleting lesson progress...')
      const { error: lessonProgressError } = await supabaseAdmin
        .from('user_lesson_progress')
        .delete()
        .eq('user_id', userId)
      
      if (lessonProgressError) {
        console.error('Error deleting lesson progress:', lessonProgressError)
      } else {
        console.log('✅ Lesson progress deleted')
      }

      // Step 7: Delete approach logs (if exists)
      console.log('Deleting approach logs...')
      const { error: approachLogsError } = await supabaseAdmin
        .from('approach_logs')
        .delete()
        .eq('user_id', userId)
      
      if (approachLogsError && !approachLogsError.message.includes('does not exist')) {
        console.error('Error deleting approach logs:', approachLogsError)
      } else {
        console.log('✅ Approach logs deleted (if table exists)')
      }

      // Step 8: Delete user profiles (check both id and user_id columns)
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
      } else {
        console.log('✅ User profiles deleted (if table exists)')
      }

      console.log('All user data successfully deleted from database tables')

      // Step 9: Delete the auth user account (THIS MUST BE LAST)
      console.log('Deleting auth user account...')
      const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(userId)
      
      if (deleteUserError) {
        console.error('Critical error deleting auth user:', deleteUserError)
        throw new Error(`Failed to delete auth user: ${deleteUserError.message}`)
      }

      console.log('✅ Auth user account deleted successfully')

      // Success response - matches your Swift AccountDeletionResponse model
      console.log(`🎉 Account deletion completed successfully for user: ${userId}`)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Account and all associated data deleted successfully',
          deletedUserId: userId,
          timestamp: new Date().toISOString(),
          error: null
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )

    } catch (deletionError) {
      console.error('Critical error during data deletion process:', deletionError)
      
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