import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { purchaseToken, productId, orderId } = await req.json()
    
    // Auth check: get user from header
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    // IN A REAL SCENARIO:
    // 1. Authenticate with Google Play API using a Service Account Key
    // 2. verify the purchaseToken with Google
    // 3. check if expiry_date is in the future
    
    // For now, we simulate a successful verification:
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const expiryDate = new Date()
    expiryDate.setMonth(expiryDate.getMonth() + 1) // 1 month from now

    const { error: upsertError } = await adminClient
      .from('user_subscriptions')
      .upsert({
        user_id: user.id,
        status: 'active',
        provider: 'google_play',
        purchase_token: purchaseToken,
        order_id: orderId,
        product_id: productId,
        expiry_date: expiryDate.toISOString(),
        updated_at: new Date().toISOString(),
      })

    if (upsertError) throw upsertError

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
