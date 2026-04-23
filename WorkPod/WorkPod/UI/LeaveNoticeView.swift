import SwiftUI

struct LeaveNoticeView: View {
    @EnvironmentObject var cockpitManager: CockpitManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("已离开工作舱区域")
                    .fontWeight(.medium)
            }
            
            Text("您当前不在工作舱成员应用中")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack {
                Button("返回工作舱") {
                    // Logic to bring the primary member to front
                    if let activeId = cockpitManager.activeCockpitId,
                       let cockpit = cockpitManager.cockpit(with: activeId),
                       let primary = cockpit.members.first {
                        WindowManager.shared.bringToFront(bundleId: primary.bundleId, token: CockpitManager.shared.activationToken)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("忽略") {
                    cockpitManager.isLeavingCockpit = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .cornerRadius(16)
        .shadow(radius: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
