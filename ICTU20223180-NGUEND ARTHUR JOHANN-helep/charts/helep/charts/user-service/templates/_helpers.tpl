{{- define "user-service.fullname" -}}
{{- printf "%s-%s" .Release.Name "user-service" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "user-service.labels" -}}
app.kubernetes.io/name: user-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "user-service.selectorLabels" -}}
app.kubernetes.io/name: user-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
