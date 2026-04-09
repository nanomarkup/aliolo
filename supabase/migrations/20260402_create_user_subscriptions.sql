-- user_subscriptions table for cross-platform billing (Android + Web)
CREATE TABLE public.user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'inactive', -- 'active', 'inactive', 'expired', 'canceled'
  provider TEXT NOT NULL, -- 'google_play', 'stripe', 'system'
  expiry_date TIMESTAMPTZ,
  purchase_token TEXT, -- Token from Google or Stripe subscription ID
  order_id TEXT, -- Order ID from provider
  product_id TEXT, -- The subscription SKU/Price ID
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policies: Users can read their own subscription
CREATE POLICY "Users can view own subscription" 
ON public.user_subscriptions FOR SELECT 
USING (auth.uid() = user_id);

-- System functions will handle updates, but we allow service_role to do everything
CREATE POLICY "Service role full access" 
ON public.user_subscriptions FOR ALL 
TO service_role 
USING (true);
