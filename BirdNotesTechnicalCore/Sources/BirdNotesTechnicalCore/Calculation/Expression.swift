import Foundation

public enum ExpressionUnaryOperator: String, Codable, Sendable {
    case plus
    case minus
}

public enum ExpressionBinaryOperator: String, Codable, Sendable {
    case add
    case subtract
    case multiply
    case divide
    case power
}

public enum ExpressionFunction: String, Codable, Sendable {
    case squareRoot = "sqrt"
    case absoluteValue = "abs"
    case sine = "sin"
    case cosine = "cos"
    case tangent = "tan"
    case naturalLogarithm = "ln"
    case decimalLogarithm = "log10"
}

public indirect enum ExpressionNode: Codable, Equatable, Sendable {
    case number(Double)
    case variable(String)
    case unary(ExpressionUnaryOperator, ExpressionNode)
    case binary(ExpressionBinaryOperator, ExpressionNode, ExpressionNode)
    case function(ExpressionFunction, ExpressionNode)

    public var variableNames: Set<String> {
        switch self {
        case .number:
            return []
        case .variable(let name):
            return [name]
        case .unary(_, let operand), .function(_, let operand):
            return operand.variableNames
        case .binary(_, let left, let right):
            return left.variableNames.union(right.variableNames)
        }
    }
}

public struct ExpressionLimits: Sendable {
    public var maximumInputLength: Int
    public var maximumTokenCount: Int
    public var maximumDepth: Int
    public var maximumOperationCount: Int
    public var maximumVariableCount: Int
    public var maximumIdentifierLength: Int

    public init(
        maximumInputLength: Int = 4_096,
        maximumTokenCount: Int = 512,
        maximumDepth: Int = 64,
        maximumOperationCount: Int = 1_024,
        maximumVariableCount: Int = 64,
        maximumIdentifierLength: Int = 64
    ) {
        self.maximumInputLength = max(1, maximumInputLength)
        self.maximumTokenCount = max(1, maximumTokenCount)
        self.maximumDepth = max(1, maximumDepth)
        self.maximumOperationCount = max(1, maximumOperationCount)
        self.maximumVariableCount = max(0, maximumVariableCount)
        self.maximumIdentifierLength = max(1, maximumIdentifierLength)
    }

    public static let standard = ExpressionLimits()
}

public struct CalculationStep: Codable, Equatable, Sendable {
    public let index: Int
    public let operation: String
    public let result: Quantity

    public init(index: Int, operation: String, result: Quantity) {
        self.index = index
        self.operation = operation
        self.result = result
    }
}

public struct CalculationTrace: Codable, Equatable, Sendable {
    public let steps: [CalculationStep]

    public init(steps: [CalculationStep]) {
        self.steps = steps
    }
}

public struct ExpressionEvaluation: Codable, Equatable, Sendable {
    public let expression: ExpressionNode
    public let result: Quantity
    public let trace: CalculationTrace

    public init(expression: ExpressionNode, result: Quantity, trace: CalculationTrace) {
        self.expression = expression
        self.result = result
        self.trace = trace
    }
}

public struct ExpressionEngine: Sendable {
    public let limits: ExpressionLimits

    public init(limits: ExpressionLimits = .standard) {
        self.limits = limits
    }

    public func parse(_ source: String) throws -> ExpressionNode {
        guard source.utf8.count <= limits.maximumInputLength else {
            throw TechnicalCoreError.expressionLimitExceeded("Die Formel ist zu lang.")
        }

        let tokens = try Lexer(source: source, limits: limits).tokenize()
        var parser = Parser(tokens: tokens, limits: limits)
        return try parser.parse()
    }

    public func evaluate(
        _ source: String,
        variables: [String: Quantity] = [:]
    ) throws -> ExpressionEvaluation {
        let expression = try parse(source)
        return try evaluate(expression, variables: variables)
    }

    public func evaluate(
        _ expression: ExpressionNode,
        variables: [String: Quantity] = [:]
    ) throws -> ExpressionEvaluation {
        guard variables.count <= limits.maximumVariableCount else {
            throw TechnicalCoreError.expressionLimitExceeded("Zu viele Variablen.")
        }
        guard variables.keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= limits.maximumIdentifierLength }) else {
            throw TechnicalCoreError.invalidExpression("Ungültiger Variablenname.")
        }

        var context = EvaluationContext(
            variables: variables,
            maximumOperationCount: limits.maximumOperationCount
        )
        let result = try evaluate(expression, depth: 0, context: &context)
        return ExpressionEvaluation(
            expression: expression,
            result: result,
            trace: CalculationTrace(steps: context.steps)
        )
    }

    private func evaluate(
        _ node: ExpressionNode,
        depth: Int,
        context: inout EvaluationContext
    ) throws -> Quantity {
        guard depth <= limits.maximumDepth else {
            throw TechnicalCoreError.expressionLimitExceeded("Die Formel ist zu tief verschachtelt.")
        }

        switch node {
        case .number(let value):
            return try Quantity(canonicalValue: value, dimension: .dimensionless)

        case .variable(let name):
            guard let quantity = context.variables[name] else {
                throw TechnicalCoreError.unknownVariable(name)
            }
            return quantity

        case .unary(let operation, let operand):
            let value = try evaluate(operand, depth: depth + 1, context: &context)
            let result: Quantity
            switch operation {
            case .plus:
                result = value
            case .minus:
                result = try Quantity(
                    canonicalValue: -value.canonicalValue,
                    dimension: value.dimension,
                    semantic: value.semantic,
                    preferredDisplayUnit: value.preferredDisplayUnit
                )
            }
            try context.record("unary.\(operation.rawValue)", result: result)
            return result

        case .binary(let operation, let leftNode, let rightNode):
            let left = try evaluate(leftNode, depth: depth + 1, context: &context)
            let right = try evaluate(rightNode, depth: depth + 1, context: &context)
            let result: Quantity

            switch operation {
            case .add:
                result = try left.adding(right)
            case .subtract:
                result = try left.subtracting(right)
            case .multiply:
                result = try left.multiplied(by: right)
            case .divide:
                result = try left.divided(by: right)
            case .power:
                guard right.dimension == .dimensionless,
                      right.semantic == .regular,
                      right.canonicalValue.rounded() == right.canonicalValue,
                      abs(right.canonicalValue) <= 12 else {
                    throw TechnicalCoreError.invalidFunctionArgument("Der Exponent muss eine ganze Zahl zwischen -12 und 12 sein.")
                }
                result = try left.powered(by: Int(right.canonicalValue))
            }

            try context.record("binary.\(operation.rawValue)", result: result)
            return result

        case .function(let function, let argumentNode):
            let argument = try evaluate(argumentNode, depth: depth + 1, context: &context)
            let result = try evaluate(function, argument: argument)
            try context.record("function.\(function.rawValue)", result: result)
            return result
        }
    }

    private func evaluate(_ function: ExpressionFunction, argument: Quantity) throws -> Quantity {
        switch function {
        case .squareRoot:
            guard argument.semantic == .regular, argument.canonicalValue >= 0 else {
                throw TechnicalCoreError.invalidFunctionArgument("sqrt benötigt einen nicht negativen regulären Wert.")
            }
            let dimension = try argument.dimension.exactRoot(degree: 2)
            return try Quantity(canonicalValue: sqrt(argument.canonicalValue), dimension: dimension)

        case .absoluteValue:
            return try Quantity(
                canonicalValue: abs(argument.canonicalValue),
                dimension: argument.dimension,
                semantic: argument.semantic,
                preferredDisplayUnit: argument.preferredDisplayUnit
            )

        case .sine, .cosine, .tangent:
            try requireDimensionless(argument, function: function)
            let value: Double
            switch function {
            case .sine:
                value = sin(argument.canonicalValue)
            case .cosine:
                value = cos(argument.canonicalValue)
            case .tangent:
                value = tan(argument.canonicalValue)
            default:
                value = 0
            }
            return try Quantity(canonicalValue: value, dimension: .dimensionless)

        case .naturalLogarithm, .decimalLogarithm:
            try requireDimensionless(argument, function: function)
            guard argument.canonicalValue > 0 else {
                throw TechnicalCoreError.invalidFunctionArgument("Logarithmen benötigen einen positiven Wert.")
            }
            let value = function == .naturalLogarithm
                ? log(argument.canonicalValue)
                : log10(argument.canonicalValue)
            return try Quantity(canonicalValue: value, dimension: .dimensionless)
        }
    }

    private func requireDimensionless(
        _ argument: Quantity,
        function: ExpressionFunction
    ) throws {
        guard argument.dimension == .dimensionless, argument.semantic == .regular else {
            throw TechnicalCoreError.invalidFunctionArgument("\(function.rawValue) benötigt einen dimensionslosen Wert.")
        }
    }
}

private struct EvaluationContext {
    let variables: [String: Quantity]
    let maximumOperationCount: Int
    var steps: [CalculationStep] = []

    mutating func record(_ operation: String, result: Quantity) throws {
        guard steps.count < maximumOperationCount else {
            throw TechnicalCoreError.expressionLimitExceeded("Zu viele Rechenschritte.")
        }
        steps.append(CalculationStep(index: steps.count + 1, operation: operation, result: result))
    }
}

private enum Token: Equatable {
    case number(Double)
    case identifier(String)
    case plus
    case minus
    case multiply
    case divide
    case power
    case leftParenthesis
    case rightParenthesis
    case end
}

private struct Lexer {
    let bytes: [UInt8]
    let limits: ExpressionLimits

    init(source: String, limits: ExpressionLimits) {
        self.bytes = Array(source.utf8)
        self.limits = limits
    }

    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var index = 0

        func appendChecked(_ token: Token, to tokens: inout [Token]) throws {
            guard tokens.count < limits.maximumTokenCount else {
                throw TechnicalCoreError.expressionLimitExceeded("Zu viele Formelbestandteile.")
            }
            tokens.append(token)
        }

        while index < bytes.count {
            let byte = bytes[index]
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 {
                index += 1
                continue
            }

            switch byte {
            case 43:
                try appendChecked(.plus, to: &tokens)
                index += 1
            case 45:
                try appendChecked(.minus, to: &tokens)
                index += 1
            case 42:
                try appendChecked(.multiply, to: &tokens)
                index += 1
            case 47:
                try appendChecked(.divide, to: &tokens)
                index += 1
            case 94:
                try appendChecked(.power, to: &tokens)
                index += 1
            case 40:
                try appendChecked(.leftParenthesis, to: &tokens)
                index += 1
            case 41:
                try appendChecked(.rightParenthesis, to: &tokens)
                index += 1
            case 48...57, 46:
                let start = index
                var hasDecimalPoint = false
                var hasExponent = false

                while index < bytes.count {
                    let current = bytes[index]
                    if (48...57).contains(current) {
                        index += 1
                    } else if current == 46, !hasDecimalPoint, !hasExponent {
                        hasDecimalPoint = true
                        index += 1
                    } else if (current == 101 || current == 69), !hasExponent {
                        hasExponent = true
                        index += 1
                        if index < bytes.count, (bytes[index] == 43 || bytes[index] == 45) {
                            index += 1
                        }
                    } else {
                        break
                    }
                }

                let raw = String(decoding: bytes[start..<index], as: UTF8.self)
                guard raw != ".", let number = Double(raw), number.isFinite else {
                    throw TechnicalCoreError.invalidExpression("Ungültige Zahl: \(raw)")
                }
                try appendChecked(.number(number), to: &tokens)

            case 65...90, 95, 97...122:
                let start = index
                index += 1
                while index < bytes.count {
                    let current = bytes[index]
                    guard (65...90).contains(current)
                            || (97...122).contains(current)
                            || (48...57).contains(current)
                            || current == 95 else {
                        break
                    }
                    index += 1
                }
                let identifier = String(decoding: bytes[start..<index], as: UTF8.self)
                guard identifier.utf8.count <= limits.maximumIdentifierLength else {
                    throw TechnicalCoreError.expressionLimitExceeded("Ein Bezeichner ist zu lang.")
                }
                try appendChecked(.identifier(identifier), to: &tokens)

            default:
                throw TechnicalCoreError.invalidExpression("Nicht erlaubtes Zeichen in der Formel.")
            }
        }

        guard !tokens.isEmpty else {
            throw TechnicalCoreError.invalidExpression("Die Formel ist leer.")
        }
        tokens.append(.end)
        return tokens
    }
}

private struct Parser {
    let tokens: [Token]
    let limits: ExpressionLimits
    var index = 0

    mutating func parse() throws -> ExpressionNode {
        let expression = try parseAddition(depth: 0)
        guard current == .end else {
            throw TechnicalCoreError.invalidExpression("Unerwarteter Formelbestandteil.")
        }
        return expression
    }

    private var current: Token {
        tokens[index]
    }

    private mutating func parseAddition(depth: Int) throws -> ExpressionNode {
        try checkDepth(depth)
        var node = try parseMultiplication(depth: depth + 1)
        while current == .plus || current == .minus {
            let operation: ExpressionBinaryOperator = current == .plus ? .add : .subtract
            index += 1
            node = .binary(operation, node, try parseMultiplication(depth: depth + 1))
        }
        return node
    }

    private mutating func parseMultiplication(depth: Int) throws -> ExpressionNode {
        try checkDepth(depth)
        var node = try parsePower(depth: depth + 1)
        while current == .multiply || current == .divide {
            let operation: ExpressionBinaryOperator = current == .multiply ? .multiply : .divide
            index += 1
            node = .binary(operation, node, try parsePower(depth: depth + 1))
        }
        return node
    }

    private mutating func parsePower(depth: Int) throws -> ExpressionNode {
        try checkDepth(depth)
        let node = try parseUnary(depth: depth + 1)
        guard current == .power else { return node }
        index += 1
        return .binary(.power, node, try parsePower(depth: depth + 1))
    }

    private mutating func parseUnary(depth: Int) throws -> ExpressionNode {
        try checkDepth(depth)
        if current == .plus {
            index += 1
            return .unary(.plus, try parseUnary(depth: depth + 1))
        }
        if current == .minus {
            index += 1
            return .unary(.minus, try parseUnary(depth: depth + 1))
        }
        return try parsePrimary(depth: depth + 1)
    }

    private mutating func parsePrimary(depth: Int) throws -> ExpressionNode {
        try checkDepth(depth)
        switch current {
        case .number(let value):
            index += 1
            return .number(value)

        case .identifier(let name):
            index += 1
            guard current == .leftParenthesis else {
                return .variable(name)
            }
            guard let function = ExpressionFunction(rawValue: name) else {
                throw TechnicalCoreError.unsupportedFunction(name)
            }
            index += 1
            let argument = try parseAddition(depth: depth + 1)
            guard current == .rightParenthesis else {
                throw TechnicalCoreError.invalidExpression("Schließende Klammer fehlt.")
            }
            index += 1
            return .function(function, argument)

        case .leftParenthesis:
            index += 1
            let expression = try parseAddition(depth: depth + 1)
            guard current == .rightParenthesis else {
                throw TechnicalCoreError.invalidExpression("Schließende Klammer fehlt.")
            }
            index += 1
            return expression

        default:
            throw TechnicalCoreError.invalidExpression("Operand erwartet.")
        }
    }

    private func checkDepth(_ depth: Int) throws {
        guard depth <= limits.maximumDepth else {
            throw TechnicalCoreError.expressionLimitExceeded("Die Formel ist zu tief verschachtelt.")
        }
    }
}
