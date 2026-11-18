{{- define "expense-tracker.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "expense-tracker.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "expense-tracker.labels" -}}
app.kubernetes.io/name: {{ include "expense-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "expense-tracker.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
