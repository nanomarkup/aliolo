-- Fix leaderboard badges by allowing everyone to see basic subscription status
-- This is safe as long as we don't expose purchase_token or order_id

DROP POLICY IF EXISTS "Users can view own subscription" ON public.user_subscriptions;

CREATE POLICY "Public can view subscription status" 
ON public.user_subscriptions FOR SELECT 
USING (true);

-- Optional: If performance is an issue, add is_premium to profiles
-- ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
