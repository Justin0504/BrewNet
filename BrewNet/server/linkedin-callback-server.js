/**
 * LinkedIn OAuth Callback Redirect Server
 * 
 * This server receives LinkedIn's OAuth callback and redirects to the app scheme.
 * 
 * Setup:
 * 1. Install dependencies: npm install express
 * 2. Run: node linkedin-callback-server.js
 * 3. Configure reverse proxy (nginx/cloudflare) to route:
 *    https://brewnet.app/auth/linkedin/callback -> http://localhost:3001/auth/linkedin/callback
 * 
 * Production deployment options:
 * - Vercel: Deploy as serverless function
 * - Railway/Render: Deploy as Node.js service
 * - AWS Lambda: Convert to serverless function
 * - DigitalOcean App Platform: Deploy as web service
 */

const express = require('express');
const app = express();

const PORT = process.env.PORT || 3001;
const APP_SCHEME = process.env.APP_SCHEME || 'brewnet';

// Middleware
app.use(express.json());

// LinkedIn OAuth Callback Endpoint
app.get('/auth/linkedin/callback', (req, res) => {
  try {
    const { code, state, error, error_description } = req.query;

    // Handle OAuth errors from LinkedIn
    if (error) {
      console.error('LinkedIn OAuth error:', error, error_description);
      // Redirect to app with error
      const errorRedirect = `${APP_SCHEME}://auth/linkedin?error=${encodeURIComponent(error)}&error_description=${encodeURIComponent(error_description || '')}`;
      return res.redirect(302, errorRedirect);
    }

    // Validate required parameters
    if (!code) {
      return res.status(400).send('Missing authorization code');
    }

    // Build app scheme redirect URL
    // Format: brewnet://auth/linkedin?code=XXX&state=YYY
    const params = new URLSearchParams();
    params.append('code', code);
    if (state) {
      params.append('state', state);
    }

    const appRedirectURL = `${APP_SCHEME}://auth/linkedin?${params.toString()}`;

    console.log(`[${new Date().toISOString()}] Redirecting to app: ${appRedirectURL}`);

    // 302 redirect to app scheme
    // ASWebAuthenticationSession will capture this and trigger the callback
    res.redirect(302, appRedirectURL);
  } catch (error) {
    console.error('Callback handler error:', error);
    res.status(500).json({
      error: 'Internal server error',
      detail: error.message
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'linkedin-callback-server' });
});

// Start server
app.listen(PORT, () => {
  console.log(`✅ LinkedIn Callback Server running on port ${PORT}`);
  console.log(`📍 Callback URL: http://localhost:${PORT}/auth/linkedin/callback`);
  console.log(`📱 App Scheme: ${APP_SCHEME}://auth/linkedin`);
  console.log(`\n⚠️  Configure reverse proxy to route:`);
  console.log(`   https://brewnet.app/auth/linkedin/callback -> http://localhost:${PORT}/auth/linkedin/callback`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

