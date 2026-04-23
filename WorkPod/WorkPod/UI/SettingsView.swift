import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("设置")
                .font(.title)
                .padding(.bottom)
            
            Text("欢迎使用 WorkPod!")
                .padding()
            
            Divider()
            
            Text("功能设置")
                .font(.headline)
                .padding(.top)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
