const clientToken = import.meta.env.VITE_PAYMENTS_CLIENT_TOKEN;

export function PaymentTestModeBanner() {
  if (!clientToken) {
    return (
      <div className="w-full border-b border-destructive/30 bg-destructive/10 px-4 py-2 text-center text-xs text-destructive">
        Production checkout is not configured yet.
      </div>
    );
  }
  if (clientToken.startsWith("pk_test_")) {
    return (
      <div className="w-full rounded-xl bg-amber-100 px-3 py-2 text-center text-[11px] text-amber-900">
        Test mode — no real money is charged. Use card 4242 4242 4242 4242.
      </div>
    );
  }
  return null;
}
