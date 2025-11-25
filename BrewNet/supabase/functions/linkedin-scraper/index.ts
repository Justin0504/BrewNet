// Supabase Edge Function: LinkedIn Profile HTML Scraper
// This function scrapes LinkedIn profile HTML to extract structured data
// 
// Deploy: supabase functions deploy linkedin-scraper --no-verify-jwt
// URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-scraper
//
// Note: This is a workaround for API limitations. Use with caution and respect LinkedIn's ToS.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface ScrapedProfile {
  headline?: string
  location?: string
  about?: string
  experience?: Array<{
    title?: string
    company?: string
    duration?: string
  }>
  education?: Array<{
    school?: string
    degree?: string
    field?: string
    duration?: string
  }>
  skills?: string[]
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
    const { profileUrl } = await req.json()

    if (!profileUrl) {
      return new Response(
        JSON.stringify({ error: "Missing profileUrl" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Validate LinkedIn URL format
    if (!profileUrl.includes("linkedin.com/in/")) {
      return new Response(
        JSON.stringify({ error: "Invalid LinkedIn profile URL" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log("Scraping LinkedIn profile:", profileUrl)

    // Fetch LinkedIn profile HTML
    // Note: LinkedIn may block requests without proper headers
    const htmlResponse = await fetch(profileUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
      },
    })

    if (!htmlResponse.ok) {
      const errorText = await htmlResponse.text()
      console.error("Failed to fetch LinkedIn profile HTML:", {
        status: htmlResponse.status,
        statusText: htmlResponse.statusText,
        error: errorText.substring(0, 500)
      })
      
      return new Response(
        JSON.stringify({ 
          error: "Failed to fetch LinkedIn profile",
          detail: `HTTP ${htmlResponse.status}: ${htmlResponse.statusText}`,
          hint: "LinkedIn may be blocking the request. This could be due to rate limiting or anti-scraping measures."
        }),
        { status: htmlResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const html = await htmlResponse.text()
    console.log("HTML fetched, length:", html.length)

    // Parse HTML to extract structured data
    const scrapedData = parseLinkedInHTML(html)

    console.log("Scraped data:", JSON.stringify(scrapedData, null, 2))

    return new Response(
      JSON.stringify({
        success: true,
        profileUrl: profileUrl,
        data: scrapedData,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("LinkedIn scraper error:", error)
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

function parseLinkedInHTML(html: string): ScrapedProfile {
  const profile: ScrapedProfile = {}

  try {
    // Extract headline - LinkedIn stores this in various places
    // Try to find it in JSON-LD structured data first
    const jsonLdMatch = html.match(/<script type="application\/ld\+json">(.*?)<\/script>/s)
    if (jsonLdMatch) {
      try {
        const jsonLd = JSON.parse(jsonLdMatch[1])
        if (jsonLd.headline) {
          profile.headline = jsonLd.headline
        }
        if (jsonLd.address?.addressLocality) {
          profile.location = jsonLd.address.addressLocality
        }
      } catch (e) {
        console.warn("Failed to parse JSON-LD:", e)
      }
    }

    // Extract headline from meta tags or other HTML elements
    if (!profile.headline) {
      // Try meta description
      const metaDescMatch = html.match(/<meta[^>]*property="og:description"[^>]*content="([^"]*)"/i)
      if (metaDescMatch) {
        profile.headline = metaDescMatch[1].trim()
      }
      
      // Try title tag
      if (!profile.headline) {
        const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i)
        if (titleMatch && titleMatch[1].includes("|")) {
          const parts = titleMatch[1].split("|")
          if (parts.length > 1) {
            profile.headline = parts[1].trim()
          }
        }
      }
    }

    // Extract location
    if (!profile.location) {
      const locationMatch = html.match(/<span[^>]*class="[^"]*text-body-small[^"]*"[^>]*>([^<]*),?\s*([^<]*)<\/span>/i)
      if (locationMatch) {
        profile.location = locationMatch[0].replace(/<[^>]*>/g, "").trim()
      }
    }

    // Extract about section
    const aboutMatch = html.match(/<section[^>]*id="about"[^>]*>.*?<span[^>]*>([^<]*)<\/span>/is)
    if (aboutMatch) {
      profile.about = aboutMatch[1].trim()
    }

    // Extract experience (simplified - LinkedIn's HTML structure is complex)
    profile.experience = []
    const experienceMatches = html.matchAll(/<li[^>]*class="[^"]*experience[^"]*"[^>]*>.*?<span[^>]*>([^<]*)<\/span>.*?<span[^>]*>([^<]*)<\/span>/gis)
    for (const match of experienceMatches) {
      if (match[1] && match[2]) {
        profile.experience.push({
          title: match[1].trim(),
          company: match[2].trim(),
        })
      }
    }

    // Extract education (simplified)
    profile.education = []
    const educationMatches = html.matchAll(/<li[^>]*class="[^"]*education[^"]*"[^>]*>.*?<span[^>]*>([^<]*)<\/span>.*?<span[^>]*>([^<]*)<\/span>/gis)
    for (const match of educationMatches) {
      if (match[1] && match[2]) {
        profile.education.push({
          school: match[1].trim(),
          degree: match[2].trim(),
        })
      }
    }

    // Extract skills (simplified)
    profile.skills = []
    const skillMatches = html.matchAll(/<span[^>]*class="[^"]*skill[^"]*"[^>]*>([^<]*)<\/span>/gi)
    for (const match of skillMatches) {
      if (match[1]) {
        profile.skills.push(match[1].trim())
      }
    }

    // Alternative: Try to extract from inline JSON data
    // LinkedIn often embeds profile data in window.__INITIAL_STATE__ or similar
    const initialStateMatch = html.match(/window\.__INITIAL_STATE__\s*=\s*({.*?});/s)
    if (initialStateMatch) {
      try {
        const initialState = JSON.parse(initialStateMatch[1])
        // Navigate through the nested structure to find profile data
        // This structure varies, so we'll try common paths
        if (initialState.profile?.headline) {
          profile.headline = initialState.profile.headline
        }
        if (initialState.profile?.location) {
          profile.location = initialState.profile.location
        }
      } catch (e) {
        console.warn("Failed to parse __INITIAL_STATE__:", e)
      }
    }

  } catch (error) {
    console.error("Error parsing LinkedIn HTML:", error)
  }

  return profile
}



