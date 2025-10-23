# Profile Backend Setup Guide

## 🎯 Overview
This guide will help you set up the complete profile backend infrastructure for BrewNet using Supabase.

## 📋 Prerequisites
- Supabase project created
- Supabase URL and API key configured
- Users table already created

## 🚀 Setup Steps

### 1. Create Profiles Table
Execute the SQL script in Supabase Dashboard:

```sql
-- Run this in Supabase Dashboard > SQL Editor
-- File: create_profiles_table.sql
```

### 2. Test Profile Backend
Execute the test script to verify everything works:

```sql
-- Run this in Supabase Dashboard > SQL Editor
-- File: test_profile_backend.sql
```

### 3. Verify Setup
Check that the following are working:
- ✅ Profiles table created
- ✅ Row Level Security enabled
- ✅ Policies configured
- ✅ Indexes created
- ✅ Triggers working
- ✅ Sample data inserted

## 🏗️ Database Schema

### Profiles Table Structure
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intent JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);
```

### JSONB Structure

#### Core Identity
```json
{
    "name": "string",
    "email": "string",
    "phone_number": "string?",
    "profile_image": "string?",
    "bio": "string?",
    "pronouns": "string?",
    "location": "string?",
    "personal_website": "string?",
    "github_url": "string?",
    "linkedin_url": "string?",
    "time_zone": "string",
    "available_timeslot": {
        "sunday": {"morning": boolean, "noon": boolean, "afternoon": boolean, "evening": boolean, "night": boolean},
        "monday": {...},
        "tuesday": {...},
        "wednesday": {...},
        "thursday": {...},
        "friday": {...},
        "saturday": {...}
    }
}
```

#### Professional Background
```json
{
    "current_company": "string?",
    "job_title": "string?",
    "industry": "string?",
    "experience_level": "string",
    "education": "string?",
    "years_of_experience": "number?",
    "career_stage": "string",
    "skills": ["string"],
    "certifications": ["string"],
    "languages_spoken": ["string"],
    "work_experiences": [
        {
            "company": "string",
            "position": "string",
            "start_date": "string",
            "end_date": "string?",
            "description": "string"
        }
    ]
}
```

#### Networking Intent
```json
{
    "networking_intent": ["string"],
    "conversation_topics": ["string"],
    "collaboration_interest": ["string"],
    "coffee_chat_goal": "string?",
    "preferred_chat_format": "string",
    "available_timeslot": {...},
    "preferred_chat_duration": "string?",
    "intro_prompt_answers": [
        {
            "prompt": "string",
            "answer": "string"
        }
    ]
}
```

#### Personality Social
```json
{
    "icebreaker_prompts": [
        {
            "prompt": "string",
            "answer": "string"
        }
    ],
    "values_tags": ["string"],
    "hobbies": ["string"],
    "preferred_meeting_vibe": "string",
    "communication_style": "string"
}
```

#### Privacy Trust
```json
{
    "visibility_settings": {
        "company": "string",
        "email": "string",
        "phone_number": "string",
        "location": "string",
        "skills": "string",
        "interests": "string"
    },
    "verified_status": "string",
    "data_sharing_consent": "boolean",
    "report_preferences": {
        "allow_reports": "boolean",
        "report_categories": ["string"]
    }
}
```

## 🔧 API Endpoints

### Profile Operations
- `createProfile(profile: SupabaseProfile)` → `SupabaseProfile`
- `getProfile(userId: String)` → `SupabaseProfile?`
- `updateProfile(profileId: String, profile: SupabaseProfile)` → `SupabaseProfile`
- `deleteProfile(profileId: String)` → `void`
- `getRecommendedProfiles(userId: String, limit: Int)` → `[SupabaseProfile]`
- `searchProfiles(query: String, limit: Int)` → `[SupabaseProfile]`
- `hasProfile(userId: String)` → `Bool`
- `getProfileCompletion(userId: String)` → `Double`

### Error Handling
All operations include comprehensive error handling with specific error types:
- `ProfileError.invalidData`
- `ProfileError.creationFailed`
- `ProfileError.fetchFailed`
- `ProfileError.updateFailed`
- `ProfileError.deleteFailed`
- `ProfileError.searchFailed`
- `ProfileError.networkError`
- `ProfileError.unknownError`

## 🔒 Security Features

### Row Level Security (RLS)
- Users can only access their own profiles
- Secure data isolation
- Automatic policy enforcement

### Data Validation
- Required field validation
- Email format validation
- JSON structure validation
- Data type validation

## 📊 Performance Optimizations

### Indexes
- `idx_profiles_user_id` - Fast user lookups
- `idx_profiles_created_at` - Time-based queries

### Triggers
- Automatic `updated_at` timestamp updates
- Data consistency maintenance

## 🧪 Testing

### Test Coverage
- ✅ Profile creation
- ✅ Profile retrieval
- ✅ Profile updates
- ✅ Profile deletion
- ✅ Search functionality
- ✅ Recommendation system
- ✅ Error handling
- ✅ Data validation

### Test Data
Sample profiles are included for testing and development.

## 🚀 Next Steps

1. **Execute SQL Scripts**: Run the provided SQL scripts in Supabase Dashboard
2. **Test Backend**: Use the test script to verify functionality
3. **Integrate Frontend**: Connect your SwiftUI app to the profile backend
4. **Monitor Performance**: Use Supabase Dashboard to monitor queries and performance
5. **Scale as Needed**: Add more indexes or optimize queries based on usage patterns

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)

## 🆘 Troubleshooting

### Common Issues
1. **Table not found**: Ensure you've run the `create_profiles_table.sql` script
2. **Permission denied**: Check RLS policies are correctly configured
3. **JSON parsing errors**: Verify JSON structure matches the expected schema
4. **Performance issues**: Check if indexes are properly created

### Debug Queries
```sql
-- Check if table exists
SELECT table_name FROM information_schema.tables WHERE table_name = 'profiles';

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'profiles';

-- Check indexes
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'profiles';
```

---

✅ **Profile Backend Setup Complete!**

Your BrewNet profile system is now ready for production use with full CRUD operations, security, and performance optimizations.
