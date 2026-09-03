import Foundation
import Testing
@testable import BirdNotesTechnicalCore

@Suite("Built-in technical modules")
struct TechnicalModuleTests {
    @Test("The compiled catalog contains all v3 foundation domains")
    func containsFoundationModules() throws {
        let registry = try TechnicalModuleRegistry.builtIn()

        #expect(registry.modules.count == 6)
        #expect(Set(registry.modules.map(\.domain)) == Set(TechnicalDomain.allCases))
        #expect(registry.versionMap.values.allSatisfy { $0 == "1.0.0" })
    }

    @Test("Software engineering symbols cover requirements, architecture, data, CI and security")
    func containsStudySymbols() throws {
        let registry = try TechnicalModuleRegistry.builtIn()
        let module = try registry.module(id: "birdnotes.software-engineering")

        #expect(Set(module.symbols.map(\.id)).isSuperset(of: [
            "requirement", "use-case", "uml-class", "component", "database-entity",
            "pipeline-stage", "trust-boundary", "test-case"
        ]))
        let requirement = try registry.instantiate(
            moduleID: module.id,
            symbolID: "requirement",
            at: TechnicalPoint(x: 0, y: 0),
            layerID: UUID()
        )
        #expect(requirement.properties["priority"] == .selection("Muss"))
    }

    @Test("Symbols instantiate with semantic ports and default properties")
    func instantiatesSymbols() throws {
        let registry = try TechnicalModuleRegistry.builtIn()
        let layerID = UUID()
        let resistor = try registry.instantiate(
            moduleID: "birdnotes.electrical",
            symbolID: "resistor",
            at: TechnicalPoint(x: 20, y: 30),
            layerID: layerID
        )

        #expect(resistor.ports.count == 2)
        #expect(resistor.properties["resistance"] != nil)
        #expect(resistor.frame.origin == TechnicalPoint(x: 20, y: 30))
    }

    @Test("Built-in calculation templates are dimensionally correct")
    func evaluatesElectricalTemplate() throws {
        let registry = try TechnicalModuleRegistry.builtIn()
        let module = try registry.module(id: "birdnotes.electrical")
        let template = try #require(module.calculations.first(where: { $0.id == "ohms-law-voltage" }))
        let result = try ExpressionEngine().evaluate(template.expression, variables: [
            "current": try Quantity(value: 2, unitID: "ampere"),
            "resistance": try Quantity(value: 5, unitID: "ohm")
        ]).result

        #expect(result.dimension == .voltage)
        #expect(try result.value(in: "volt") == 10)
    }

    @Test("Invalid module versions and non-finite primitives are rejected")
    func rejectsInvalidDefinitions() {
        let symbol = TechnicalSymbolDefinition(
            id: "broken",
            name: "Broken",
            defaultSize: TechnicalSize(width: 100, height: 100),
            primitives: [.line(
                from: TechnicalPoint(x: .infinity, y: 0),
                to: TechnicalPoint(x: 1, y: 1)
            )]
        )
        let module = TechnicalModuleDefinition(
            id: "birdnotes.broken",
            name: "Broken",
            version: "latest",
            domain: .general,
            symbols: [symbol]
        )

        #expect(throws: TechnicalCoreError.self) {
            _ = try TechnicalModuleRegistry(modules: [module])
        }
    }
}

@Suite("Safe vector export")
struct SVGExportTests {
    @Test("SVG output is deterministic and escapes embedded text")
    func exportsEscapedSVG() throws {
        let maliciousText = #"</text><script>alert("x")</script>"#
        let module = TechnicalModuleDefinition(
            id: "birdnotes.export-test",
            name: "Export Test",
            version: "1.0.0",
            domain: .general,
            symbols: [TechnicalSymbolDefinition(
                id: "safe-text",
                name: "Text",
                defaultSize: TechnicalSize(width: 100, height: 60),
                primitives: [.text(
                    value: maliciousText,
                    position: TechnicalPoint(x: 0.5, y: 0.5),
                    relativeSize: 0.2
                )]
            )]
        )
        let registry = try TechnicalModuleRegistry(modules: [module])
        var diagram = TechnicalDiagram(domain: .general)
        let layerID = try #require(diagram.layers.first?.id)
        diagram.elements = [try registry.instantiate(
            moduleID: module.id,
            symbolID: "safe-text",
            at: TechnicalPoint(x: 10, y: 10),
            layerID: layerID
        )]
        let exporter = SVGDiagramExporter(registry: registry)

        let first = try exporter.export(diagram)
        let second = try exporter.export(diagram)
        let text = try #require(String(data: first, encoding: .utf8))

        #expect(first == second)
        #expect(text.contains("&lt;script&gt;"))
        #expect(!text.contains("<script>"))
    }

    @Test("Output limits and unsafe grid scales are enforced")
    func enforcesExportLimits() throws {
        let registry = try TechnicalModuleRegistry.builtIn()
        let exporter = SVGDiagramExporter(registry: registry)
        let diagram = TechnicalDiagram(domain: .general)

        #expect(throws: TechnicalCoreError.self) {
            _ = try exporter.export(diagram, options: SVGExportOptions(maximumOutputBytes: 10))
        }

        var unsafeGrid = diagram
        unsafeGrid.grid.spacing = 1e-300
        #expect(throws: TechnicalCoreError.self) {
            _ = try exporter.export(unsafeGrid, options: SVGExportOptions(includesGrid: true))
        }
    }
}
