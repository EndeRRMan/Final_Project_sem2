{{- define "infra.mongodb.labels" -}}
app: mongodb
app.kubernetes.io/name: mongodb
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/component: mongodb
app.kubernetes.io/part-of: {{ .Release.Name | quote }}
{{- end -}}
