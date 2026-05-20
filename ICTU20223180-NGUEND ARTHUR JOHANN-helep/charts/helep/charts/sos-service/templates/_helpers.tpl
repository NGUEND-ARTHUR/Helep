{{- define "sos-service.fullname" -}}
{{- printf "%s-%s" .Release.Name "sos-service" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sos-service.labels" -}}
app.kubernetes.io/name: sos-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "sos-service.selectorLabels" -}}
app.kubernetes.io/name: sos-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
