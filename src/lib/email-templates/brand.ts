// Shared SetGoals brand styling for auth emails.
// Colors mirror the app's sage design tokens (src/styles.css), converted to
// hex for email clients. Body background stays white per email guidelines.

export const brand = {
  main: {
    backgroundColor: '#ffffff',
    fontFamily: "'Albert Sans', 'Helvetica Neue', Arial, sans-serif",
  },
  container: {
    backgroundColor: '#f2f5ef', // sage-100
    borderRadius: '16px',
    padding: '32px 28px',
    margin: '24px auto',
    maxWidth: '520px',
  },
  wordmark: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
    color: '#566955', // sage-700
    letterSpacing: '0.5px',
    margin: '0 0 24px',
  },
  h1: {
    fontSize: '22px',
    fontWeight: 'bold' as const,
    color: '#263126', // sage-900
    margin: '0 0 20px',
  },
  text: {
    fontSize: '14px',
    color: '#4a5548',
    lineHeight: '1.6',
    margin: '0 0 25px',
  },
  link: { color: '#566955', textDecoration: 'underline' },
  button: {
    backgroundColor: '#566955', // sage-700
    color: '#ffffff',
    fontSize: '14px',
    fontWeight: 'bold' as const,
    borderRadius: '9999px',
    padding: '12px 28px',
    textDecoration: 'none',
  },
  code: {
    fontFamily: 'Courier, monospace',
    fontSize: '24px',
    fontWeight: 'bold' as const,
    color: '#263126',
    letterSpacing: '4px',
    margin: '0 0 30px',
  },
  footer: { fontSize: '12px', color: '#879884', margin: '30px 0 0' }, // sage-500
}

// Rendered as a text child, which React may HTML-escape: keep this CSS free of >, &, and quotes.
export const darkModeCss = `
  @media (prefers-color-scheme: dark) {
    .dm-btn { background-color: #879884 !important; color: #263126 !important; }
  }
  [data-ogsc] .dm-btn { background-color: #879884 !important; color: #263126 !important; }
  [data-ogsb] .dm-btn { background-color: #879884 !important; color: #263126 !important; }
`
