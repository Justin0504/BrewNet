// Supabase Edge Function: LinkedIn OAuth Callback Redirect
// This function receives LinkedIn's OAuth callback and redirects to the app scheme
// 
// Deploy: supabase functions deploy linkedin-callback
// URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
//
// To use with custom domain (brewnet.app):
// 1. Configure custom domain in Supabase Dashboard
// 2. Set up reverse proxy to route /auth/linkedin/callback to this function

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const APP_SCHEME = "brewnet"

serve(async (req) => {
  // Only allow GET requests
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 })
  }

  try {
    // Parse query parameters
    const url = new URL(req.url)
    const code = url.searchParams.get("code")
    const state = url.searchParams.get("state")
    const error = url.searchParams.get("error")
    const errorDescription = url.searchParams.get("error_description")

    // Handle OAuth errors from LinkedIn
    if (error) {
      console.error("LinkedIn OAuth error:", error, errorDescription)
      // Redirect to app with error
      const errorRedirect = `${APP_SCHEME}://auth/linkedin?error=${encodeURIComponent(error)}&error_description=${encodeURIComponent(errorDescription || "")}`
      return Response.redirect(errorRedirect, 302)
    }

    // Validate required parameters
    if (!code) {
      return new Response("Missing authorization code", { status: 400 })
    }

    // Build app scheme redirect URL
    // Format: brewnet://auth/linkedin?code=XXX&state=YYY
    const params = new URLSearchParams()
    params.append("code", code)
    if (state) {
      params.append("state", state)
    }

    const appRedirectURL = `${APP_SCHEME}://auth/linkedin?${params.toString()}`

    console.log("Redirecting to app:", appRedirectURL)

    // 302 redirect to app scheme
    // ASWebAuthenticationSession will capture this and trigger the callback
    return Response.redirect(appRedirectURL, 302)
  } catch (error) {
    console.error("Callback handler error:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    )
  }
})

