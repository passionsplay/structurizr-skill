source "$EVAL_LIB"
gate workspace-exists has_workspace
gate still-validates validates
gate mermaid-per-view at_least "$(ls diagrams/*.mmd 2>/dev/null | wc -l | tr -d ' ')" 2
gate mermaid-content grep -qiE 'graph|flowchart' diagrams/*.mmd
common_metrics
