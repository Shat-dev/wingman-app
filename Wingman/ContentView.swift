import SwiftUI


struct ContentView: View {
    
    // MARK: - Dummy onboarding data (you will replace later)
    let pages = [
        LandingModel(title: "Stop Overthinking, Start Approaching",
                       description: "Build the confidence to talk to strangers naturally without letting fear hold you back.",
                       imageName: "wingman_logo"),
        
        LandingModel(title: "Turn anxiety into action",
                       description: "Daily practice and real-world tracking help you approach more and worry less.",
                       imageName: "wingman_logo"),
        
        LandingModel(title: "Learn what actually works",
                       description: "Master mindset, approach mechanics, and conversation skills step-by-step.",
                       imageName: "wingman_logo"),
        
        LandingModel(title: "Track your progress Stay consistent",
                       description: "Log every attempt  and watch your confidence grow with real data.",
                       imageName: "wingman_logo")
    ]
    
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 25) {
                        
                        Spacer().frame(height: 30)
                        
                        // MARK: - Title + Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pages[index].title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.wingmanBlack)
                            
                            Text(pages[index].description)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.trailing, 20)
                        }
                        .padding(.horizontal, 24)
                        
                        // MARK: - Image
                        Image(pages[index].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 260)
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // hide default dots
            
            // MARK: Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.wingmanBlack : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            
            
            // MARK: Buttons Section
            VStack(spacing: 16) {
                
                Button(action: {
                    print("Create Account tapped")
                }) {
                    Text("Create Account")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.wingmanBlack)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    print("Log In tapped")
                }) {
                    Text("Log In")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.wingmanBlack)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            
            // MARK: Skip Button
            Button(action: {
                print("Skip tapped")
            }) {
                Text("Skip for now")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            }
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
