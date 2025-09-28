import Foundation
import AVFoundation
import Photos
import UIKit
import os.log

/// Comprehensive permissions manager for camera, photo library, and file access
@MainActor
class PermissionsManager: ObservableObject {

    // MARK: - Types

    enum PermissionType {
        case camera
        case photoLibrary
        case photoLibraryAdd
        case microphone
        case faceID
        case touchID
    }

    enum PermissionStatus {
        case notDetermined
        case restricted
        case denied
        case authorized
        case limited // For photo library
    }

    struct PermissionInfo {
        let type: PermissionType
        let status: PermissionStatus
        let isRequired: Bool
        let title: String
        let description: String
        let settingsMessage: String
    }

    // MARK: - Published Properties

    @Published var cameraPermission: PermissionStatus = .notDetermined
    @Published var photoLibraryPermission: PermissionStatus = .notDetermined
    @Published var isCheckingPermissions = false
    @Published var needsPermissionSetup = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.mortgageguardian", category: "PermissionsManager")

    // MARK: - Initialization

    init() {
        checkAllPermissions()
    }

    // MARK: - Permission Status Checking

    func checkAllPermissions() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
        updatePermissionSetupNeeded()
    }

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = mapAVAuthorizationStatus(status)
    }

    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryPermission = mapPHAuthorizationStatus(status)
    }

    private func updatePermissionSetupNeeded() {
        needsPermissionSetup = cameraPermission == .denied ||
                              cameraPermission == .restricted ||
                              photoLibraryPermission == .denied ||
                              photoLibraryPermission == .restricted
    }

    // MARK: - Permission Requests

    func requestCameraPermission() async -> PermissionStatus {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let mappedStatus = mapAVAuthorizationStatus(status)

        cameraPermission = mappedStatus
        updatePermissionSetupNeeded()

        logger.info("Camera permission requested: \(granted ? "granted" : "denied")")
        return mappedStatus
    }

    func requestPhotoLibraryPermission() async -> PermissionStatus {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let mappedStatus = mapPHAuthorizationStatus(status)

        photoLibraryPermission = mappedStatus
        updatePermissionSetupNeeded()

        logger.info("Photo library permission requested: \(status.rawValue)")
        return mappedStatus
    }

    func requestAllRequiredPermissions() async -> Bool {
        let cameraStatus = await requestCameraPermission()
        let photoStatus = await requestPhotoLibraryPermission()

        return cameraStatus == .authorized &&
               (photoStatus == .authorized || photoStatus == .limited)
    }

    // MARK: - Permission Info

    func getPermissionInfo(for type: PermissionType) -> PermissionInfo {
        switch type {
        case .camera:
            return PermissionInfo(
                type: .camera,
                status: cameraPermission,
                isRequired: true,
                title: "Camera Access",
                description: "Capture mortgage documents with your device camera",
                settingsMessage: "Enable camera access in Settings > Privacy & Security > Camera to scan documents"
            )

        case .photoLibrary:
            return PermissionInfo(
                type: .photoLibrary,
                status: photoLibraryPermission,
                isRequired: false,
                title: "Photo Library Access",
                description: "Import document images from your photo library",
                settingsMessage: "Enable photo library access in Settings > Privacy & Security > Photos to import images"
            )

        case .photoLibraryAdd:
            return PermissionInfo(
                type: .photoLibraryAdd,
                status: photoLibraryPermission,
                isRequired: false,
                title: "Save to Photos",
                description: "Save processed documents to your photo library",
                settingsMessage: "Enable photo library access in Settings > Privacy & Security > Photos to save documents"
            )

        case .microphone:
            return PermissionInfo(
                type: .microphone,
                status: .notDetermined,
                isRequired: false,
                title: "Microphone Access",
                description: "Optional audio notes for documents",
                settingsMessage: "Enable microphone access in Settings > Privacy & Security > Microphone"
            )

        case .faceID:
            return PermissionInfo(
                type: .faceID,
                status: .notDetermined,
                isRequired: false,
                title: "Face ID",
                description: "Secure authentication for document access",
                settingsMessage: "Face ID can be configured in Settings > Face ID & Passcode"
            )

        case .touchID:
            return PermissionInfo(
                type: .touchID,
                status: .notDetermined,
                isRequired: false,
                title: "Touch ID",
                description: "Secure authentication for document access",
                settingsMessage: "Touch ID can be configured in Settings > Touch ID & Passcode"
            )
        }
    }

    func getAllPermissions() -> [PermissionInfo] {
        return [
            getPermissionInfo(for: .camera),
            getPermissionInfo(for: .photoLibrary),
            getPermissionInfo(for: .photoLibraryAdd)
        ]
    }

    func getRequiredPermissions() -> [PermissionInfo] {
        return getAllPermissions().filter { $0.isRequired }
    }

    func getDeniedPermissions() -> [PermissionInfo] {
        return getAllPermissions().filter {
            $0.status == .denied || $0.status == .restricted
        }
    }

    // MARK: - Permission Utilities

    func canUseCamera() -> Bool {
        return cameraPermission == .authorized
    }

    func canAccessPhotoLibrary() -> Bool {
        return photoLibraryPermission == .authorized || photoLibraryPermission == .limited
    }

    func canSaveToPhotoLibrary() -> Bool {
        return photoLibraryPermission == .authorized
    }

    func shouldShowPermissionAlert(for type: PermissionType) -> Bool {
        let info = getPermissionInfo(for: type)
        return info.status == .denied || info.status == .restricted
    }

    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            logger.error("Cannot open app settings")
            return
        }

        UIApplication.shared.open(settingsUrl) { success in
            self.logger.info("Opened app settings: \(success)")
        }
    }

    // MARK: - Status Mapping

    private func mapAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    private func mapPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .notDetermined
        }
    }

    // MARK: - Device Capabilities

    func isCameraAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func isPhotoLibraryAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }

    func getAvailableCameraDevices() -> [AVCaptureDevice] {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    func hasFrontCamera() -> Bool {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func hasBackCamera() -> Bool {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func hasFlash() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return false
        }
        return device.hasFlash
    }

    // MARK: - Error Handling

    func getPermissionErrorMessage(for type: PermissionType) -> String {
        let info = getPermissionInfo(for: type)

        switch info.status {
        case .denied:
            return info.settingsMessage
        case .restricted:
            return "\(info.title) is restricted by device settings or parental controls"
        case .notDetermined:
            return "Permission for \(info.title) has not been requested yet"
        case .authorized, .limited:
            return ""
        }
    }

    func createPermissionAlert(for type: PermissionType) -> UIAlertController {
        let info = getPermissionInfo(for: type)
        let alert = UIAlertController(
            title: "\(info.title) Required",
            message: info.settingsMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            self.openAppSettings()
        })

        return alert
    }

    // MARK: - Accessibility

    func getAccessibilityLabel(for type: PermissionType) -> String {
        let info = getPermissionInfo(for: type)
        let statusText = getStatusText(info.status)
        return "\(info.title), \(statusText), \(info.description)"
    }

    private func getStatusText(_ status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "not determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .limited:
            return "limited access"
        }
    }
}

// MARK: - Permission Setup View

struct PermissionSetupView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermissions = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Permissions Required")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Mortgage Guardian needs access to your camera and photo library to help you capture and import documents securely.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Permissions list
                VStack(spacing: 16) {
                    ForEach(permissionsManager.getAllPermissions(), id: \.type) { permission in
                        PermissionRow(permission: permission)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        requestPermissions()
                    } label: {
                        HStack {
                            if isRequestingPermissions {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.shield")
                            }
                            Text("Grant Permissions")
                        }
                        .foregroundColor(.white)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isRequestingPermissions)

                    Button("Continue Without Some Permissions") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .font(.body)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
        }
    }

    private func requestPermissions() {
        isRequestingPermissions = true

        Task {
            let success = await permissionsManager.requestAllRequiredPermissions()

            await MainActor.run {
                isRequestingPermissions = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

struct PermissionRow: View {
    let permission: PermissionInfo

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.title)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(permission.description)
                    .font(.body)
                    .foregroundColor(.secondary)

                if permission.status == .denied || permission.status == .restricted {
                    Text("Tap Settings to enable")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Status
            VStack {
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)

                if permission.isRequired {
                    Text("Required")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .accessibilityLabel(getAccessibilityLabel())
    }

    private var statusColor: Color {
        switch permission.status {
        case .authorized, .limited:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        }
    }

    private var statusIcon: String {
        switch permission.status {
        case .authorized, .limited:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }

    private var statusText: String {
        switch permission.status {
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Set"
        }
    }

    private func getAccessibilityLabel() -> String {
        return "\(permission.title), \(statusText), \(permission.description)"
    }
}

// MARK: - Extensions

extension PermissionsManager {
    static let shared = PermissionsManager()
}