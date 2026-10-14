source "$EVAL_LIB"
gate workspace-exists has_workspace
gate validates validates
export_json
gate adds-redis has_element 'redis'
gate has-component-view at_least "$(view_count componentViews)" 1
gate has-components at_least "$(component_count)" 4
gate keeps-web-app has_element '^web app$'
gate keeps-database has_element '^database$'
gate keeps-container-view at_least "$(view_count containerViews)" 1
common_metrics
