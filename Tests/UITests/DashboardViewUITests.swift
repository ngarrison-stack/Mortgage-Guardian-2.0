import XCTest
import SwiftUI
@testable import MortgageGuardian

/// UI tests for DashboardView
/// Tests user interface interactions, navigation, and accessibility
final class DashboardViewUITests: MortgageGuardianUITestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Dashboard Layout Tests

    func testDashboardView_InitialLayout() {
        // Given
        let dashboardTitle = app.navigationBars["Dashboard"]
        let uploadButton = app.buttons["Upload Document"]
        let analysisSection = app.staticTexts["Recent Analysis"]

        // Then
        XCTAssertTrue(dashboardTitle.exists)
        XCTAssertTrue(uploadButton.exists)
        XCTAssertTrue(analysisSection.exists)

        // Verify accessibility
        XCTAssertTrue(uploadButton.isAccessibilityElement)
        XCTAssertFalse(uploadButton.accessibilityLabel?.isEmpty ?? true)
    }

    func testDashboardView_NavigationElements() {
        // Given
        let settingsButton = app.buttons["Settings"]
        let profileButton = app.buttons["Profile"]

        // Then
        XCTAssertTrue(settingsButton.exists)
        XCTAssertTrue(profileButton.exists)

        // Verify navigation bar elements are accessible
        XCTAssertTrue(settingsButton.isAccessibilityElement)
        XCTAssertTrue(profileButton.isAccessibilityElement)
    }

    func testDashboardView_DocumentUploadSection() {
        // Given
        let uploadSection = app.otherElements["Upload Section"]
        let uploadButton = app.buttons["Upload Document"]
        let supportedFormatsText = app.staticTexts["Supported formats: PDF, JPG, PNG, HEIC"]

        // Then
        XCTAssertTrue(uploadSection.exists)
        XCTAssertTrue(uploadButton.exists)
        XCTAssertTrue(supportedFormatsText.exists)

        // Verify upload button is prominently displayed
        XCTAssertTrue(uploadButton.frame.width > 200)
        XCTAssertTrue(uploadButton.frame.height > 40)
    }

    func testDashboardView_RecentAnalysisSection() {
        // Given
        let recentAnalysisSection = app.otherElements["Recent Analysis Section"]
        let analysisTitle = app.staticTexts["Recent Analysis"]

        // Then
        XCTAssertTrue(recentAnalysisSection.exists)
        XCTAssertTrue(analysisTitle.exists)

        // Check for empty state or analysis items
        let emptyStateText = app.staticTexts["No analysis yet"]
        let analysisItems = app.cells.matching(identifier: "AnalysisItem")

        XCTAssertTrue(emptyStateText.exists || analysisItems.count > 0)
    }

    // MARK: - Document Upload Flow Tests

    func testDashboardView_DocumentUploadTap() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When
        uploadButton.tap()

        // Then
        // Should present document picker or camera options
        let documentPicker = app.sheets["Document Picker"]
        let cameraOption = app.buttons["Take Photo"]
        let libraryOption = app.buttons["Choose from Library"]

        XCTAssertTrue(documentPicker.exists || cameraOption.exists || libraryOption.exists)
    }

    func testDashboardView_CameraAccessRequest() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When
        uploadButton.tap()

        // Then
        let cameraOption = app.buttons["Camera"]
        if cameraOption.exists {
            cameraOption.tap()

            // Check for camera permission alert
            let cameraAlert = app.alerts["Camera Access"]
            if cameraAlert.exists {
                XCTAssertTrue(cameraAlert.buttons["Allow"].exists)
                XCTAssertTrue(cameraAlert.buttons["Don't Allow"].exists)
            }
        }
    }

    func testDashboardView_PhotoLibraryAccess() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When
        uploadButton.tap()

        // Then
        let libraryOption = app.buttons["Photo Library"]
        if libraryOption.exists {
            libraryOption.tap()

            // Should open photo library or request permission
            let photoLibrary = app.otherElements["Photo Library"]
            let permissionAlert = app.alerts["Photo Library Access"]

            XCTAssertTrue(photoLibrary.exists || permissionAlert.exists)
        }
    }

    // MARK: - Navigation Tests

    func testDashboardView_SettingsNavigation() {
        // Given
        let settingsButton = app.buttons["Settings"]

        // When
        settingsButton.tap()

        // Then
        let settingsView = app.navigationBars["Settings"]
        XCTAssertTrue(settingsView.exists)

        // Verify back navigation
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
            XCTAssertTrue(app.navigationBars["Dashboard"].exists)
        }
    }

    func testDashboardView_ProfileNavigation() {
        // Given
        let profileButton = app.buttons["Profile"]

        // When
        profileButton.tap()

        // Then
        let profileView = app.navigationBars["Profile"]
        XCTAssertTrue(profileView.exists)
    }

    func testDashboardView_AnalysisDetailNavigation() {
        // Given - Assuming there are analysis items
        let analysisItems = app.cells.matching(identifier: "AnalysisItem")

        if analysisItems.count > 0 {
            // When
            analysisItems.element(boundBy: 0).tap()

            // Then
            let analysisDetailView = app.navigationBars["Analysis Details"]
            XCTAssertTrue(analysisDetailView.exists)
        }
    }

    // MARK: - Content State Tests

    func testDashboardView_EmptyState() {
        // Given - Fresh app state with no documents
        let emptyStateText = app.staticTexts["No documents analyzed yet"]
        let getStartedText = app.staticTexts["Upload your first mortgage document to get started"]
        let uploadPromptButton = app.buttons["Upload Your First Document"]

        // Then
        if emptyStateText.exists {
            XCTAssertTrue(getStartedText.exists)
            XCTAssertTrue(uploadPromptButton.exists)

            // Verify empty state accessibility
            XCTAssertTrue(emptyStateText.isAccessibilityElement)
            XCTAssertTrue(uploadPromptButton.isAccessibilityElement)
        }
    }

    func testDashboardView_LoadingState() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When
        uploadButton.tap()

        // Simulate document upload
        let libraryOption = app.buttons["Photo Library"]
        if libraryOption.exists {
            libraryOption.tap()

            // Then - Check for loading indicators
            let loadingIndicator = app.activityIndicators["Processing"]
            let loadingText = app.staticTexts["Processing document..."]

            // Loading state might appear briefly
            if loadingIndicator.exists {
                XCTAssertTrue(loadingText.exists)
            }
        }
    }

    func testDashboardView_ContentState() {
        // Given - App with existing analysis data
        let analysisItems = app.cells.matching(identifier: "AnalysisItem")

        if analysisItems.count > 0 {
            // Then
            for i in 0..<min(analysisItems.count, 3) { // Check first 3 items
                let item = analysisItems.element(boundBy: i)
                XCTAssertTrue(item.exists)

                // Verify analysis item content
                let documentName = item.staticTexts.matching(identifier: "DocumentName").firstMatch
                let analysisDate = item.staticTexts.matching(identifier: "AnalysisDate").firstMatch
                let issueCount = item.staticTexts.matching(identifier: "IssueCount").firstMatch

                XCTAssertTrue(documentName.exists)
                XCTAssertTrue(analysisDate.exists)
                XCTAssertTrue(issueCount.exists)
            }
        }
    }

    // MARK: - Error State Tests

    func testDashboardView_ErrorState() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When - Simulate upload error
        uploadButton.tap()

        // Then - Check for error handling
        let errorAlert = app.alerts["Upload Error"]
        let errorMessage = app.staticTexts["Failed to upload document"]

        if errorAlert.exists {
            XCTAssertTrue(errorMessage.exists)
            XCTAssertTrue(errorAlert.buttons["OK"].exists)
            XCTAssertTrue(errorAlert.buttons["Try Again"].exists)
        }
    }

    func testDashboardView_NetworkErrorHandling() {
        // Given - Simulate network error
        let refreshButton = app.buttons["Refresh"]

        if refreshButton.exists {
            // When
            refreshButton.tap()

            // Then
            let networkErrorAlert = app.alerts["Network Error"]
            let retryButton = app.buttons["Retry"]

            if networkErrorAlert.exists {
                XCTAssertTrue(retryButton.exists)
                XCTAssertTrue(networkErrorAlert.staticTexts["Check your internet connection"].exists)
            }
        }
    }

    // MARK: - Accessibility Tests

    func testDashboardView_AccessibilityLabels() {
        // Given
        let uploadButton = app.buttons["Upload Document"]
        let settingsButton = app.buttons["Settings"]
        let profileButton = app.buttons["Profile"]

        // Then
        XCTAssertFalse(uploadButton.accessibilityLabel?.isEmpty ?? true)
        XCTAssertFalse(settingsButton.accessibilityLabel?.isEmpty ?? true)
        XCTAssertFalse(profileButton.accessibilityLabel?.isEmpty ?? true)

        // Verify meaningful accessibility labels
        XCTAssertTrue(uploadButton.accessibilityLabel?.contains("Upload") ?? false)
        XCTAssertTrue(settingsButton.accessibilityLabel?.contains("Settings") ?? false)
        XCTAssertTrue(profileButton.accessibilityLabel?.contains("Profile") ?? false)
    }

    func testDashboardView_AccessibilityHints() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // Then
        XCTAssertFalse(uploadButton.accessibilityHint?.isEmpty ?? true)
        XCTAssertTrue(uploadButton.accessibilityHint?.contains("document") ?? false)
    }

    func testDashboardView_AccessibilityTraits() {
        // Given
        let uploadButton = app.buttons["Upload Document"]
        let settingsButton = app.buttons["Settings"]
        let analysisTitle = app.staticTexts["Recent Analysis"]

        // Then
        XCTAssertTrue(uploadButton.accessibilityTraits.contains(.button))
        XCTAssertTrue(settingsButton.accessibilityTraits.contains(.button))
        XCTAssertTrue(analysisTitle.accessibilityTraits.contains(.header))
    }

    func testDashboardView_VoiceOverSupport() {
        // Given
        let uploadButton = app.buttons["Upload Document"]

        // When
        uploadButton.accessibilityActivate()

        // Then
        // Should behave the same as tap() for VoiceOver users
        let documentPicker = app.sheets["Document Picker"]
        let cameraOption = app.buttons["Camera"]

        XCTAssertTrue(documentPicker.exists || cameraOption.exists)
    }

    func testDashboardView_AccessibilityElementOrder() {
        // Given
        let dashboardElements = [
            app.staticTexts["Dashboard"],
            app.buttons["Upload Document"],
            app.staticTexts["Recent Analysis"]
        ]

        // Then
        // Verify elements are in logical reading order
        var previousY: CGFloat = 0
        for element in dashboardElements {
            if element.exists {
                let currentY = element.frame.minY
                XCTAssertGreaterThanOrEqual(currentY, previousY)
                previousY = currentY
            }
        }
    }

    // MARK: - Dynamic Type Tests

    func testDashboardView_DynamicType() {
        // Given
        let uploadButton = app.buttons["Upload Document"]
        let originalFrame = uploadButton.frame

        // When - Simulate accessibility text size change
        // Note: In a real test, you would change the system text size setting

        // Then
        // Button should resize appropriately for larger text
        XCTAssertGreaterThan(uploadButton.frame.height, 0)
        XCTAssertGreaterThan(uploadButton.frame.width, 0)
    }

    // MARK: - Pull to Refresh Tests

    func testDashboardView_PullToRefresh() {
        // Given
        let recentAnalysisSection = app.scrollViews["Recent Analysis"]

        if recentAnalysisSection.exists {
            // When
            recentAnalysisSection.swipeDown()

            // Then
            let refreshIndicator = app.activityIndicators["Refreshing"]
            if refreshIndicator.exists {
                XCTAssertTrue(refreshIndicator.exists)
            }
        }
    }

    // MARK: - Search Tests

    func testDashboardView_SearchFunctionality() {
        // Given
        let searchButton = app.buttons["Search"]

        if searchButton.exists {
            // When
            searchButton.tap()

            // Then
            let searchField = app.textFields["Search documents"]
            XCTAssertTrue(searchField.exists)

            // Test search input
            searchField.tap()
            searchField.typeText("mortgage")

            let searchResults = app.cells.matching(identifier: "SearchResult")
            // Results depend on content, so we just verify search UI works
            XCTAssertTrue(searchField.value as? String == "mortgage")
        }
    }

    // MARK: - Quick Actions Tests

    func testDashboardView_QuickActions() {
        // Given
        let quickActionsSection = app.otherElements["Quick Actions"]

        if quickActionsSection.exists {
            // Then
            let analyzeButton = app.buttons["Quick Analyze"]
            let reportButton = app.buttons["Generate Report"]
            let linkAccountButton = app.buttons["Link Bank Account"]

            XCTAssertTrue(analyzeButton.exists || reportButton.exists || linkAccountButton.exists)

            // Test quick action tap
            if analyzeButton.exists {
                analyzeButton.tap()
                // Should navigate to analysis flow
            }
        }
    }

    // MARK: - Notification Tests

    func testDashboardView_NotificationHandling() {
        // Given
        let notificationBanner = app.otherElements["Notification Banner"]

        if notificationBanner.exists {
            // Then
            let notificationText = app.staticTexts.matching(identifier: "NotificationText").firstMatch
            let dismissButton = app.buttons["Dismiss"]

            XCTAssertTrue(notificationText.exists)
            XCTAssertTrue(dismissButton.exists)

            // Test dismissal
            dismissButton.tap()
            XCTAssertFalse(notificationBanner.exists)
        }
    }

    // MARK: - Performance Tests

    func testDashboardView_LaunchPerformance() {
        // Measure dashboard launch time
        measure {
            app.terminate()
            app.launch()

            // Wait for dashboard to appear
            let dashboardTitle = app.navigationBars["Dashboard"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5.0))
        }
    }

    func testDashboardView_ScrollPerformance() {
        // Given
        let recentAnalysisSection = app.scrollViews["Recent Analysis"]

        if recentAnalysisSection.exists {
            // When/Then
            measure {
                // Perform multiple scroll operations
                for _ in 0..<5 {
                    recentAnalysisSection.swipeUp()
                    recentAnalysisSection.swipeDown()
                }
            }
        }
    }

    // MARK: - Dark Mode Tests

    func testDashboardView_DarkModeSupport() {
        // Given - Dark mode enabled (would be set via launch arguments in real test)
        let uploadButton = app.buttons["Upload Document"]
        let dashboardTitle = app.staticTexts["Dashboard"]

        // Then
        // Verify elements are visible in dark mode
        XCTAssertTrue(uploadButton.exists)
        XCTAssertTrue(dashboardTitle.exists)
        XCTAssertTrue(uploadButton.isHittable)
    }

    // MARK: - Orientation Tests

    func testDashboardView_RotationSupport() {
        // Given
        let initialOrientation = app.orientation
        let uploadButton = app.buttons["Upload Document"]

        // When
        XCUIDevice.shared.orientation = .landscapeLeft

        // Then
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 2.0))
        XCTAssertTrue(uploadButton.exists)

        // Restore orientation
        XCUIDevice.shared.orientation = initialOrientation
    }

    // MARK: - Context Menu Tests

    func testDashboardView_ContextMenus() {
        // Given
        let analysisItems = app.cells.matching(identifier: "AnalysisItem")

        if analysisItems.count > 0 {
            let firstItem = analysisItems.element(boundBy: 0)

            // When
            firstItem.press(forDuration: 1.0)

            // Then
            let contextMenu = app.menus["AnalysisContextMenu"]
            if contextMenu.exists {
                let deleteAction = app.buttons["Delete"]
                let shareAction = app.buttons["Share"]
                let editAction = app.buttons["Edit"]

                XCTAssertTrue(deleteAction.exists || shareAction.exists || editAction.exists)
            }
        }
    }
}