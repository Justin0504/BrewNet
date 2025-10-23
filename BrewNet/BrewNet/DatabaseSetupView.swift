import SwiftUI

struct DatabaseSetupView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSQLInstructions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "database")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Database Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("The profiles table needs to be created in your Supabase database.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 16) {
                    Button("Check Profiles Table") {
                        checkProfilesTable()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                    
                    Button("Show SQL Instructions") {
                        showSQLInstructions = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                if isLoading {
                    ProgressView("Checking...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Database Setup")
            .alert("Database Status", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showSQLInstructions) {
                SQLInstructionsView()
            }
        }
    }
    
    private func checkProfilesTable() {
        isLoading = true
        
        Task {
            do {
                try await supabaseService.createProfilesTable()
                await MainActor.run {
                    isLoading = false
                    alertMessage = "✅ Profiles table exists and is ready to use!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "❌ Profiles table not found. Please create it using the SQL instructions."
                    showAlert = true
                }
            }
        }
    }
}

struct SQLInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SQL Instructions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Follow these steps to create the profiles table:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Go to your Supabase Dashboard")
                        Text("2. Navigate to SQL Editor")
                        Text("3. Copy and paste the following SQL statement:")
                            .fontWeight(.semibold)
                    }
                    
                    Text("SQL Statement:")
                        .font(.headline)
                        .padding(.top)
                    
                    Text(createProfilesTableSQL)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("4. Click 'Run' to execute the SQL")
                    Text("5. Return to the app and try again")
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("SQL Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private let createProfilesTableSQL = """
CREATE TABLE IF NOT EXISTS profiles (
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
"""
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    DatabaseSetupView()
        .environmentObject(SupabaseService.shared)
}
