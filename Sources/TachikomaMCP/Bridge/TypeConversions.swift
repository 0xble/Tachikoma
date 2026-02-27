import Foundation
import MCP
import Tachikoma

// MARK: - Type Conversion Extensions for TachikomaMCP

// MARK: ToolArguments Extensions

extension ToolArguments {
    /// Initialize from Tachikoma's AgentToolArguments
    public init(from arguments: AgentToolArguments) {
        var dict: [String: Any] = [:]
        for key in arguments.keys {
            guard let value = arguments[key] else { continue }
            if let json = try? value.toJSON() {
                dict[key] = json
            } else {
                dict[key] = ["serializationFailure": String(describing: value)]
            }
        }
        self.init(raw: dict)
    }
}

// MARK: AnyAgentToolValue Extensions

extension AnyAgentToolValue {
    /// Convert to MCP Value
    public func toValue() -> Value {
        // Convert to MCP Value
        if let str = stringValue {
            .string(str)
        } else if let num = intValue {
            .int(num)
        } else if let num = doubleValue {
            .double(num)
        } else if let bool = boolValue {
            .bool(bool)
        } else if let array = arrayValue {
            .array(array.map { $0.toValue() })
        } else if let dict = objectValue {
            .object(dict.mapValues { $0.toValue() })
        } else if isNull {
            .null
        } else {
            // Fallback to null
            .null
        }
    }
}

// MARK: Value Extensions

extension Value {
    /// Convert from Any type
    public static func from(_ any: Any) -> Value {
        // Convert from Any type
        switch any {
        case let str as String:
            .string(str)
        case let num as Int:
            .int(num)
        case let num as Double:
            .double(num)
        case let bool as Bool:
            .bool(bool)
        case let array as [Any]:
            .array(array.map { Value.from($0) })
        case let dict as [String: Any]:
            .object(dict.mapValues { Value.from($0) })
        case is NSNull:
            .null
       default:
            // Fallback: convert to string representation
            .string(String(describing: any))
        }
    }

    /// Convert to Tachikoma's AnyAgentToolValue
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        // Convert to Tachikoma's AnyAgentToolValue
        switch self {
        case let .string(str):
            AnyAgentToolValue(string: str)
        case let .int(num):
            AnyAgentToolValue(int: num)
        case let .double(num):
            AnyAgentToolValue(double: num)
        case let .bool(bool):
            AnyAgentToolValue(bool: bool)
        case let .array(array):
            AnyAgentToolValue(array: array.map { $0.toAnyAgentToolValue() })
        case let .object(dict):
            AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        case .null:
            AnyAgentToolValue(null: ())
        case let .data(mimeType, data):
            // Convert data to a special object representation
            // Note: mimeType is optional, data is Data type
            AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "data"),
                "mimeType": AnyAgentToolValue(string: mimeType ?? "application/octet-stream"),
                "dataSize": AnyAgentToolValue(int: data.count),
            ])
        }
    }
}

// MARK: ToolResponse Extensions

extension ToolResponse {
    /// Convert to Tachikoma's AnyAgentToolValue (which is what AgentTool.execute returns)
    public func toAgentToolResult() -> AnyAgentToolValue {
        // If there's an error, return error message
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert the first content item to a result
        if let firstContent = content.first {
            switch firstContent {
            case let .text(text):
                return AnyAgentToolValue(string: text)
            case let .image(data, mimeType, _):
                // For images, return a descriptive string
                return AnyAgentToolValue(string: "[Image: \(mimeType), size: \(data.count) bytes]")
            case let .resource(resourceValue, secondValue, thirdValue):
                return Self.resourceSummary(
                    resourceValue: resourceValue,
                    secondValue: secondValue,
                    thirdValue: thirdValue)
            case let .audio(data, mimeType):
                return AnyAgentToolValue(string: "[Audio: \(mimeType), size: \(data.count) bytes]")
            default:
                return AnyAgentToolValue(string: String(describing: firstContent))
            }
        }

        // No content
        return AnyAgentToolValue(string: "Success")
    }

    /// Convert to Tachikoma's AnyAgentToolValue for more complex results
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        // If there's an error, return it as a string
        if isError {
            let errorMessage = content.compactMap { content -> String? in
                if case let .text(text) = content {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            return AnyAgentToolValue(string: "Error: \(errorMessage)")
        }

        // Convert content to appropriate format
        if content.count == 1 {
            // Single content item
            return self.convertContentToAnyAgentToolValue(content[0])
        } else if content.isEmpty {
            // No content
            return AnyAgentToolValue(null: ())
        } else {
            // Multiple content items - return as array
            return AnyAgentToolValue(array: content.map { self.convertContentToAnyAgentToolValue($0) })
        }
    }

    private func convertContentToAnyAgentToolValue(_ content: MCP.Tool.Content) -> AnyAgentToolValue {
        switch content {
        case let .text(text):
            return AnyAgentToolValue(string: text)
        case let .image(data, mimeType, _):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "image"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        case let .resource(resourceValue, secondValue, thirdValue):
            return Self.resourceObject(
                resourceValue: resourceValue,
                secondValue: secondValue,
                thirdValue: thirdValue)
        case let .audio(data, mimeType):
            return AnyAgentToolValue(object: [
                "type": AnyAgentToolValue(string: "audio"),
                "mimeType": AnyAgentToolValue(string: mimeType),
                "data": AnyAgentToolValue(string: data),
            ])
        default:
            return AnyAgentToolValue(string: String(describing: content))
        }
    }

    private static func resourceSummary<ResourceValue, SecondValue, ThirdValue>(
        resourceValue: ResourceValue,
        secondValue: SecondValue,
        thirdValue: ThirdValue
    ) -> AnyAgentToolValue {
        let details = self.parseResourceDetails(
            resourceValue: resourceValue,
            secondValue: secondValue,
            thirdValue: thirdValue)
        return AnyAgentToolValue(string: details.text ?? "[Resource: \(details.uri)]")
    }

    private static func resourceObject<ResourceValue, SecondValue, ThirdValue>(
        resourceValue: ResourceValue,
        secondValue: SecondValue,
        thirdValue: ThirdValue
    ) -> AnyAgentToolValue {
        let details = self.parseResourceDetails(
            resourceValue: resourceValue,
            secondValue: secondValue,
            thirdValue: thirdValue)

        var resourceDict: [String: AnyAgentToolValue] = [
            "type": AnyAgentToolValue(string: "resource"),
            "uri": AnyAgentToolValue(string: details.uri),
        ]
        if let mimeType = details.mimeType {
            resourceDict["mimeType"] = AnyAgentToolValue(string: mimeType)
        } else {
            resourceDict["mimeType"] = AnyAgentToolValue(null: ())
        }
        if let text = details.text {
            resourceDict["text"] = AnyAgentToolValue(string: text)
        } else {
            resourceDict["text"] = AnyAgentToolValue(null: ())
        }
        if let blob = details.blob {
            resourceDict["blob"] = AnyAgentToolValue(string: blob)
        }
        return AnyAgentToolValue(object: resourceDict)
    }

    private static func parseResourceDetails<ResourceValue, SecondValue, ThirdValue>(
        resourceValue: ResourceValue,
        secondValue: SecondValue,
        thirdValue: ThirdValue
    ) -> (uri: String, mimeType: String?, text: String?, blob: String?) {
        // MCP 0.10.x exposes `.resource(uri:mimeType:text:)` while 0.11.x exposes
        // `.resource(resource: Resource.Content, annotations:..., _meta:...)`.
        if let uri = resourceValue as? String {
            return (
                uri: uri,
                mimeType: secondValue as? String,
                text: thirdValue as? String,
                blob: nil
            )
        }

        return (
            uri: self.extractStringProperty(named: "uri", from: resourceValue) ?? "[resource]",
            mimeType: self.extractStringProperty(named: "mimeType", from: resourceValue),
            text: self.extractStringProperty(named: "text", from: resourceValue),
            blob: self.extractStringProperty(named: "blob", from: resourceValue)
        )
    }

    private static func extractStringProperty<Value>(named name: String, from value: Value) -> String? {
        for child in Mirror(reflecting: value).children {
            guard child.label == name else { continue }
            return self.unwrapOptional(child.value) as? String
        }
        return nil
    }

    private static func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}
