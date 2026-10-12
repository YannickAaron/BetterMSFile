import Foundation
@testable import Meta
import SampleBackends

@main
struct TestExecutable {

    public static func main() {
        DemoApp.main()
        RunLoop.main.run(until: .now.addingTimeInterval(3))
    }

}

struct DemoApp: App {

    // #if os(...)
    var app = Backend1.Backend1App()
    // #else
    // var app = Backend2.Backend2App()
    // #endif

    var scene: Scene {
        Backend1.Window("main", spawn: 1) {
            DemoView(app: app)
                .environment("test", data: 5)
        }
    }

}

struct DemoView: View {

    @State private var model = TestModel()
    @Environment("test")
    private var test: Int?
    var app: any AppStorage
    let condition = false

    var view: Body {
        if condition {
            Backend1.TestWidget1()
        } else {
            Backend1.TestWidget3()
        }
        Backend1.Wrapper {
            Backend1.Button(model.test) {
                Task {
                    model.updateAsync()
                    app.addSceneElement("main")
                }
            }
            .onAppear { print(test ?? 0) }
        }
        TestView()
        testContent
     }

     @ViewBuilder
     var testContent: Body {
        Backend2.TestWidget2()
        Backend1.TestWidget3()
     }

}

struct TestView: View {

    @State private var test = "Label"

    var view: Body {
        Backend2.TestWidget4()
        Backend1.Button(test) {
            test = "Directly use state"
        }
    }

}

struct TestModel: Model {

    var test = "Label"

    var model: ModelData?

    func updateAsync() {
        Task {
            // Do something
            setModel { $0.test = "\(Int.random(in: 1...10))" }
        }
    }

}
