import Foundation

public extension TechnicalModuleRegistry {
    static func builtIn() throws -> Self {
        try Self(modules: [
            generalModule(),
            electricalModule(),
            technicalDrawingModule(),
            mechanicsModule(),
            softwareEngineeringModule(),
            informationTechnologyModule()
        ])
    }

    private static func generalModule() throws -> TechnicalModuleDefinition {
        TechnicalModuleDefinition(
            id: "birdnotes.general",
            name: "Allgemein",
            version: "1.0.0",
            domain: .general,
            symbols: [
                TechnicalSymbolDefinition(
                    id: "box",
                    name: "Block",
                    defaultSize: TechnicalSize(width: 140, height: 80),
                    ports: standardHorizontalPorts(kind: "general"),
                    properties: [textProperty(id: "caption", name: "Beschriftung", value: "Block")],
                    primitives: [.rectangle(unitRect())]
                ),
                TechnicalSymbolDefinition(
                    id: "coordinate-system",
                    name: "Koordinatensystem",
                    defaultSize: TechnicalSize(width: 220, height: 220),
                    primitives: [
                        .line(from: point(0, 0.5), to: point(1, 0.5)),
                        .line(from: point(0.5, 1), to: point(0.5, 0))
                    ]
                )
            ]
        )
    }

    private static func electricalModule() throws -> TechnicalModuleDefinition {
        let resistance = try Quantity(value: 1, unitID: "kiloohm")
        let voltage = try Quantity(value: 5, unitID: "volt")
        return TechnicalModuleDefinition(
            id: "birdnotes.electrical",
            name: "Elektrotechnik",
            version: "1.0.0",
            domain: .electricalEngineering,
            symbols: [
                TechnicalSymbolDefinition(
                    id: "resistor",
                    name: "Widerstand",
                    defaultSize: TechnicalSize(width: 140, height: 50),
                    ports: standardHorizontalPorts(kind: "electrical"),
                    properties: [quantityProperty(id: "resistance", name: "Widerstand", value: resistance)],
                    primitives: [
                        .line(from: point(0, 0.5), to: point(0.15, 0.5)),
                        .polyline([
                            point(0.15, 0.5), point(0.25, 0.2), point(0.35, 0.8), point(0.45, 0.2),
                            point(0.55, 0.8), point(0.65, 0.2), point(0.75, 0.8), point(0.85, 0.5)
                        ]),
                        .line(from: point(0.85, 0.5), to: point(1, 0.5))
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "capacitor",
                    name: "Kondensator",
                    defaultSize: TechnicalSize(width: 100, height: 70),
                    ports: standardHorizontalPorts(kind: "electrical"),
                    primitives: [
                        .line(from: point(0, 0.5), to: point(0.42, 0.5)),
                        .line(from: point(0.42, 0.15), to: point(0.42, 0.85)),
                        .line(from: point(0.58, 0.15), to: point(0.58, 0.85)),
                        .line(from: point(0.58, 0.5), to: point(1, 0.5))
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "dc-voltage-source",
                    name: "Gleichspannungsquelle",
                    defaultSize: TechnicalSize(width: 100, height: 100),
                    ports: standardVerticalPorts(kind: "electrical"),
                    properties: [quantityProperty(id: "voltage", name: "Spannung", value: voltage)],
                    primitives: [
                        .ellipse(TechnicalRect(origin: point(0.1, 0.1), size: TechnicalSize(width: 0.8, height: 0.8))),
                        .line(from: point(0.4, 0.35), to: point(0.6, 0.35)),
                        .line(from: point(0.5, 0.25), to: point(0.5, 0.45)),
                        .line(from: point(0.4, 0.68), to: point(0.6, 0.68))
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "ground",
                    name: "Masse",
                    defaultSize: TechnicalSize(width: 80, height: 70),
                    ports: [DiagramPort(id: "terminal", name: "Anschluss", kind: "electrical", position: point(0.5, 0))],
                    primitives: [
                        .line(from: point(0.5, 0), to: point(0.5, 0.55)),
                        .line(from: point(0.15, 0.55), to: point(0.85, 0.55)),
                        .line(from: point(0.28, 0.7), to: point(0.72, 0.7)),
                        .line(from: point(0.4, 0.85), to: point(0.6, 0.85))
                    ]
                )
            ],
            calculations: [
                CalculationTemplate(
                    id: "ohms-law-voltage",
                    name: "Ohmsches Gesetz – Spannung",
                    expression: "current * resistance",
                    variables: [
                        CalculationVariableDefinition(id: "current", name: "Strom", dimension: .electricCurrent, suggestedUnitID: "ampere"),
                        CalculationVariableDefinition(id: "resistance", name: "Widerstand", dimension: .resistance, suggestedUnitID: "ohm")
                    ]
                ),
                CalculationTemplate(
                    id: "electrical-power",
                    name: "Elektrische Leistung",
                    expression: "voltage * current",
                    variables: [
                        CalculationVariableDefinition(id: "voltage", name: "Spannung", dimension: .voltage, suggestedUnitID: "volt"),
                        CalculationVariableDefinition(id: "current", name: "Strom", dimension: .electricCurrent, suggestedUnitID: "ampere")
                    ]
                )
            ]
        )
    }

    private static func technicalDrawingModule() throws -> TechnicalModuleDefinition {
        TechnicalModuleDefinition(
            id: "birdnotes.drawing",
            name: "Technisches Zeichnen",
            version: "1.0.0",
            domain: .technicalDrawing,
            symbols: [
                TechnicalSymbolDefinition(
                    id: "line",
                    name: "Linie",
                    defaultSize: TechnicalSize(width: 160, height: 30),
                    primitives: [.line(from: point(0, 0.5), to: point(1, 0.5))]
                ),
                TechnicalSymbolDefinition(
                    id: "rectangle",
                    name: "Rechteck",
                    defaultSize: TechnicalSize(width: 160, height: 100),
                    primitives: [.rectangle(unitRect())]
                ),
                TechnicalSymbolDefinition(
                    id: "circle",
                    name: "Kreis",
                    defaultSize: TechnicalSize(width: 120, height: 120),
                    primitives: [.ellipse(unitRect())]
                ),
                TechnicalSymbolDefinition(
                    id: "dimension-line",
                    name: "Bemaßung",
                    defaultSize: TechnicalSize(width: 180, height: 50),
                    properties: [textProperty(id: "value", name: "Maß", value: "100 mm")],
                    primitives: [
                        .line(from: point(0, 0.5), to: point(1, 0.5)),
                        .line(from: point(0, 0.2), to: point(0, 0.8)),
                        .line(from: point(1, 0.2), to: point(1, 0.8))
                    ]
                )
            ],
            calculations: [
                CalculationTemplate(
                    id: "rectangle-area",
                    name: "Rechteckfläche",
                    expression: "width * height",
                    variables: [
                        CalculationVariableDefinition(id: "width", name: "Breite", dimension: .length, suggestedUnitID: "millimetre"),
                        CalculationVariableDefinition(id: "height", name: "Höhe", dimension: .length, suggestedUnitID: "millimetre")
                    ]
                )
            ]
        )
    }

    private static func mechanicsModule() throws -> TechnicalModuleDefinition {
        TechnicalModuleDefinition(
            id: "birdnotes.mechanics",
            name: "Physik & Technische Mechanik",
            version: "1.0.0",
            domain: .mechanics,
            symbols: [
                TechnicalSymbolDefinition(
                    id: "force-arrow",
                    name: "Kraftpfeil",
                    defaultSize: TechnicalSize(width: 160, height: 50),
                    properties: [textProperty(id: "caption", name: "Bezeichnung", value: "F")],
                    primitives: [
                        .line(from: point(0, 0.5), to: point(1, 0.5)),
                        .line(from: point(1, 0.5), to: point(0.82, 0.25)),
                        .line(from: point(1, 0.5), to: point(0.82, 0.75))
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "beam",
                    name: "Balken",
                    defaultSize: TechnicalSize(width: 260, height: 45),
                    ports: standardHorizontalPorts(kind: "mechanical"),
                    primitives: [.rectangle(TechnicalRect(origin: point(0, 0.3), size: TechnicalSize(width: 1, height: 0.4)))]
                ),
                TechnicalSymbolDefinition(
                    id: "fixed-support",
                    name: "Feste Einspannung",
                    defaultSize: TechnicalSize(width: 80, height: 140),
                    ports: [DiagramPort(id: "mount", name: "Lager", kind: "mechanical", position: point(1, 0.5))],
                    primitives: [
                        .line(from: point(0.75, 0), to: point(0.75, 1)),
                        .line(from: point(0.1, 0.15), to: point(0.75, 0)),
                        .line(from: point(0.1, 0.4), to: point(0.75, 0.25)),
                        .line(from: point(0.1, 0.65), to: point(0.75, 0.5)),
                        .line(from: point(0.1, 0.9), to: point(0.75, 0.75))
                    ]
                )
            ],
            calculations: [
                CalculationTemplate(
                    id: "newtons-second-law",
                    name: "Kraft",
                    expression: "mass * acceleration",
                    variables: [
                        CalculationVariableDefinition(id: "mass", name: "Masse", dimension: .mass, suggestedUnitID: "kilogram"),
                        CalculationVariableDefinition(id: "acceleration", name: "Beschleunigung", dimension: .acceleration, suggestedUnitID: "metrePerSecondSquared")
                    ]
                ),
                CalculationTemplate(
                    id: "moment",
                    name: "Drehmoment",
                    expression: "force * leverArm",
                    variables: [
                        CalculationVariableDefinition(id: "force", name: "Kraft", dimension: .force, suggestedUnitID: "newton"),
                        CalculationVariableDefinition(id: "leverArm", name: "Hebelarm", dimension: .length, suggestedUnitID: "metre")
                    ]
                )
            ]
        )
    }

    private static func softwareEngineeringModule() throws -> TechnicalModuleDefinition {
        let softwarePorts = standardHorizontalPorts(kind: "software")
        return TechnicalModuleDefinition(
            id: "birdnotes.software-engineering",
            name: "Softwareentwicklung & Studium",
            version: "1.0.0",
            domain: .informationTechnology,
            symbols: [
                TechnicalSymbolDefinition(
                    id: "requirement",
                    name: "Anforderung",
                    defaultSize: TechnicalSize(width: 220, height: 100),
                    ports: softwarePorts,
                    properties: [
                        textProperty(id: "caption", name: "Anforderung", value: "Das System muss …"),
                        TechnicalPropertyDefinition(
                            id: "priority",
                            name: "Priorität",
                            kind: .selection,
                            defaultValue: .selection("Muss"),
                            allowedSelections: ["Muss", "Soll", "Kann"]
                        )
                    ],
                    primitives: [
                        .rectangle(unitRect()),
                        .text(value: "REQ", position: point(0.5, 0.52), relativeSize: 0.16)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "use-case",
                    name: "Use Case",
                    defaultSize: TechnicalSize(width: 190, height: 105),
                    ports: softwarePorts,
                    properties: [textProperty(id: "caption", name: "Use Case", value: "Anwendungsfall")],
                    primitives: [
                        .ellipse(unitRect()),
                        .text(value: "USE CASE", position: point(0.5, 0.54), relativeSize: 0.12)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "decision",
                    name: "Entscheidung",
                    defaultSize: TechnicalSize(width: 150, height: 120),
                    ports: softwarePorts,
                    properties: [textProperty(id: "caption", name: "Bedingung", value: "Bedingung?")],
                    primitives: [
                        .polyline([point(0.5, 0), point(1, 0.5), point(0.5, 1), point(0, 0.5), point(0.5, 0)]),
                        .text(value: "?", position: point(0.5, 0.57), relativeSize: 0.22)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "uml-class",
                    name: "UML-Klasse",
                    defaultSize: TechnicalSize(width: 220, height: 180),
                    ports: softwarePorts,
                    properties: [
                        textProperty(id: "name", name: "Klassenname", value: "ClassName"),
                        textProperty(id: "attributes", name: "Attribute", value: "+ attribute: Type"),
                        textProperty(id: "methods", name: "Methoden", value: "+ operation()")
                    ],
                    primitives: [
                        .rectangle(unitRect()),
                        .line(from: point(0, 0.27), to: point(1, 0.27)),
                        .line(from: point(0, 0.63), to: point(1, 0.63)),
                        .text(value: "CLASS", position: point(0.5, 0.17), relativeSize: 0.10)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "component",
                    name: "Architekturkomponente",
                    defaultSize: TechnicalSize(width: 220, height: 130),
                    ports: softwarePorts,
                    properties: [textProperty(id: "caption", name: "Komponente", value: "Component")],
                    primitives: [
                        .rectangle(unitRect()),
                        .rectangle(TechnicalRect(origin: point(0.78, 0.18), size: TechnicalSize(width: 0.16, height: 0.20))),
                        .rectangle(TechnicalRect(origin: point(0.78, 0.48), size: TechnicalSize(width: 0.16, height: 0.20))),
                        .text(value: "COMPONENT", position: point(0.42, 0.55), relativeSize: 0.09)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "database-entity",
                    name: "Datenbank-Entität",
                    defaultSize: TechnicalSize(width: 220, height: 150),
                    ports: softwarePorts,
                    properties: [
                        textProperty(id: "name", name: "Entität", value: "Entity"),
                        textProperty(id: "attributes", name: "Attribute", value: "id (PK)")
                    ],
                    primitives: [
                        .rectangle(unitRect()),
                        .line(from: point(0, 0.3), to: point(1, 0.3)),
                        .text(value: "ENTITY", position: point(0.5, 0.19), relativeSize: 0.11)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "pipeline-stage",
                    name: "CI/CD-Pipeline-Schritt",
                    defaultSize: TechnicalSize(width: 190, height: 90),
                    ports: softwarePorts,
                    properties: [
                        textProperty(id: "caption", name: "Schritt", value: "Build"),
                        TechnicalPropertyDefinition(
                            id: "gate",
                            name: "Quality Gate",
                            kind: .boolean,
                            defaultValue: .boolean(true)
                        )
                    ],
                    primitives: [
                        .rectangle(unitRect()),
                        .text(value: "PIPELINE", position: point(0.5, 0.55), relativeSize: 0.12)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "trust-boundary",
                    name: "Trust Boundary",
                    defaultSize: TechnicalSize(width: 280, height: 190),
                    ports: softwarePorts,
                    properties: [textProperty(id: "caption", name: "Vertrauensgrenze", value: "Trust Boundary")],
                    primitives: [
                        .rectangle(unitRect()),
                        .text(value: "TRUST BOUNDARY", position: point(0.5, 0.12), relativeSize: 0.08)
                    ]
                ),
                TechnicalSymbolDefinition(
                    id: "test-case",
                    name: "Testfall",
                    defaultSize: TechnicalSize(width: 210, height: 110),
                    ports: softwarePorts,
                    properties: [
                        textProperty(id: "caption", name: "Testfall", value: "Given / When / Then"),
                        TechnicalPropertyDefinition(
                            id: "level",
                            name: "Teststufe",
                            kind: .selection,
                            defaultValue: .selection("Unit"),
                            allowedSelections: ["Unit", "Integration", "System", "Abnahme"]
                        )
                    ],
                    primitives: [
                        .rectangle(unitRect()),
                        .text(value: "TEST", position: point(0.5, 0.55), relativeSize: 0.16)
                    ]
                )
            ]
        )
    }

    private static func informationTechnologyModule() throws -> TechnicalModuleDefinition {
        let symbols = [
            itBox(id: "server", name: "Server", caption: "SERVER", portCount: 2),
            itBox(id: "router", name: "Router", caption: "ROUTER", portCount: 4),
            itBox(id: "switch", name: "Switch", caption: "SWITCH", portCount: 6),
            itBox(id: "database", name: "Datenbank", caption: "DB", portCount: 2),
            TechnicalSymbolDefinition(
                id: "cloud",
                name: "Cloud",
                defaultSize: TechnicalSize(width: 180, height: 100),
                ports: standardHorizontalPorts(kind: "network"),
                properties: [textProperty(id: "caption", name: "Beschriftung", value: "Cloud")],
                primitives: [
                    .ellipse(TechnicalRect(origin: point(0.08, 0.35), size: TechnicalSize(width: 0.38, height: 0.45))),
                    .ellipse(TechnicalRect(origin: point(0.3, 0.12), size: TechnicalSize(width: 0.4, height: 0.62))),
                    .ellipse(TechnicalRect(origin: point(0.55, 0.32), size: TechnicalSize(width: 0.38, height: 0.48))),
                    .line(from: point(0.2, 0.8), to: point(0.8, 0.8))
                ]
            )
        ]
        return TechnicalModuleDefinition(
            id: "birdnotes.it",
            name: "IT & Netzwerke",
            version: "1.0.0",
            domain: .informationTechnology,
            symbols: symbols
        )
    }

    private static func itBox(id: String, name: String, caption: String, portCount: Int) -> TechnicalSymbolDefinition {
        let ports = (0..<portCount).map { index in
            DiagramPort(
                id: "port-\(index + 1)",
                name: "Port \(index + 1)",
                kind: "network",
                direction: .bidirectional,
                position: point(index.isMultiple(of: 2) ? 0 : 1, Double(index + 1) / Double(portCount + 1))
            )
        }
        return TechnicalSymbolDefinition(
            id: id,
            name: name,
            defaultSize: TechnicalSize(width: 160, height: 100),
            ports: ports,
            properties: [textProperty(id: "caption", name: "Name", value: name)],
            primitives: [
                .rectangle(unitRect()),
                .text(value: caption, position: point(0.5, 0.55), relativeSize: 0.14)
            ]
        )
    }

    private static func standardHorizontalPorts(kind: String) -> [DiagramPort] {
        [
            DiagramPort(id: "left", name: "Links", kind: kind, position: point(0, 0.5)),
            DiagramPort(id: "right", name: "Rechts", kind: kind, position: point(1, 0.5))
        ]
    }

    private static func standardVerticalPorts(kind: String) -> [DiagramPort] {
        [
            DiagramPort(id: "top", name: "Oben", kind: kind, position: point(0.5, 0)),
            DiagramPort(id: "bottom", name: "Unten", kind: kind, position: point(0.5, 1))
        ]
    }

    private static func quantityProperty(id: String, name: String, value: Quantity) -> TechnicalPropertyDefinition {
        TechnicalPropertyDefinition(id: id, name: name, kind: .quantity, defaultValue: .quantity(value))
    }

    private static func textProperty(id: String, name: String, value: String) -> TechnicalPropertyDefinition {
        TechnicalPropertyDefinition(id: id, name: name, kind: .text, defaultValue: .text(value))
    }

    private static func point(_ x: Double, _ y: Double) -> TechnicalPoint {
        TechnicalPoint(x: x, y: y)
    }

    private static func unitRect() -> TechnicalRect {
        TechnicalRect(origin: point(0, 0), size: TechnicalSize(width: 1, height: 1))
    }
}
