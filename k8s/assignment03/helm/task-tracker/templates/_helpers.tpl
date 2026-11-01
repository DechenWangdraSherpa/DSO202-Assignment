{{/* task-tracker.environment: required, so nothing renders without one. */}}
{{- define "task-tracker.environment" -}}
{{- required "environment must be set (dev, staging or prod)" .Values.environment -}}
{{- end }}

{{/* task-tracker.chart: "<name>-<version>" for the helm.sh/chart label. */}}
{{- define "task-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
task-tracker.selectorLabels: the stable labels Services and Deployments select on.
Takes a dict with "tier". Must match the Assignment 1 selectors.
*/}}
{{- define "task-tracker.selectorLabels" -}}
app: task-tracker
tier: {{ .tier }}
{{- end }}

{{/* task-tracker.labels: full label set. Takes a dict with "root" and "tier". */}}
{{- define "task-tracker.labels" -}}
helm.sh/chart: {{ include "task-tracker.chart" .root }}
{{ include "task-tracker.selectorLabels" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
dso202/assignment: "03"
dso202/environment: {{ include "task-tracker.environment" .root | quote }}
{{- end }}
