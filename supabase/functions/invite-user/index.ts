import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { 
      headers: { 
        'Access-Control-Allow-Origin': '*', 
        'Access-Control-Allow-Methods': 'POST', 
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' 
      } 
    })
  }

  try {
    const { email, senderId } = await req.json()
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // 1. Invite user
    const { data, error } = await supabaseAdmin.auth.admin.inviteUserByEmail(email)
    if (error) throw error

    const user = data.user
    if (!user) throw new Error('User creation failed')

    // 2. Create profile
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: user.id,
        email: email.toLowerCase(),
        username: email.split('@')[0],
        ui_language: 'en',
        main_pillar_id: 6,
        total_xp: 0,
        current_streak: 0,
        max_streak: 0,
        theme_mode: 'system',
        daily_goal_count: 20,
        next_daily_goal: 20,
        daily_completions: 0,
        sidebar_left: true,
        sound_enabled: true,
        auto_play_enabled: false,
        show_on_leaderboard: true,
        learn_session_size: 20,
        test_session_size: 10,
        options_count: 6,
        default_language: 'en'
      })
    if (profileError) throw profileError

    // 3. Create friendship request (Optional)
    if (senderId) {
      const { error: friendshipError } = await supabaseAdmin.from('user_friendships').insert({
        sender_id: senderId,
        receiver_id: user.id,
        status: 'pending'
      })
      if (friendshipError) throw friendshipError
    }

    return new Response(JSON.stringify({ data }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 400,
    })
  }
})
