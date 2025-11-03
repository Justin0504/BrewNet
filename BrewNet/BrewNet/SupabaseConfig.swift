import Foundation
import Supabase

// MARK: - Supabase Configuration
class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    // TODO: 替换为您的 Supabase 项目配置
    private let supabaseURL = "https://jcxvdolcdifdghaibspy.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjeHZkb2xjZGlmZGdoYWlic3B5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5ODIzNjksImV4cCI6MjA3NjU1ODM2OX0.z_Fa8XDp7S_oP3_Aqx2jjuGcE3tuwYRQ3DOEvdNCkX0"
    
    lazy var client: SupabaseClient = {
        return SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
    }()
    
    private init() {}
}

// MARK: - Supabase Tables
enum SupabaseTable: String, CaseIterable {
    case users = "users"
    case profiles = "profiles"
    case invitations = "invitations"
    case matches = "matches"
    case coffeeChats = "coffee_chats"
    case messages = "messages"
}

// MARK: - Database Schema Helper
struct DatabaseSchema {
    static func createTables() async throws {
        let _ = SupabaseConfig.shared.client
        
        // 注意：这些 SQL 语句需要在 Supabase Dashboard 中执行
        // 这里只是作为参考
        let _ = """
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT,
            is_guest BOOLEAN DEFAULT FALSE,
            profile_image TEXT,
            bio TEXT,
            company TEXT,
            job_title TEXT,
            location TEXT,
            skills TEXT,
            interests TEXT,
            profile_setup_completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        let _ = """
        CREATE TABLE IF NOT EXISTS profiles (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            core_identity JSONB NOT NULL,
            professional_background JSONB NOT NULL,
            networking_intention JSONB NOT NULL,
            networking_preferences JSONB NOT NULL,
            personality_social JSONB NOT NULL,
            privacy_trust JSONB NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(user_id)
        );
        """
        
        let _ = """
        CREATE TABLE IF NOT EXISTS invitations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
            reason_for_interest TEXT,
            sender_profile JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_invitations_unique_pending 
            ON invitations(sender_id, receiver_id) 
            WHERE status = 'pending';
        """
        
        let _ = """
        CREATE TABLE IF NOT EXISTS matches (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            matched_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            matched_user_name TEXT NOT NULL,
            match_type TEXT NOT NULL DEFAULT 'mutual' CHECK (match_type IN ('mutual', 'invitation_based', 'recommended')),
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_unique_active 
            ON matches(user_id, matched_user_id) 
            WHERE is_active = TRUE;
        """
        
        let _ = """
        CREATE TABLE IF NOT EXISTS coffee_chats (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id),
            title TEXT NOT NULL,
            participant_id TEXT NOT NULL,
            participant_name TEXT NOT NULL,
            scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
            location TEXT NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        let _ = """
        CREATE TABLE IF NOT EXISTS messages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            sender_id UUID NOT NULL REFERENCES users(id),
            receiver_id UUID NOT NULL REFERENCES users(id),
            content TEXT NOT NULL,
            message_type TEXT NOT NULL,
            is_read BOOLEAN DEFAULT FALSE,
            timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        print("📋 数据库表结构已定义，请在 Supabase Dashboard 中执行相应的 SQL 语句")
        print("📋 或者使用 Supabase CLI 来创建这些表")
    }
}
