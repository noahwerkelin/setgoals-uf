import { createFileRoute } from '@tanstack/react-router'
import { createClient } from '@supabase/supabase-js'

// Public health check: verifies real database connectivity and returns only
// a status and the check time. CORS is limited to setgoals.se.
const ALLOWED_ORIGIN = 'https://setgoals.se'

function corsHeaders(): HeadersInit {
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'no-store',
  }
}

export const Route = createFileRoute('/api/public/health')({
  server: {
    handlers: {
      GET: async () => {
        const checkedAt = new Date().toISOString()
        let ok = false
        try {
          const url = process.env['SUPABASE_URL'] ?? process.env['VITE_SUPABASE_URL']
          const key =
            process.env['SUPABASE_PUBLISHABLE_KEY'] ?? process.env['VITE_SUPABASE_PUBLISHABLE_KEY']
          if (url && key) {
            const supabase = createClient(url, key, {
              auth: { persistSession: false, autoRefreshToken: false },
            })
            // Real connectivity probe: a harmless read against a public table.
            const { error } = await supabase.from('profiles').select('id', { head: true, count: 'exact' }).limit(1)
            ok = !error
          }
        } catch {
          ok = false
        }
        return Response.json(
          { status: ok ? 'ok' : 'error', checked_at: checkedAt },
          { status: ok ? 200 : 503, headers: corsHeaders() },
        )
      },
      OPTIONS: async () => new Response(null, { status: 204, headers: corsHeaders() }),
    },
  },
})
