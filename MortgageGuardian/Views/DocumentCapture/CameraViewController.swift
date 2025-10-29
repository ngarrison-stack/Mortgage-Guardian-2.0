import UIKit
import SwiftUI
import AVFoundation
import Vision
import os.log

/// UIKit wrapper for camera functionality with document scanning optimizations
class CameraViewController: UIViewController {

    // MARK: - Types

    struct CameraConfiguration {
        let enableDocumentDetection: Bool
        let enableAutoFocus: Bool
        let enableAutoExposure: Bool
        let showGuides: Bool
        let maxCaptureCount: Int
        let enableMultiPageMode: Bool

        static let `default` = CameraConfiguration(
            enableDocumentDetection: true,
            enableAutoFocus: true,
            enableAutoExposure: true,
            showGuides: true,
            maxCaptureCount: 1,
            enableMultiPageMode: false
        )

        static let multiPage = CameraConfiguration(
            enableDocumentDetection: true,
            enableAutoFocus: true,
            enableAutoExposure: true,
            showGuides: true,
            maxCaptureCount: 10,
            enableMultiPageMode: true
        )
    }

    // MARK: - Properties

    weak var delegate: CameraViewControllerDelegate?
    private let configuration: CameraConfiguration
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "CameraViewController")

    // Camera components
    private var captureSession: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentCameraInput: AVCaptureDeviceInput?

    // Document detection
    private var rectangleDetectionRequest: VNDetectRectanglesRequest!
    private var documentBounds: VNRectangleObservation?

    // UI Components
    private var previewView: UIView!
    private var captureButton: UIButton!
    private var flashButton: UIButton!
    private var switchCameraButton: UIButton!
    private var closeButton: UIButton!
    private var guidesOverlay: DocumentGuidesView!
    private var detectionOverlay: CAShapeLayer!
    private var controlsContainer: UIView!
    private var instructionLabel: UILabel!
    private var countLabel: UILabel!

    // State
    private var isCapturing = false
    private var capturedImages: [UIImage] = []
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    // MARK: - Initialization

    init(configuration: CameraConfiguration = .default, delegate: CameraViewControllerDelegate? = nil) {
        self.configuration = configuration
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        setupDocumentDetection()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCameraSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
        updateUILayout()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Preview view
        previewView = UIView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)

        // Document guides overlay
        if configuration.showGuides {
            guidesOverlay = DocumentGuidesView()
            guidesOverlay.translatesAutoresizingMaskIntoConstraints = false
            guidesOverlay.backgroundColor = .clear
            view.addSubview(guidesOverlay)
        }

        // Controls container
        controlsContainer = UIView()
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(controlsContainer)

        // Instruction label
        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Position the document within the guides"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        view.addSubview(instructionLabel)

        // Capture button
        captureButton = UIButton(type: .custom)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        captureButton.accessibilityLabel = "Capture document"
        captureButton.accessibilityHint = "Double tap to take a photo of the document"
        controlsContainer.addSubview(captureButton)

        // Flash button
        flashButton = UIButton(type: .custom)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setImage(UIImage(systemName: "bolt.circle"), for: .normal)
        flashButton.tintColor = .white
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        flashButton.accessibilityLabel = "Toggle flash"
        flashButton.accessibilityHint = "Double tap to change flash settings"
        controlsContainer.addSubview(flashButton)

        // Switch camera button
        switchCameraButton = UIButton(type: .custom)
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.addTarget(self, action: #selector(switchCameraButtonTapped), for: .touchUpInside)
        switchCameraButton.accessibilityLabel = "Switch camera"
        switchCameraButton.accessibilityHint = "Double tap to switch between front and back camera"
        controlsContainer.addSubview(switchCameraButton)

        // Close button
        closeButton = UIButton(type: .custom)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = "Close camera"
        closeButton.accessibilityHint = "Double tap to close the camera and return to document capture"
        view.addSubview(closeButton)

        // Count label (for multi-page mode)
        if configuration.enableMultiPageMode {
            countLabel = UILabel()
            countLabel.translatesAutoresizingMaskIntoConstraints = false
            countLabel.textColor = .white
            countLabel.font = .systemFont(ofSize: 14, weight: .medium)
            countLabel.textAlignment = .center
            countLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            countLabel.layer.cornerRadius = 16
            countLabel.clipsToBounds = true
            updateCountLabel()
            view.addSubview(countLabel)
        }

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Preview view
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor),

            // Controls container
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 120),

            // Capture button
            captureButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),

            // Flash button
            flashButton.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -40),
            flashButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),

            // Switch camera button
            switchCameraButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 40),
            switchCameraButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 40),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 40),

            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Instruction label
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            instructionLabel.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -20)
        ])

        // Guides overlay
        if let guidesOverlay = guidesOverlay {
            NSLayoutConstraint.activate([
                guidesOverlay.topAnchor.constraint(equalTo: previewView.topAnchor),
                guidesOverlay.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
                guidesOverlay.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
                guidesOverlay.bottomAnchor.constraint(equalTo: previewView.bottomAnchor)
            ])
        }

        // Count label
        if let countLabel = countLabel {
            NSLayoutConstraint.activate([
                countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
                countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
                countLabel.heightAnchor.constraint(equalToConstant: 32)
            ])
        }
    }

    private func updateUILayout() {
        // Update detection overlay if needed
        detectionOverlay?.frame = previewView.bounds
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        // Configure photo output
        photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.canAddOutput(photoOutput)
        }

        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)

        // Add camera input
        addCameraInput(position: .back)

        // Setup detection overlay
        if configuration.enableDocumentDetection {
            setupDetectionOverlay()
        }
    }

    private func addCameraInput(position: AVCaptureDevice.Position) {
        // Remove existing input
        if let currentInput = currentCameraInput {
            captureSession.removeInput(currentInput)
        }

        // Add new input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            logger.error("Failed to create camera input for position: \(position.rawValue)")
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentCameraInput = input
            currentCameraPosition = position

            // Configure camera settings
            configureCameraSettings(for: camera)
        }
    }

    private func configureCameraSettings(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Auto focus
            if configuration.enableAutoFocus && device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Auto exposure
            if configuration.enableAutoExposure && device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            // Enable low light boost if available
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            device.unlockForConfiguration()
        } catch {
            logger.error("Failed to configure camera settings: \(error.localizedDescription)")
        }
    }

    private func setupDetectionOverlay() {
        detectionOverlay = CAShapeLayer()
        detectionOverlay.strokeColor = UIColor.systemBlue.cgColor
        detectionOverlay.fillColor = UIColor.clear.cgColor
        detectionOverlay.lineWidth = 3.0
        detectionOverlay.frame = previewView.bounds
        previewView.layer.addSublayer(detectionOverlay)
    }

    // MARK: - Document Detection

    private func setupDocumentDetection() {
        rectangleDetectionRequest = VNDetectRectanglesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleDocumentDetection(request: request, error: error)
            }
        }

        rectangleDetectionRequest.maximumObservations = 1
        rectangleDetectionRequest.minimumConfidence = 0.8
        rectangleDetectionRequest.minimumAspectRatio = 0.3
        rectangleDetectionRequest.maximumAspectRatio = 1.7
    }

    private func handleDocumentDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation],
              let rectangle = observations.first else {
            documentBounds = nil
            updateDetectionOverlay(rectangle: nil)
            return
        }

        documentBounds = rectangle
        updateDetectionOverlay(rectangle: rectangle)
        updateInstructionText(hasDocument: true)
    }

    private func updateDetectionOverlay(rectangle: VNRectangleObservation?) {
        guard configuration.enableDocumentDetection,
              let detectionOverlay = detectionOverlay else { return }

        if let rectangle = rectangle {
            let bounds = previewLayer.layerRectConverted(fromMetadataOutputRect: rectangle.boundingBox)
            let path = createRectanglePath(from: rectangle, in: bounds)
            detectionOverlay.path = path
            detectionOverlay.strokeColor = UIColor.systemGreen.cgColor
        } else {
            detectionOverlay.path = nil
        }
    }

    private func createRectanglePath(from rectangle: VNRectangleObservation, in bounds: CGRect) -> CGPath {
        let path = CGMutablePath()

        let topLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.topLeft)
        let topRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.topRight)
        let bottomRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.bottomRight)
        let bottomLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: rectangle.bottomLeft)

        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()

        return path
    }

    private func updateInstructionText(hasDocument: Bool) {
        if hasDocument {
            instructionLabel.text = "Document detected - tap to capture"
            instructionLabel.textColor = .systemGreen
        } else {
            instructionLabel.text = "Position the document within the guides"
            instructionLabel.textColor = .white
        }
    }

    // MARK: - Camera Session

    private func startCameraSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    private func stopCameraSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Actions

    @objc private func captureButtonTapped() {
        guard !isCapturing else { return }
        capturePhoto()
    }

    @objc private func flashButtonTapped() {
        switch flashMode {
        case .off:
            flashMode = .auto
            flashButton.setImage(UIImage(systemName: "bolt.circle"), for: .normal)
        case .auto:
            flashMode = .on
            flashButton.setImage(UIImage(systemName: "bolt.circle.fill"), for: .normal)
        case .on:
            flashMode = .off
            flashButton.setImage(UIImage(systemName: "bolt.slash.circle"), for: .normal)
        @unknown default:
            flashMode = .auto
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    @objc private func switchCameraButtonTapped() {
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        addCameraInput(position: newPosition)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    @objc private func closeButtonTapped() {
        delegate?.cameraViewControllerDidCancel(self)
    }

    // MARK: - Photo Capture

    private func capturePhoto() {
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode

        // Enable high resolution capture
        if photoOutput.isHighResolutionCaptureEnabled {
            settings.isHighResolutionPhotoEnabled = true
        }

        // Capture with current settings
        photoOutput.capturePhoto(with: settings, delegate: self)

        // Visual feedback
        animateCaptureFlash()

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }

    private func animateCaptureFlash() {
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        view.addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                flashView.alpha = 0
            } completion: { _ in
                flashView.removeFromSuperview()
            }
        }
    }

    private func updateCountLabel() {
        guard let countLabel = countLabel else { return }
        countLabel.text = "\(capturedImages.count)/\(configuration.maxCaptureCount)"
    }

    // MARK: - Multi-page handling

    private func handleCapturedImage(_ image: UIImage) {
        capturedImages.append(image)

        if configuration.enableMultiPageMode {
            updateCountLabel()

            if capturedImages.count >= configuration.maxCaptureCount {
                // Reached maximum, finish capture
                delegate?.cameraViewController(self, didCaptureImages: capturedImages)
            } else {
                // Continue capturing
                showContinuePrompt()
            }
        } else {
            // Single capture mode
            delegate?.cameraViewController(self, didCaptureImage: image)
        }
    }

    private func showContinuePrompt() {
        let alert = UIAlertController(
            title: "Document Captured",
            message: "Would you like to capture another page?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            // Continue capturing
        })

        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
            self.delegate?.cameraViewController(self, didCaptureImages: self.capturedImages)
        })

        present(alert, animated: true)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false

        if let error = error {
            logger.error("Photo capture failed: \(error.localizedDescription)")
            delegate?.cameraViewController(self, didFailWithError: error)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            logger.error("Failed to create image from photo data")
            delegate?.cameraViewController(self, didFailWithError: CameraError.imageCreationFailed)
            return
        }

        // Apply perspective correction if document was detected
        let finalImage = applePerspectiveCorrection(to: image) ?? image

        handleCapturedImage(finalImage)
    }

    private func applePerspectiveCorrection(to image: UIImage) -> UIImage? {
        guard let rectangle = documentBounds else { return image }

        // Apply perspective correction using Vision framework
        // This is a simplified implementation - full correction would involve
        // more complex geometric transformations

        return image // Return original for now
    }
}

// MARK: - Supporting Types

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didCaptureImage image: UIImage)
    func cameraViewController(_ controller: CameraViewController, didCaptureImages images: [UIImage])
    func cameraViewController(_ controller: CameraViewController, didFailWithError error: Error)
    func cameraViewControllerDidCancel(_ controller: CameraViewController)
}

enum CameraError: LocalizedError {
    case imageCreationFailed
    case cameraNotAvailable

    var errorDescription: String? {
        switch self {
        case .imageCreationFailed:
            return "Failed to create image from captured photo"
        case .cameraNotAvailable:
            return "Camera is not available"
        }
    }
}

// MARK: - Document Guides View

class DocumentGuidesView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [10, 5])

        // Draw document frame guides
        let guideRect = CGRect(
            x: rect.width * 0.1,
            y: rect.height * 0.2,
            width: rect.width * 0.8,
            height: rect.height * 0.6
        )

        context.addRect(guideRect)
        context.strokePath()

        // Draw corner guides
        let cornerLength: CGFloat = 30
        let corners = [
            guideRect.origin, // Top-left
            CGPoint(x: guideRect.maxX, y: guideRect.minY), // Top-right
            CGPoint(x: guideRect.maxX, y: guideRect.maxY), // Bottom-right
            CGPoint(x: guideRect.minX, y: guideRect.maxY)  // Bottom-left
        ]

        context.setLineDash(phase: 0, lengths: [])
        context.setLineWidth(3.0)

        for (index, corner) in corners.enumerated() {
            switch index {
            case 0: // Top-left
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x + cornerLength, y: corner.y))
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerLength))
            case 1: // Top-right
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x - cornerLength, y: corner.y))
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerLength))
            case 2: // Bottom-right
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x - cornerLength, y: corner.y))
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x, y: corner.y - cornerLength))
            case 3: // Bottom-left
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x + cornerLength, y: corner.y))
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x, y: corner.y - cornerLength))
            default:
                break
            }
        }

        context.strokePath()
    }
}

// MARK: - SwiftUI Representable

struct CameraView: UIViewControllerRepresentable {
    let configuration: CameraViewController.CameraConfiguration
    let onImageCaptured: (UIImage) -> Void
    let onImagesCaptured: ([UIImage]) -> Void
    let onError: (Error) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func cameraViewController(_ controller: CameraViewController, didCaptureImage image: UIImage) {
            parent.onImageCaptured(image)
        }

        func cameraViewController(_ controller: CameraViewController, didCaptureImages images: [UIImage]) {
            parent.onImagesCaptured(images)
        }

        func cameraViewController(_ controller: CameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }

        func cameraViewControllerDidCancel(_ controller: CameraViewController) {
            parent.onCancel()
        }
    }
}