{{- define "dispatch-service.fullname" -}}
{{- printf "%s-%s" .Release.Name "dispatch-service" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dispatch-service.labels" -}}
app.kubernetes.io/name: dispatch-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dispatch-service.selectorLabels" -}}
app.kubernetes.io/name: dispatch-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
