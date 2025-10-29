import SwiftUI

struct BrandedHeader: View {
    let title: String
    let showLogo: Bool
    
    init(_ title: String, showLogo: Bool = true) {
        self.title = title
        self.showLogo = showLogo
    }
    
    var body: some View {
        HStack {
            if showLogo {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            }
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.darkBlue)
            
            Spacer()
        }
        .padding()
        .background(
            AppTheme.gradient
                .opacity(0.1)
        )
    }
}