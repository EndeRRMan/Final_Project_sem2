{{- define "backend-report.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 55 | trimSuffix "-" -}}
{{- end -}}

{{- define "backend-report.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "backend-report.labels" -}}
{{ include "backend-report.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/component: backend-report
app.kubernetes.io/part-of: {{ .Release.Name | quote }}
{{- end -}}
