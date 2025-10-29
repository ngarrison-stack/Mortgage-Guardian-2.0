// DocumentUploadView.swift
import SwiftUI
import PhotosUI

struct DocumentUploadView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var uploadResult: String?

    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
            }

            Button("Select Document") {
                showingImagePicker = true
            }
            .buttonStyle(.borderedProminent)

            if selectedImage != nil {
                Button("Upload & Analyze") {
                    Task {
                        await uploadDocument()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(documentManager.isProcessing)
            }

            if documentManager.isProcessing {
                ProgressView("Processing document...")
            }

            if let result = uploadResult {
                Text(result)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    private func uploadDocument() async {
        guard let image = selectedImage else { return }

        do {
            let result = try await documentManager.processDocument(image)
            uploadResult = "Document uploaded! ID: \(result.document.id)"
        } catch {
            uploadResult = "Error: \(error.localizedDescription)"
        }
    }
}

// Simple image picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}