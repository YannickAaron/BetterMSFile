//
//  WrapBoxDemo.swift
//  Adwaita
//
//  Created by desbeers on 07.08.26.
//

// swiftlint:disable missing_docs

import Adwaita
import Foundation

struct WrapBoxDemo: View {

    static var item: Element {
        // swiftlint:disable:next line_length
        let loremIpsum = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua"
        let words = loremIpsum.split(separator: " ").shuffled().prefix(Int.random(in: 1...4))
        return Element(content: words.joined(separator: " "))
    }

    @State private var items: [Element] = (0..<10).map { _ in item }

    var view: Body {
        WrapBox(items) { item in
            HStack {
                if item == items.last {
                    Button(icon: .default(icon: .listAdd)) {
                        items.append(Self.item)
                    }
                    .suggested()
                    .circular()
                } else {
                    HStack {
                        Text("\(item.content)")
                            .padding(.leading)
                        Button(icon: .default(icon: .windowClose)) {
                            items = items.filter { $0.id != item.id }
                        }
                        .flat()
                        .circular()
                    }
                    .card()
                    .style("wrap-item")
                    .css {
                        """
                        .wrap-item {
                            border-radius: 999px;
                        }
                        """
                    }
                }
            }
        }
        .lineSpacing(6)
        .childSpacing(6)
        .halign(.center)
    }

    struct Element: Identifiable, Equatable {
        var id = UUID()
        var content: String
    }

}

// swiftlint:enable missing_docs
