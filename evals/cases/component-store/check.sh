source "$EVAL_LIB"
gate workspace-exists has_workspace
gate validates validates
export_json
gate has-component-view at_least "$(view_count componentViews)" 1
gate has-components at_least "$(component_count)" 3
gate models-stripe has_element 'stripe'
gate spa-calls-components at_least "$(cross_container_component_rels)" 1
common_metrics
