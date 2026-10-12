# Create a Backend

Learn how to implement a backend.

## Overview

In this tutorial, [TermKitBackend](https://git.aparoksha.dev/david-swift/term-kit-backend) will be used as a sample backend to explain the elements of a backend.
General information can be found in the <doc:Backends> article.

## Package Manifest

Set up a new Swift Package (`swift package init`).
Add the _Meta_ package as well as other dependencies if required to the dependencies section in the manifest.

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TermKitBackend",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "TermKitBackend",
            targets: ["TermKitBackend"]
        )
    ],
    dependencies: [
        .package(url: "https://git.aparoksha.dev/aparoksha/meta", from: "0.1.0"),
        .package(url: "https://github.com/david-swift/TermKit", branch: "main")
    ],
    targets: [
        .target(
            name: "TermKitBackend",
            dependencies: [
                "TermKit",
                .product(name: "Meta", package: "meta")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
```

## Backend-Specific Scene Type

An app can contain scenes from multiple backends. To determine which scenes to render, a backend-specific scene protocol is required.
Simply create a protocol which conforms to the ``SceneElement`` protocol.

```swift
// TermKitSceneElement.swift

import Meta

public protocol TermKitSceneElement: SceneElement { }
```

## The App Storage

When creating an app, the backend is selected via the app storage (more information under <doc:CreateApp>).
Furthermore, it offers functions that allow the user to quit the app (``AppStorage/quit()``) and manage which scene elements (often windows) are visible (``AppStorage/addSceneElement(_:)`` or ``AppStorage/addWindow(_:)``, ``AppStorage/showSceneElement(_:)`` or ``AppStorage/showWindow(_:)``).

The ``AppStorage/run(setup:)`` method is used by the Meta framework to execute the application, where the `setup` parameter is a closure initializing the scene elements in the app's ``App/scene`` property, based on the initial setup function of your scene elements.
Creating scene elements will be covered later in this article.

Store additional properties in the app storage. You can fetch the data for the additional properties via the initializer of the app storage (such as the app's identifier).
The ``AppStorage/storage`` stores a standard app storage which has to be the same in every backend.

Add a typealias defining the ``AppStorage/SceneElementType`` to be the backend-specific scene type.

```swift
// TermKitApp.swift

@_exported import Meta // Export the Meta framework (only required in one file)
import TermKit

public class TermKitApp: AppStorage {

    public typealias SceneElementType = TermKitSceneElement

    public var storage: StandardAppStorage = .init()

    public init() { } // Optionally, fetch additional data

    public func run(setup: @escaping () -> Void) {
        Application.prepare()
        setup() // Always call the setup closure in the run function
        Application.run()
    }

    public func quit() {
        Application.shutdown()
    }

}
```

## Create a Scene Element

Each backend defines one or multiple scene elements.
A scene element is anything one level below the application.
Windows are a common type of scene elements, but there may be other types such as the menu bar on macOS.

Scene elements are structures conforming to ``SceneElement``.
Note that for elements where multiple copies of one type of scene element are _possible_, such as windows, the scene element represents the _type_ of elements, not the individual elements.
Add individual copies via the previously mentioned functions on app storages.

```swift
// Window.swift

import TermKit

public struct Window: TermKitSceneElement { // Use the backend-specific scene element type

    public var id: String

// ...
```

``SceneElement/id`` is an identifier which uniquely identifies the _type_ of scene element. For instance, use an identifier "main" which represents main windows.

```swift
// ...

    var title: String?
    var content: Body

// ...
```

Those are additional properties required for initializing the scene elements. Common examples are a title displayed in a window's title bar and the window's content.

```swift
// ...

    public init(_ title: String? = nil, id: String = "main", @ViewBuilder content: () -> Body) { // @ViewBuilder enables the DSL to be used
        self.id = id
        self.title = title
        self.content = content()
    }

// ...
```

A public initializer providing the properties with data.

```swift
// ...

    public func setupInitialContainers<Storage>(app: Storage) where Storage: AppStorage {
        app.storage.sceneStorage.append(container(app: app))
    }

// ...
```

The function ``SceneElement/setupInitialContainers(app:)`` is responsible for creating a certain amount of initial instances of the scene element.
By convention, if sensible, create one element if no further information is provided, but let the user specify the number in the initializer or via a modifier.
Append the scene element's container to the scene storage of the app object.

In this example, the number of instances cannot be customized as creating additional windows is not supported.

```swift
// ...

    public func container<Storage>(app: Storage) -> SceneStorage where Storage: AppStorage {
        let win = TermKit.Window(title)
        win.fill()
        Application.top.addSubview(win)
        let storage = SceneStorage(id: id, pointer: win) {
            win.ensureFocus()
        }
        let viewStorage = content.storage(
            data: .init(sceneStorage: storage, appStorage: app),
            type: TermKitMainView.self
        )
        if let pointer = viewStorage.pointer as? TermKit.View {
            win.addSubview(pointer)
        }
        storage.content = [.mainContent: [viewStorage]]
        return storage
    }

// ...
```

Scene elements as well as widgets are based on two functions: a function for creating a new instance of the element, and a function for updating a certain instance of an element.

For scene elements, the function for creating an instance is called ``SceneElement/container(app:)``.

First, create the instance in the imperative framework (I will refer to it as the native representation).
Store the identifier and the native representation (``SceneStorage/pointer``) as well as a function which presents the scene element in a new ``SceneStorage`` object.

In most frameworks, you have to get a single native representation for the whole content view of a certain scene element or widget.
Whenever this is required, store a property of the type ``Body`` and initialize using the ``AnyView/storage(data:type:)`` type.
When working with views, you have to pass the backend-specific widget type to the methods. More information on working with widgets under [Widgets](#Widgets).
Store view storages in the scene storage (preferably via ``SceneStorage/content``) to access the storages when updating the view.

```swift
// ...

    public func update<Storage>(
        _ storage: SceneStorage,
        app: Storage,
        updateProperties: Bool
    ) where Storage: AppStorage {
        guard let viewStorage = storage.content[.mainContent]?.first else {
            return
        }
        content
            .updateStorage(
                viewStorage,
                data: .init(sceneStorage: storage, appStorage: app),
                updateProperties: updateProperties,
                type: TermKitMainView.self
            )
        /*
        // Update additional properties
        guard updateProperties else {
            return
        }
        let previousState = storage.previousState as? Self
        if previousState?.property != property { // Only if equatable
            nativeRepresentation.doSomething(basedOn: property) // Update the native representation
        }
        */
        Application.refresh()
    }

```

In this case, there is only one property which can be modified after creating the widget: the content.
Get the view storage from the scene storage and update the view using ``AnyView/updateStorage(_:data:updateProperties:type:)``.

For properties in general (in scene elements and widgets), follow two simple rules:

- Update properties in the native representation only if the `updateProperties` parameter is `true`. If state has changed in a parent view, this property will be set to `true`, otherwise, there is nothing to update. Furthermore, if (and only if) the type of the property is equatable, check whether the value has actually changed before updating.
- An exception are views: always update views when the parent widget or scene element gets updated. The reason is that child views are able to hold state properties themselves, even though parent views do not know about the change in the state values.

## Widgets

Widgets are the basic building blocks of all the elements a scene element can hold.
This includes classic views (such as buttons, text fields, etc.) as well as more limited views (such as menus).

Similarly to the backend-specific scene element protocol, create a view-type-specific protocol conforming to ``Widget`` (e.g. one for "regular" views, one for menus, etc.).

```swift
// TermKitWidget.swift

public protocol TermKitWidget: Widget { }
```

The widget type (``TermKitMainView/WidgetType``) is not enough for working with view types.
Each view type has to provide two special views (usually widgets):

- ``ViewRenderData/WrapperType`` is a type which is used when multiple views are used in a view body without explicitly specifying the container. If there is only a single element, it usually returns that element, otherwise, it usually aligns the elements vertically.
- ``ViewRenderData/EitherViewType`` allows Swift's `if`/`else` syntax to be used inside the bodies. While calling an either view widget like any other widget would work, Swift's `if`/`else` syntax allows more advanced syntax such as unwrapping optionals.

### The Wrapper Widget

Let's create the wrapper type first. This illustrates the process of creating complex widgets. For simpler widgets, there is a more concise syntax available.

We will call the container type `VStack`. This is dervied from SwiftUI and aligns the elements vertically.

```swift
// VStack.swift

import TermKit

public struct VStack: Wrapper, TermKitWidget {

    var content: Body

    public init(@ViewBuilder content: @escaping () -> Body) {
        self.content = content()
    }

// ...
```

A wrapper type has to conform to the ``Wrapper`` protocol.
The only requirement of this protocol is the ``Wrapper/init(content:)`` initializer.

Each widget conforms to the backend-specific widget protocol. As with scene elements, a widget can store "regular" properties as well as view bodies.

```swift
// ...

    public func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        let storages = content.storages(data: data, type: type)
        if storages.count == 1 {
            return .init(storages[0].pointer, content: [.mainContent: storages])
        }
        let view = View()
        for (index, storage) in storages.enumerated() {
            if let pointer = storage.pointer as? TermKit.View {
                view.addSubview(pointer)
                if let previous = (storages[safe: index - 1]?.pointer as? TermKit.View) {
                    pointer.y = .bottom(of: previous)
                }
            }
        }
        return .init(view, content: [.mainContent: storages])
    }

// ...
```

The ``Widget/container(data:type:)`` method is the equivalent to ``SceneElement/container(app:)`` for widgets.
Initialize the native representation.

This is a very complex container function. The reason is that the wrapper is not allowed to use the convenience [storage](https://meta.aparoksha.dev/documentation/meta/anyview/storage(data:type:))
function as this method uses the container widget to "combine" multiple views. Therefore, it is important to add the individual views to the native representation.
If there is only one item (note that this is checked via `storages`, not via the `content` property, as there might be items from other backends), return this item instead.

Store the storages for child views in the view storage's `content` property. You will access it in the updating function to update the content.

```swift
// ...

    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        guard let storages = storage.content[.mainContent] else {
            return
        }
        content.update(storages, data: data, updateProperties: updateProperties, type: type)
    }
}
```

In the update function, the storages are updated based on the current state of the content.

### The Either View

The either view allows standard Swift `if`/`else` syntax to be used in a view body.

```swift
// EitherView.swift

import TermKit

public struct EitherView: TermKitWidget, Meta.EitherView {

    var condition: Bool
    var view1: Body
    var view2: Body

    public init(_ condition: Bool, @ViewBuilder view1: () -> Body, @ViewBuilder else view2: () -> Body) {
        self.condition = condition
        self.view1 = view1()
        self.view2 = view2()
    }

// ...
```

As always, store relevant properties in the widget.
For the ``EitherView``, it is again the initializer that has to match a requirement (``EitherView/init(_:view1:else:)``).

```swift
// ...

    public func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        let view = TermKit.View()
        return .init(view)
    }

// ...
```

The either view has a quite complicated structure as well (it will get way easier for "normal" widgets, I promise).
Normally, you would initialize all your content storages in the container function (as in the wrapper widget).
In this case, this does not work. If the either view is called via standard `if`/`else` syntax and the condition is `true`,
we can access `view1`, but `view2` is empty (the actual view is not known). If `condition` is `false`, `view1` is empty and `view2` is known.
Therefore, we have to wait with the initialization process until `condition` changes, which is why this is handled in the `update` function.
Make sure to call the child view's `update` function after constructing a view in the parent view's `update` function.

```swift
// ...

    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        guard let parent = storage.pointer as? TermKit.View else {
            return
        }
        let view: TermKit.View?
        let body = condition ? view1 : view2
        if let content = storage.content[condition.description]?.first {
            body.updateStorage(content, data: data, updateProperties: updateProperties, type: type)
            view = content.pointer as? TermKit.View
        } else {
            let content = body.storage(data: data, type: type)
            body.update(content, data: data, updateProperties: true, type: type)
            storage.content[condition.description] = [content]
            view = content.pointer as? TermKit.View
        }
        if let view, (storage.previousState as? Self)?.condition != condition {
            parent.removeAllSubviews()
            parent.addSubview(view)
        }
        storage.previousState = self
    }

}

```

If the storage for the current condition has already been initialized, this method calls the children's update function.
Otherwise, it is initialized. Here, you can see how the convenient ``AnyView/storage(data:type:)`` and ``AnyView/updateStorage(_:data:updateProperties:type:)`` is being used for this.

Assign the correct view to the native representation of the either view if the condition has changed.

### The View Render Data

Each view context (regular views, menus, etc.) has its own view render data type. You could already see it passed to widgets as the `type` parameter.
This allows widgets to behave differently based on the context (in case this is required). Don't forget to make the widget conform to the widget protocol of all the view contexts it supports!

Let's create the view context type for our main view context:

```swift
// TermKitMainView.swift

public enum TermKitMainView: ViewRenderData {

    public typealias WidgetType = TermKitWidget
    public typealias WrapperType = VStack
    public typealias EitherViewType = EitherView

}
```

### A Regular Widget

Regular widgets are much simpler to implement. Here, we will implement a simple label widget.

While one could use the `container`/`update` methods to implement any widgets, for most wigdets, it might be more sensible to use a more declarative approach.
One can set the ``Widget/initializeWidget()-9ut4i`` function instead and mark the properties as widget properties with the following property wrappers:

- ``ViewProperty`` for child views
- ``BindingProperty`` for bindings (see <doc:StateConcept>)
- ``Property`` for other properties (labels, closures, etc.)

First, create the widget's structure without any backend logic:

```swift
// Label.swift

import TermKit

public struct Label: TermKitWidget {

    var label: String

    public init(_ label: String) {
        self.label = label
    }

}
```

Then, create a method for initializing the native representation.

```swift
// Label.swift

import TermKit

public struct Label: TermKitWidget {

    var label: String

    public init(_ label: String) {
        self.label = label
    }

    public func initializeWidget() -> Any {
        TermKit.Label(label) // You woudn't set properties here usually, but the label initializer needs a label already
    }

}
```

Now, mark the `label` property with the ``Property`` property wrapper to provide a closure for "translating" the declarative representation into an imperative program.

```swift
// Label.swift

import TermKit

public struct Label: TermKitWidget {

    @Property(set: { $0.text = $1 }, pointer: TermKit.Label.self) // This is a property
    var label = ""

    public init(_ label: String) {
        self.label = label
    }

    public func initializeWidget() -> Any {
        TermKit.Label(label)
    }

}
```

This is already a functioning label widget!

### The Binding Property Wrapper

Whenever a property needs to allow two-way traffic (let the parent view as well as the widget itself modify the property), use a ``Binding``.

```swift
// Checkbox.swift

import TermKit

public struct Checkbox: TermKitWidget {

    @Property(set: { $0.text = $1 }, pointer: TermKit.Checkbox.self)
    var label: String
    var isOn: Binding<Bool> // The binding property

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public func initializeWidget() -> Any {
        TermKit.Label(label)
    }

}
```

The ``BindingProperty`` initializer accepts two closures.

The first one, `observe`, is called when setting up the widget (in the `container` method), and should connect the binding to a callback.
The second one, `set`, is equivalent to the closure with the same name for ``Property``.

```swift
// Checkbox.swift

import TermKit

public struct Checkbox: TermKitWidget {

    @Property(set: { $0.text = $1 }, pointer: TermKit.Checkbox.self)
    var label: String
    @BindingProperty(
        observe: { box, value in box.toggled = { value.wrappedValue = $0.checked } },
        set: { $0.checked = $1 },
        pointer: TermKit.Checkbox.self
    )
    var isOn: Binding<Bool>

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public func initializeWidget() -> Any {
        TermKit.Label(label)
    }

}
```

### View Properties

View properties are properties of the type ``Body``.
The `set` closure will be called only in the `container` method.

```swift
/// Frame.swift

import TermKit

public struct Frame: TermKitWidget {

    @ViewProperty(
        set: { $0.addSubview($1) },
        pointer: TermKit.Frame.self,
        subview: TermKit.View.self,
        context: MainViewContext.self
    )
    var view: Body

    public init(@ViewBuilder content: @escaping () -> Body) { // Use the view builder
        self.view = content()
    }

    public func initializeWidget() -> Any {
        TermKit.Frame()
    }

}

```

Define the type of the view context with the `context` property.

Remember not to use this property wrapper in the wrapper widget.

### Complex Widgets

More complex widgets (we have already created the two "special" widgets, the wrapper and either view widget, using this method)
should be created using the ``Widget/container(data:type:)`` and ``Widget/update(_:data:updateProperties:type:)`` methods.

## Create Apps

Now that you have a backend with some scene elements and widgets, learn how to create an app under <doc:CreateApp>.

Find other backends on the [Aparoksha website](https://www.aparoksha.dev/backends/) or [forums](https://forums.aparoksha.dev/t/projects).

