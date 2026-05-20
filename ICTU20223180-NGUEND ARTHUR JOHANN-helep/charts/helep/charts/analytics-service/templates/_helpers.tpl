{{- define "analytics-service.fullname" -}}
{{- printf "%s-%s" .Release.Name "analytics-service" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "analytics-service.labels" -}}
app.kubernetes.io/name: analytics-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "analytics-service.selectorLabels" -}}
app.kubernetes.io/name: analytics-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
