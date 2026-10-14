source "$EVAL_LIB"
gate workspace-exists has_workspace
gate validates validates
export_json
gate has-context-view at_least "$(view_count systemContextViews)" 1
gate has-container-view at_least "$(view_count containerViews)" 1
gate models-google has_element 'google'
gate models-sendgrid has_element 'sendgrid'
common_metrics
