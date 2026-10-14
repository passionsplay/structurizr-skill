workspace {
    model {
        a = person "A"
        a -> b "Uses" "HTTPS"
        b = softwareSystem "B"
    }
}
