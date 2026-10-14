source "$EVAL_LIB"
gate workspace-exists has_workspace
gate validates validates
export_json
gate keeps-person-a has_element '^a$'
gate keeps-system-b has_element '^b$'
gate keeps-relationship at_least "$(rel_count)" 1
common_metrics
