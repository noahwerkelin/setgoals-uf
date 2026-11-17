import * as React from 'react'
import { createAuthEmailHandler } from '@lovable.dev/email-js'
import { createFileRoute } from '@tanstack/react-router'
import { SignupEmail } from '@/lib/email-templates/signup'
import { InviteEmail } from '@/lib/email-templates/invite'
import { MagicLinkEmail } from '@/lib/email-templates/magic-link'
import { RecoveryEmail } from '@/lib/email-templates/recovery'
import { EmailChangeEmail } from '@/lib/email-templates/email-change'
import { ReauthenticationEmail } from '@/lib/email-templates/reauthentication'

// Configuration
const SITE_NAME = "SetGoals UF"
const SENDER_DOMAIN = "notify.setgoals.se"
const ROOT_DOMAIN = "setgoals.se"
const FROM_DOMAIN = "setgoals.se"
const SITE_URL = `https://${ROOT_DOMAIN}`

// The SDK handler owns verification, dispatch, and retry semantics; this file
// owns only the email decisions: subjects, templates, and per-type props.
export const Route = createFileRoute("/lovable/email/auth/webhook")({
  server: {
    handlers: {
      POST: ({ request }) => {
        const handler = createAuthEmailHandler({
          apiKey: process.env['LOVABLE_API_KEY']!,
          from: { name: SITE_NAME, address: `noreply@${FROM_DOMAIN}` },
          senderDomain: SENDER_DOMAIN,
          sendUrl: process.env['LOVABLE_SEND_URL'],
          emails: {
            signup: {
              subject: 'Confirm your email',
              render: (data) =>
                React.createElement(SignupEmail, {
                  siteName: SITE_NAME,
                  siteUrl: SITE_URL,
                  recipient: data.email,
                  confirmationUrl: data.url,
                }),
            },
            invite: {
              subject: "You've been invited",
              render: (data) =>
                React.createElement(InviteEmail, {
                  siteName: SITE_NAME,
                  siteUrl: SITE_URL,
                  confirmationUrl: data.url,
                }),
            },
            magiclink: {
              subject: 'Your login link',
              render: (data) =>
                React.createElement(MagicLinkEmail, {
                  siteName: SITE_NAME,
                  confirmationUrl: data.url,
                }),
            },
            recovery: {
              subject: 'Reset your password',
              render: (data) => {
                // AuthEmailHookData exposes the Auth verification URL, not a
                // token_hash field. Its `token` field is the raw email OTP and
                // must never be used as a token_hash fallback.
                let verificationUrl: URL
                try {
                  verificationUrl = new URL(data.url)
                } catch {
                  // Do not include the URL or any token in errors/logs.
                  throw new Error('Recovery email requires a valid Auth verification URL')
                }

                // Supabase's action-link contract is:
                // /auth/v1/verify?type=recovery&token={hashed_token}.
                // A PKCE callback's `code` or verifier is not this token.
                const tokenHashes = verificationUrl.searchParams.getAll('token')
                const actionTypes = verificationUrl.searchParams.getAll('type')
                const tokenHash = tokenHashes[0]
                if (
                  data.action_type !== 'recovery' ||
                  verificationUrl.protocol !== 'https:' ||
                  verificationUrl.pathname !== '/auth/v1/verify' ||
                  actionTypes.length !== 1 ||
                  actionTypes[0] !== 'recovery' ||
                  tokenHashes.length !== 1 ||
                  !tokenHash ||
                  tokenHash.trim() !== tokenHash ||
                  tokenHash === data.token
                ) {
                  // The SDK catches render failures, returns 500 and retries;
                  // no email is sent with a missing or ambiguous recovery hash.
                  throw new Error('Recovery email requires an unambiguous recovery token hash')
                }

                const resetUrl = new URL('/reset-password', SITE_URL)
                resetUrl.searchParams.set('token_hash', tokenHash)
                resetUrl.searchParams.set('type', 'recovery')

                return React.createElement(RecoveryEmail, {
                  siteName: SITE_NAME,
                  confirmationUrl: resetUrl.toString(),
                })
              },
            },
            email_change: {
              subject: 'Confirm your new email',
              render: (data) =>
                React.createElement(EmailChangeEmail, {
                  siteName: SITE_NAME,
                  oldEmail: data.old_email ?? '',
                  email: data.email,
                  newEmail: data.new_email ?? '',
                  confirmationUrl: data.url,
                }),
            },
            reauthentication: {
              subject: 'Your verification code',
              render: (data) =>
                React.createElement(ReauthenticationEmail, { token: data.token ?? '' }),
            },
          },
        })
        return handler(request)
      },
    },
  },
})
