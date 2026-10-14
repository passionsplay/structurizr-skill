workspace "Bookshop" "An online bookshop." {

    model {
        customer = person "Customer" "Buys books online."

        bookshop = softwareSystem "Bookshop" "Lets customers browse and buy books." {
            spa = container "Web App" "Browse and checkout UI." "React"
            api = container "API" "Catalog and order endpoints." "Node.js, Express"
            db = container "Database" "Books, orders, customers." "PostgreSQL 16" "Database"
        }

        customer -> spa "Browses and buys books with" "HTTPS"
        spa -> api "Calls" "HTTPS/JSON"
        api -> db "Reads and writes" "SQL/TCP"
    }

    views {
        systemContext bookshop "Context" {
            include *
            autolayout lr
        }

        container bookshop "Containers" {
            include *
            autolayout lr
        }

        styles {
            element "Database" {
                shape cylinder
            }
        }
    }
}
