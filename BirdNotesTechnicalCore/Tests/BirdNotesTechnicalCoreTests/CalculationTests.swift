import Testing
@testable import BirdNotesTechnicalCore

@Suite("SI quantities and safe expressions")
struct CalculationTests {
    @Test("Compatible SI values are converted and added")
    func convertsAndAddsCompatibleValues() throws {
        let registry = UnitRegistry.si
        let metres = try Quantity(value: 2, unitID: "metre", registry: registry)
        let millimetres = try Quantity(value: 500, unitID: "millimetre", registry: registry)

        let sum = try metres.adding(millimetres)

        #expect(try sum.value(in: "metre", registry: registry) == 2.5)
        #expect(try sum.value(in: "millimetre", registry: registry) == 2_500)
    }

    @Test("Incompatible dimensions cannot be added")
    func rejectsIncompatibleAddition() throws {
        let metres = try Quantity(value: 2, unitID: "metre")
        let seconds = try Quantity(value: 2, unitID: "second")

        #expect(throws: TechnicalCoreError.self) {
            _ = try metres.adding(seconds)
        }
    }

    @Test("Absolute Celsius values use Kelvin internally")
    func handlesAffineTemperatureUnits() throws {
        let temperature = try Quantity(value: 20, unitID: "degreeCelsius")
        let delta = try Quantity(value: 5, unitID: "celsiusDifference")
        let warmer = try temperature.adding(delta)

        #expect(abs(temperature.canonicalValue - 293.15) < 0.000_001)
        #expect(abs(try warmer.value(in: "degreeCelsius") - 25) < 0.000_001)
    }

    @Test("Operator precedence and right-associative powers are deterministic")
    func parsesOperatorPrecedence() throws {
        let engine = ExpressionEngine()

        #expect(try engine.evaluate("2 + 3 * 4").result.canonicalValue == 14)
        #expect(try engine.evaluate("2 ^ 3 ^ 2").result.canonicalValue == 512)
    }

    @Test("Expressions preserve and validate dimensions")
    func evaluatesDimensionedExpression() throws {
        let variables = [
            "distance": try Quantity(value: 10, unitID: "metre"),
            "duration": try Quantity(value: 2, unitID: "second")
        ]

        let evaluation = try ExpressionEngine().evaluate("distance / duration", variables: variables)

        #expect(evaluation.result.dimension == .velocity)
        #expect(evaluation.result.canonicalValue == 5)
        #expect(evaluation.trace.steps.count == 1)
    }

    @Test("Unsafe and unbounded expression inputs are rejected")
    func rejectsUnsafeInputs() throws {
        let engine = ExpressionEngine(limits: ExpressionLimits(maximumInputLength: 16))

        #expect(throws: TechnicalCoreError.self) {
            _ = try engine.evaluate("1; system_call()")
        }
        #expect(throws: TechnicalCoreError.self) {
            _ = try engine.evaluate(String(repeating: "1+", count: 20) + "1")
        }
        #expect(throws: TechnicalCoreError.self) {
            _ = try ExpressionEngine().evaluate("unknown + 1")
        }
    }

    @Test("Square roots only create integral SI dimensions")
    func validatesSquareRootDimensions() throws {
        let area = try Quantity(canonicalValue: 9, dimension: .area)
        let length = try ExpressionEngine().evaluate(
            .function(.squareRoot, .variable("area")),
            variables: ["area": area]
        ).result
        #expect(length.dimension == .length)
        #expect(length.canonicalValue == 3)

        let time = try Quantity(value: 4, unitID: "second")
        #expect(throws: TechnicalCoreError.self) {
            _ = try ExpressionEngine().evaluate(
                .function(.squareRoot, .variable("time")),
                variables: ["time": time]
            )
        }
    }
}
