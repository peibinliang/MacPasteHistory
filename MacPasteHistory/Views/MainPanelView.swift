import SwiftUI

struct MainPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clipboard History")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Project foundation is ready. Clipboard history features will be implemented in later changes.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}
