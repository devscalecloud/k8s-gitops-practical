{{/*
Namespace the chart's resources are placed in. Templated (not hardcoded to
`demo-app`) so this chart could be installed into any namespace via
`--namespace`/`.Values.namespace`, and every template references this helper
rather than repeating `demo-app` -- one bad edit here would be a good,
realistic "chart looks fine, wrong namespace" fault to plant later.
*/}}
{{- define "demo-app.namespace" -}}
{{ .Values.namespace | default .Release.Namespace }}
{{- end -}}
