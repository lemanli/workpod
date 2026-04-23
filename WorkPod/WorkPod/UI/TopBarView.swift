import SwiftUI

struct TopBarView: View {
    @ObservedObject var cockpitManager = CockpitManager.shared
    
    var body: some View {
        if let activeId = cockpitManager.activeCockpitId,
           let cockpit = cockpitManager.cockpit(with: activeId) {
            HStack(spacing: 15) {
                // Cockpit Name & Icon
                HStack {
                    Image(systemName: cockpit.icon ?? "square.grid.2x2")
                        .foregroundColor(.blue)
                    Text(cockpit.name)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Divider().frame(height: 15)
                
                // Member List
                HStack(spacing: 10) {
                    ForEach(cockpit.members) { member in
                        MemberButton(member: member)
                    }
                }
                
                Spacer()
                
                // Quick Status / Close
                Button(action: {
                    cockpitManager.deactivateCockpit(id: activeId)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(5)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .frame(height: 40)
        } else {
            EmptyView()
        }
    }
}

struct MemberButton: View {
    let member: Member
    @ObservedObject var cockpitManager = CockpitManager.shared
    
    var body: some View {
        Button(action: {
            WindowManager.shared.bringToFront(bundleId: member.bundleId, token: CockpitManager.shared.activationToken)
        }) {
            Text(member.name)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
