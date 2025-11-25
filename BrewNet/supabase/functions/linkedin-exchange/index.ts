// Supabase Edge Function: LinkedIn OAuth Token Exchange
// This function exchanges authorization code for access token and fetches user profile
// 
// Deploy: supabase functions deploy linkedin-exchange --no-verify-jwt
// URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
//
// Environment variables required:
// - LINKEDIN_CLIENT_ID
// - LINKEDIN_CLIENT_SECRET
// - LINKEDIN_REDIRECT_URI

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const { code, redirect_uri } = await req.json()

    if (!code) {
      return new Response(
        JSON.stringify({ error: "Missing authorization code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get environment variables
    const clientId = Deno.env.get("LINKEDIN_CLIENT_ID")
    const clientSecret = Deno.env.get("LINKEDIN_CLIENT_SECRET")
    const redirectURI = redirect_uri || Deno.env.get("LINKEDIN_REDIRECT_URI") || "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback"

    if (!clientId || !clientSecret) {
      console.error("Missing LinkedIn credentials")
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

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

    console.log("Access token received, fetching profile...")

    // Step 2: Fetch user profile using OpenID Connect UserInfo endpoint
    // Try standard OpenID Connect UserInfo endpoint first
    // If that fails, fallback to LinkedIn-specific endpoint
    let profileResponse = await fetch(
      "https://www.linkedin.com/oauth/v2/userinfo",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      }
    )
    
    // If standard endpoint fails, try LinkedIn-specific endpoint
    if (!profileResponse.ok && profileResponse.status === 404) {
      console.log("Standard UserInfo endpoint failed, trying LinkedIn-specific endpoint...")
      profileResponse = await fetch(
        "https://api.linkedin.com/v2/userinfo",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        }
      )
    }

    if (!profileResponse.ok) {
      const errorText = await profileResponse.text()
      const statusCode = profileResponse.status
      const statusText = profileResponse.statusText
      
      // Log detailed error information
      console.error("Profile fetch failed:", {
        status: statusCode,
        statusText: statusText,
        error: errorText,
        url: "https://api.linkedin.com/v2/userinfo",
        hasToken: !!accessToken
      })
      
      // Try to parse error as JSON for better error message
      let errorDetail = errorText
      try {
        const errorJson = JSON.parse(errorText)
        if (errorJson.error_description) {
          errorDetail = errorJson.error_description
        } else if (errorJson.message) {
          errorDetail = errorJson.message
        } else if (errorJson.error) {
          errorDetail = errorJson.error
        }
      } catch {
        // Keep original errorText if not JSON
      }
      
      return new Response(
        JSON.stringify({ 
          error: "Failed to fetch LinkedIn profile", 
          detail: errorDetail,
          status: statusCode,
          statusText: statusText,
          hint: statusCode === 401 ? "Access token may be invalid or expired" :
                statusCode === 403 ? "Insufficient permissions. Check LinkedIn app scopes." :
                statusCode === 429 ? "Rate limit exceeded. Please try again later." :
                "Check LinkedIn API status and app configuration."
        }),
        { status: profileResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const profile = await profileResponse.json()
    
    console.log("UserInfo response:", JSON.stringify(profile, null, 2))
    console.log("UserInfo available fields:", Object.keys(profile))
    
    // Try to extract profile URL from various possible fields
    let profileUrl: string | null = null
    if (profile.profile_url || profile.publicProfileUrl || profile.url || profile.website) {
      profileUrl = profile.profile_url || profile.publicProfileUrl || profile.url || profile.website
      console.log("✅ Found profile URL in UserInfo:", profileUrl)
    } else {
      // Try to construct profile URL from name and ID
      // LinkedIn profile URLs typically follow: https://www.linkedin.com/in/{vanity-name}/
      // We can try to construct it from the user's name
      if (profile.given_name && profile.family_name) {
        const firstName = profile.given_name.toLowerCase()
        const lastName = profile.family_name.toLowerCase()
        // Note: This is a guess, actual vanity URL might be different
        console.log("⚠️ Profile URL not in UserInfo, will need to fetch from HTML or use alternative method")
      }
    }
    // Check if UserInfo contains headline in any form
    if (profile.headline || profile.localizedHeadline || profile.jobTitle || profile.title || profile.position) {
      console.log("✅ Found headline in UserInfo:", {
        headline: profile.headline,
        localizedHeadline: profile.localizedHeadline,
        jobTitle: profile.jobTitle,
        title: profile.title,
        position: profile.position
      })
    } else {
      console.log("⚠️ No headline found in UserInfo endpoint")
    }

    // Step 3: Fetch additional profile data from LinkedIn v2 API (for headline and other fields)
    // Note: LinkedIn v2 API requires specific permissions. If this fails, we'll fall back to UserInfo data.
    let headline: string | null = null
    let v2ProfileData: any = null
    
    // Try multiple API endpoints to get headline
    const apiEndpoints = [
      // Try v2 API with full projection
      "https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName,localizedHeadline,profilePicture(displayImage~:playableStreams))",
      // Try v2 API with minimal projection (might have different permission requirements)
      "https://api.linkedin.com/v2/me?projection=(id,localizedHeadline)",
      // Try People API (if available)
      "https://api.linkedin.com/v2/people/(id~me)?projection=(id,localizedHeadline)",
    ]
    
    for (const endpoint of apiEndpoints) {
      try {
        console.log(`Attempting to fetch from: ${endpoint}`)
        const v2ProfileResponse = await fetch(endpoint, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        })

        if (v2ProfileResponse.ok) {
          v2ProfileData = await v2ProfileResponse.json()
          headline = v2ProfileData?.localizedHeadline || null
          console.log("✅ v2 API profile data fetched successfully from:", endpoint)
          console.log("v2 API profile data:", JSON.stringify(v2ProfileData, null, 2))
          console.log("Headline extracted:", headline || "null/empty")
          break // Success, exit loop
        } else {
          const errorText = await v2ProfileResponse.text()
          const statusCode = v2ProfileResponse.status
          console.warn(`⚠️ API call failed for ${endpoint}:`, {
            status: statusCode,
            statusText: v2ProfileResponse.statusText,
            error: errorText
          })
          
          // If 403 Forbidden, it's likely a permissions issue
          if (statusCode === 403) {
            console.error("⚠️ Permission denied - v2 API requires additional scopes or permissions")
            console.error("⚠️ The 'profile' scope may not include access to localizedHeadline")
            console.error("⚠️ Consider checking LinkedIn app permissions in developer portal")
            // Continue to next endpoint
          }
        }
      } catch (e) {
        console.warn(`⚠️ Exception while fetching from ${endpoint}:`, e)
        // Continue to next endpoint
      }
    }
    
    if (!headline) {
      console.error("❌ Failed to fetch headline from all API endpoints")
      console.error("❌ This indicates a permissions issue. Please check LinkedIn developer portal.")
    }

    // Step 4: Fetch user email (UserInfo endpoint may include email, but we'll try the email endpoint as fallback)
    let email: string | null = null
    
    // UserInfo endpoint may include email directly
    if (profile.email) {
      email = profile.email
    } else {
      // Fallback: Try email endpoint
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
    }

    // Step 5: Extract profile picture URL (if available)
    // Try v2 API profile picture first, then UserInfo endpoint
    let profilePictureUrl: string | null = null
    try {
      // First try v2 API profile picture (more reliable)
      if (v2ProfileData?.profilePicture?.["displayImage~"]?.elements) {
        const images = v2ProfileData.profilePicture["displayImage~"].elements
        const largestImage = images
          .filter((img: any) => img.identifiers && img.identifiers.length > 0)
          .sort((a: any, b: any) => {
            const aSize = a.data?.width * a.data?.height || 0
            const bSize = b.data?.width * b.data?.height || 0
            return bSize - aSize
          })[0]

        if (largestImage?.identifiers?.[0]?.identifier) {
          profilePictureUrl = largestImage.identifiers[0].identifier
        }
      }
      
      // Fallback: UserInfo endpoint typically returns picture as a URL string
      if (!profilePictureUrl) {
        if (profile.picture) {
          profilePictureUrl = profile.picture
        } else if (profile.profilePicture) {
          // Try to extract from profilePicture object if present
          if (profile.profilePicture?.["displayImage~"]?.elements) {
            const images = profile.profilePicture["displayImage~"].elements
            const largestImage = images
              .filter((img: any) => img.identifiers && img.identifiers.length > 0)
              .sort((a: any, b: any) => {
                const aSize = a.data?.width * a.data?.height || 0
                const bSize = b.data?.width * b.data?.height || 0
                return bSize - aSize
              })[0]

            if (largestImage?.identifiers?.[0]?.identifier) {
              profilePictureUrl = largestImage.identifiers[0].identifier
            }
          }
        }
      }
    } catch (e) {
      console.warn("Failed to extract profile picture:", e)
    }

    // Step 6: Try to get profile URL and scrape additional data
    let scrapedData: any = null
    let finalProfileUrl: string | null = profileUrl || null
    
    // If we don't have profile URL, try to construct it from name
    // Note: This is a guess and may not always work
    if (!finalProfileUrl && profile.given_name && profile.family_name) {
      const firstName = profile.given_name.toLowerCase().replace(/\s+/g, "-")
      const lastName = profile.family_name.toLowerCase().replace(/\s+/g, "-")
      // This is a guess - actual vanity URL might be different
      finalProfileUrl = `https://www.linkedin.com/in/${firstName}-${lastName}/`
      console.log("⚠️ Constructed profile URL (may be incorrect):", finalProfileUrl)
    }
    
    // If we have a profile URL and headline is missing, try scraping
    if (finalProfileUrl && !headline) {
      try {
        console.log("Attempting to scrape LinkedIn profile for additional data...")
        const scraperUrl = Deno.env.get("SUPABASE_URL") 
          ? `${Deno.env.get("SUPABASE_URL")}/functions/v1/linkedin-scraper`
          : "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-scraper"
        
        const scraperResponse = await fetch(scraperUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ profileUrl: finalProfileUrl }),
        })
        
        if (scraperResponse.ok) {
          const scraperResult = await scraperResponse.json()
          if (scraperResult.success && scraperResult.data) {
            scrapedData = scraperResult.data
            console.log("✅ Successfully scraped LinkedIn profile data")
            
            // Use scraped headline if available
            if (scrapedData.headline && !headline) {
              headline = scrapedData.headline
              console.log("✅ Headline extracted from scraped data:", headline)
            }
          }
        } else {
          const errorText = await scraperResponse.text()
          console.warn("⚠️ Scraper failed:", scraperResponse.status, errorText.substring(0, 200))
        }
      } catch (e) {
        console.warn("⚠️ Exception while scraping:", e)
        // Don't fail the entire request if scraping fails
      }
    }

    // Step 7: Build complete profile object
    // Priority: scraped data > v2 API data > UserInfo endpoint data > fallbacks
    const completeProfile = {
      id: profile.sub || v2ProfileData?.id || profile.id || "",
      localizedFirstName: v2ProfileData?.localizedFirstName || profile.given_name || profile.localizedFirstName || profile.firstName || "",
      localizedLastName: v2ProfileData?.localizedLastName || profile.family_name || profile.localizedLastName || profile.lastName || "",
      localizedHeadline: headline || scrapedData?.headline || v2ProfileData?.localizedHeadline || profile.headline || profile.localizedHeadline || profile.jobTitle || profile.title || profile.position || "",
      email: email || profile.email || "",
      profilePictureUrl: profilePictureUrl || profile.picture || null,
      profileUrl: finalProfileUrl || null,
      // Include scraped data if available
      scrapedData: scrapedData || null,
    }
    
    // Log final headline value for debugging
    console.log("Final headline value:", completeProfile.localizedHeadline || "null/empty")
    console.log("Profile URL:", completeProfile.profileUrl || "not available")

    console.log("Profile fetched successfully:", {
      id: completeProfile.id,
      name: `${completeProfile.localizedFirstName} ${completeProfile.localizedLastName}`,
      email: completeProfile.email ? "***" : "not available",
    })

    // Return profile data to client
    return new Response(
      JSON.stringify({
        profile: completeProfile,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("LinkedIn exchange error:", error)
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

