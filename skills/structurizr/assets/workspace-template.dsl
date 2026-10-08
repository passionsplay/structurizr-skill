workspace "System Name" "One sentence on what this workspace describes." {

    configuration {
        scope softwaresystem
    }

    model {
        user = person "User" "Who they are and what they want."

        system = softwareSystem "System Name" "What it does." {
            webapp = container "Web App" "What it does." "React"
            api = container "API" "What it does." "Node.js, Express" {
                authController = component "Auth Controller" "Login and session endpoints." "Express Router"
                authService = component "Auth Service" "Token validation and session rules." "TypeScript"
                authController -> authService "Validates credentials with" "In-process call"
            }
            database = container "Database" "What it stores." "PostgreSQL" "Database"
        }

        external = softwareSystem "External Service" "What it provides." "External"

        user -> webapp "Uses" "HTTPS"
        webapp -> authController "Signs in via" "HTTPS/JSON"
        api -> database "Reads from and writes to" "SQL/TCP"
        authService -> external "Verifies identity with" "HTTPS/JSON"
    }

    views {
        systemContext system "SystemContext" {
            include *
            autolayout lr
        }

        container system "Containers" {
            include *
            autolayout lr
        }

        component api "Components" {
            include *
            autolayout lr
        }

        styles {
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Database" {
                shape cylinder
            }
            element "External" {
                background #999999
                color #ffffff
            }
        }
    }
}
