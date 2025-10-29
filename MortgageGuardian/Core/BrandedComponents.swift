import SwiftUI

// MARK: - Input Fields
struct BrandedTextField: View {
    let title: String
    let text: Binding<String>
    let icon: String
    
    init(_ title: String, text: Binding<String>, icon: String) {
        self.title = title
        self.text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.Colors.light.primary)
            TextField(title, text: text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

// MARK: - Buttons
struct BrandedButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
    }
    
    init(_ title: String, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundForStyle)
                .foregroundStyle(foregroundForStyle)
                .cornerRadius(AppTheme.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .stroke(style == .outline ? AppTheme.Colors.light.primary : .clear, lineWidth: 2)
                )
        }
    }
    
    private var backgroundForStyle: some ShapeStyle {
        switch style {
        case .primary:
            AppTheme.Colors.light.gradient
        case .secondary:
            AppTheme.Colors.light.surface
        case .outline:
            .clear
        }
    }
    
    private var foregroundForStyle: Color {
        switch style {
        case .primary:
            .white
        case .secondary, .outline:
            AppTheme.Colors.light.primary
        }
    }
}

// MARK: - Cards
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.Colors.light.primary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.light.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

// MARK: - List Items
struct ScenarioListItem: View {
    let title: String
    let subtitle: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppTheme.Colors.light.gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "house.fill")
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.light.primary)
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

// MARK: - Navigation Items
struct NavigationRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.Colors.light.primary)
                    .frame(width: 30)
                
                Text(title)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(AppTheme.Colors.light.surface)
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }
}