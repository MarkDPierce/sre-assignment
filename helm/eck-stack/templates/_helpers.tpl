{{- define "cluster.name" -}}
{{- if .Values.elastic.clustername -}}
{{- $name := .Values.elastic.clustername -}}
{{- else -}}
{{- $name := "elastic-cluster" -}}
{{- printf "%s" $name }}
{{- end }}
{{- end }}