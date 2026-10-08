workspace "Web App with OAuth" "SPA + API + database, Google OAuth, component-level detail in the API" {

    configuration {
        scope softwaresystem
    }

    model {
        # People
        user = person "User" "A person using the system"
        admin = person "Administrator" "System administrator"

        # Software Systems
        webapp = softwareSystem "Web Application" "Main web application" {
            # Containers
            spa = container "Single-Page Application" "React SPA" "JavaScript, React"

            api = container "API Application" "REST API" "Node.js, Express" {
                # Components
                authController = component "Auth Controller" "Handles authentication endpoints" "Express Router"
                userController = component "User Controller" "Handles user CRUD operations" "Express Router"
                authService = component "Auth Service" "OAuth token validation and session management" "TypeScript Class"
                userService = component "User Service" "User business logic" "TypeScript Class"
                dbRepository = component "Database Repository" "Data access layer" "TypeORM"
                oauthClient = component "OAuth Client" "Communicates with Google OAuth" "Passport.js"
                emailClient = component "Email Client" "Sends transactional emails" "Nodemailer"

                # Component relationships
                authController -> authService "Validates tokens, manages sessions" "In-process call"
                userController -> userService "Delegates business logic" "In-process call"
                authService -> oauthClient "Validates OAuth tokens" "In-process call"
                authService -> dbRepository "Reads/writes user sessions" "In-process call"
                userService -> dbRepository "Reads/writes user data" "In-process call"
                emailClient -> dbRepository "Reads user preferences" "In-process call"
            }

            database = container "Database" "Stores data" "PostgreSQL"

            # Relationships within system
            spa -> api "Makes API calls to" "HTTPS/JSON"
            api -> database "Reads from and writes to" "SQL/TCP"
        }

        emailSystem = softwareSystem "Email System" "External email service" "External"

        # OAuth Providers
        group "OAuth Providers" {
            googleOAuth = softwareSystem "Google" "OAuth 2.0 identity provider" "External,OAuth"
        }

        # Relationships
        user -> spa "Uses" "HTTPS"
        user -> googleOAuth "Authenticates via" "OAuth 2.0"
        admin -> spa "Administers" "HTTPS"

        spa -> googleOAuth "Redirects to for authentication" "OAuth 2.0"
        googleOAuth -> spa "Returns authentication token to" "OAuth 2.0"

        # SPA to API component relationships (which endpoints the SPA actually calls)
        spa -> authController "Authenticates user, manages sessions" "HTTPS/JSON"
        spa -> userController "Manages user profile" "HTTPS/JSON"

        # Component to external system relationships
        oauthClient -> googleOAuth "Validates tokens with" "HTTPS/JSON"
        emailClient -> emailSystem "Sends emails using" "SMTP"

        # Component to database relationships (via repository)
        dbRepository -> database "Reads from and writes to" "SQL/TCP"
    }

    views {
        systemContext webapp "SystemContext" {
            include *
            autolayout lr
        }

        container webapp "Containers" {
            include *
            autolayout lr
        }

        component api "Components" {
            include *
            autolayout lr
        }

        styles {
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "OAuth" {
                background #4285f4
                color #ffffff
            }
            element "Person" {
                shape person
                background #08427b
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
        }
    }
}
