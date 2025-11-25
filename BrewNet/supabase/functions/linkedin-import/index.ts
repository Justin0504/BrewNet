// Supabase Edge Function: LinkedIn Profile Data Import
// This function handles LinkedIn OAuth token exchange, profile data fetching,
// data cleaning, and storage to linkedin_profiles table
//
// Deploy: supabase functions deploy linkedin-import --no-verify-jwt
// URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-import
//
// Environment variables required:
// - LINKEDIN_CLIENT_ID
// - LINKEDIN_CLIENT_SECRET
// - LINKEDIN_REDIRECT_URI
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface LinkedInProfile {
  id: string
  localizedFirstName?: string
  localizedLastName?: string
  localizedHeadline?: string
  vanityName?: string
  profilePicture?: any
  email?: string
}

interface ConsentLog {
  consent_ts: string
  user_agent?: string
  ip?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Parse request body
    const body = await req.json()
    const { code, user_id, redirect_uri } = body

    if (!code || !user_id) {
      return new Response(
        JSON.stringify({ error: "Missing code or user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get environment variables
    const clientId = Deno.env.get("LINKEDIN_CLIENT_ID")
    const clientSecret = Deno.env.get("LINKEDIN_CLIENT_SECRET")
    const redirectURI = redirect_uri || Deno.env.get("LINKEDIN_REDIRECT_URI")
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE")

    if (!clientId || !clientSecret || !supabaseUrl || !supabaseServiceKey) {
      console.error("Missing required environment variables")
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    // Step 1: Exchange authorization code for access token
    console.log("Exchanging code for access token...")
    const tokenParams = new URLSearchParams({
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirectURI,
      client_id: clientId,
      client_secret: clientSecret,
    })

    const tokenResponse = await fetch("https://www.linkedin.com/oauth/v2/accessToken", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: tokenParams.toString(),
    })

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error("Token exchange failed:", errorText)
      return new Response(
        JSON.stringify({ error: "Failed to exchange code for token", detail: errorText }),
        { status: tokenResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const tokenData = await tokenResponse.json()
    const accessToken = tokenData.access_token

    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: "No access token received" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log("Access token received, fetching profile data...")

    // Step 2: Fetch profile data from LinkedIn v2 API
    const profileResponse = await fetch(
      "https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName,localizedHeadline,vanityName,profilePicture(displayImage~:playableStreams))",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    )

    if (!profileResponse.ok) {
      const errorText = await profileResponse.text()
      console.error("Profile fetch failed:", errorText)
      return new Response(
        JSON.stringify({ error: "Failed to fetch LinkedIn profile", detail: errorText }),
        { status: profileResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const profileData: LinkedInProfile = await profileResponse.json()
    console.log("Profile data fetched:", JSON.stringify(profileData, null, 2))

    // Step 3: Fetch email address
    let email: string | null = null
    try {
      const emailResponse = await fetch(
        "https://api.linkedin.com/v2/emailAddress?q=members&projection=(elements*(handle~))",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      )

      if (emailResponse.ok) {
        const emailData = await emailResponse.json()
        email = emailData?.elements?.[0]?.["handle~"]?.emailAddress || null
      }
    } catch (e) {
      console.warn("Failed to fetch email:", e)
    }

    // Step 4: Extract and process profile picture URL
    let avatarUrl: string | null = null
    try {
      const displayImage = profileData?.profilePicture?.["displayImage~"]
      if (displayImage?.elements && Array.isArray(displayImage.elements)) {
        // Sort by resolution (width * height) and pick the highest
        const images = displayImage.elements
          .filter((img: any) => img.identifiers && img.identifiers.length > 0)
          .sort((a: any, b: any) => {
            const aSize = (a.data?.width || 0) * (a.data?.height || 0)
            const bSize = (b.data?.width || 0) * (b.data?.height || 0)
            return bSize - aSize
          })

        if (images.length > 0) {
          avatarUrl = images[0].identifiers[0].identifier
        }
      }
    } catch (e) {
      console.warn("Failed to extract avatar URL:", e)
    }

    // Step 5: Build consent log
    const consentLog: ConsentLog = {
      consent_ts: new Date().toISOString(),
      user_agent: req.headers.get("user-agent") || undefined,
      ip: req.headers.get("x-forwarded-for") || req.headers.get("x-real-ip") || undefined,
    }

    // Step 6: Prepare data for database insertion
    const linkedinProfileData = {
      user_id,
      linkedin_id: profileData.id,
      vanity_name: profileData.vanityName || null,
      headline: profileData.localizedHeadline || null,
      raw_profile: profileData,
      email: email,
      avatar_url: avatarUrl,
      import_status: "pending",
      consent_log: consentLog,
      last_fetched_at: new Date().toISOString(),
    }

    // Step 7: Upsert to linkedin_profiles table
    const { data, error } = await supabase
      .from("linkedin_profiles")
      .upsert(linkedinProfileData, { onConflict: "linkedin_id" })
      .select()
      .single()

    if (error) {
      console.error("Database upsert error:", error)
      return new Response(
        JSON.stringify({ error: "Failed to save profile data", detail: error }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Step 8: Log the import action
    await supabase.from("linkedin_import_audit").insert({
      user_id,
      linkedin_profile_id: data.id,
      action: "fetched",
      detail: {
        fetched_at: new Date().toISOString(),
        has_headline: !!profileData.localizedHeadline,
        has_email: !!email,
        has_avatar: !!avatarUrl,
        has_vanity: !!profileData.vanityName,
      }
    })

    // Step 9: Extract and clean data for frontend preview
    const cleanProfile = {
      id: data.id,
      linkedin_id: profileData.id,
      firstName: profileData.localizedFirstName || "",
      lastName: profileData.localizedLastName || "",
      fullName: `${profileData.localizedFirstName || ""} ${profileData.localizedLastName || ""}`.trim(),
      headline: profileData.localizedHeadline || "",
      vanityName: profileData.vanityName || null,
      email: email || "",
      avatarUrl: avatarUrl,
      profileUrl: profileData.vanityName ? `https://www.linkedin.com/in/${profileData.vanityName}` : null,
    }

    // Step 10: Perform basic data enrichment (optional)
    const enrichedData = await enrichProfileData(cleanProfile)

    console.log("LinkedIn profile imported successfully for user:", user_id)

    return new Response(
      JSON.stringify({
        success: true,
        profile: cleanProfile,
        enriched: enrichedData,
        import_id: data.id,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )

  } catch (error) {
    console.error("LinkedIn import error:", error)
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        detail: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

// Basic data enrichment function
async function enrichProfileData(profile: any) {
  const enriched = { ...profile }

  // Extract tags from headline (simple keyword extraction)
  if (profile.headline) {
    const tags = extractTagsFromHeadline(profile.headline)
    enriched.tags = tags
  }

  // Determine role level based on keywords in headline
  if (profile.headline) {
    enriched.roleLevel = determineRoleLevel(profile.headline)
  }

  return enriched
}

// Extract tags from LinkedIn headline
function extractTagsFromHeadline(headline: string): string[] {
  const tags: string[] = []

  // Common separators in LinkedIn headlines
  const separators = /[\|\-\@\,\&\(\)]/
  const parts = headline.split(separators)

  for (const part of parts) {
    const trimmed = part.trim()
    if (trimmed.length > 2 && trimmed.length < 50) {
      // Basic filtering - avoid very short or very long parts
      tags.push(trimmed)
    }
  }

  // Remove duplicates and return top 5
  return [...new Set(tags)].slice(0, 5)
}

// Determine role level based on keywords
function determineRoleLevel(headline: string): string {
  const lowerHeadline = headline.toLowerCase()

  // Senior/executive keywords
  if (/\b(senior|lead|principal|head|director|vp|chief|manager|architect)\b/.test(lowerHeadline)) {
    return "senior"
  }

  // Junior/entry level keywords
  if (/\b(junior|entry|intern|associate|trainee|graduate|new grad)\b/.test(lowerHeadline)) {
    return "junior"
  }

  // Engineering/Developer keywords
  if (/\b(software|engineer|developer|programmer|architect|tech|engineering)\b/.test(lowerHeadline)) {
    return "engineer"
  }

  // Student keywords
  if (/\b(student|phd|master|undergrad|university|college)\b/.test(lowerHeadline)) {
    return "student"
  }

  // Default
  return "professional"
}
