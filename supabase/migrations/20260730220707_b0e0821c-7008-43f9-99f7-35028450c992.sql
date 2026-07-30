ALTER TABLE public.subscriptions RENAME COLUMN stripe_subscription_id TO provider_txn_id;
ALTER TABLE public.subscriptions RENAME COLUMN stripe_customer_id TO provider_account_id;
ALTER TABLE public.subscriptions ALTER COLUMN provider_account_id DROP NOT NULL;
ALTER TABLE public.subscriptions ALTER COLUMN provider_account_id SET DEFAULT '';
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS provider text NOT NULL DEFAULT 'apple';
CREATE INDEX IF NOT EXISTS idx_subscriptions_provider_txn ON public.subscriptions(provider_txn_id);