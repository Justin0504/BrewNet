import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedImages: [UIImage] = []
    @State private var title = ""
    @State private var content = ""
    @State private var question = ""
    @State private var selectedTag = "General"
    @State private var isAnonymous = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var isPosting = false
    
    let tags = ["General", "Career", "Workplace", "Tech", "Personal", "Advice", "Networking", "Productivity", "Wellness", "Remote Work", "Experience Sharing", "Trend Direction", "Resource Library"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                contentView
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            imageActionSheet
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImages: $selectedImages, maxImages: 9)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(selectedImages: $selectedImages, maxImages: 9)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray)
            
            Spacer()
            
            Text("Create Post")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Spacer()
            
            Button("Post") {
                createPost()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(canPost ? Color(red: 0.4, green: 0.2, blue: 0.1) : .gray)
            .disabled(!canPost || isPosting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                anonymousToggle
                imageSelectionSection
                titleSection
                contentSection
                questionSection
                tagSelectionSection
                Spacer(minLength: 100)
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
    
    private var anonymousToggle: some View {
        HStack {
            Image(systemName: isAnonymous ? "eye.slash.fill" : "eye.fill")
                .foregroundColor(isAnonymous ? .orange : .gray)
            
            Toggle("Post Anonymously", isOn: $isAnonymous)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(isAnonymous ? 0.1 : 0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    private var imageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
                
                Text("\(selectedImages.count)/9")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            
            if selectedImages.isEmpty {
                addImageButton
            } else {
                imageGrid
            }
        }
    }
    
    private var addImageButton: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                
                Text("Add Photos")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("Tap to add photos from your library or take a new photo")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(Color.gray.opacity(0.3))
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var imageGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<selectedImages.count, id: \.self) { index in
                    imageItem(at: index)
                }
                
                if selectedImages.count < 9 {
                    addMoreButton
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func imageItem(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImages[index])
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(8)
            
            Button(action: {
                selectedImages.remove(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
        }
    }
    
    private var addMoreButton: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                
                Text("Add More")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .frame(width: 120, height: 120)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .foregroundColor(Color.gray.opacity(0.3))
            )
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            TextField("What's on your mind?", text: $title)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            TextField("Share your thoughts, experiences, or insights...", text: $content, axis: .vertical)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .lineLimit(5...10)
        }
        .padding(.horizontal, 16)
    }
    
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question (Optional)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            TextField("Ask a question to engage others...", text: $question)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
    
    private var tagSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        tagButton(for: tag)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func tagButton(for tag: String) -> some View {
        Button(action: {
            selectedTag = tag
        }) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedTag == tag ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedTag == tag ? Color(red: 0.4, green: 0.2, blue: 0.1) : Color.gray.opacity(0.1))
                .cornerRadius(20)
        }
    }
    
    private var imageActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Add Photo"),
            message: Text("Choose how you want to add a photo"),
            buttons: [
                .default(Text("Camera")) {
                    showingCamera = true
                },
                .default(Text("Photo Library")) {
                    showingImagePicker = true
                },
                .cancel()
            ]
        )
    }
    
    private var canPost: Bool {
        !title.isEmpty || !selectedImages.isEmpty
    }
    
    private func createPost() {
        isPosting = true
        
        // Simulate posting delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPosting = false
            presentationMode.wrappedValue.dismiss()
            
            // Here you would normally save the post to your data store
            // For now, we'll just show a success message
            print("Post created successfully!")
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let maxImages: Int
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = maxImages - selectedImages.count
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.selectedImages.append(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let maxImages: Int
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImages.append(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview
struct CreatePostView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePostView()
    }
}
