{{/*
Expand the name of the chart.
*/}}
{{- define "hinge-service.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hinge-service.fullName" -}}
{{- if .Values.fullNameOverride }}
{{- .Values.fullNameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hinge-service.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hinge-service.labels" -}}
helm.sh/chart: {{ include "hinge-service.chart" . }}
{{ include "hinge-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.imageTag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tags.datadoghq.com/env: "{{ required "environment must be present and valid e.g. dev|stage|prod" .Values.environment }}"
tags.datadoghq.com/service: "{{ include "hinge-service.fullName" . }}"
tags.datadoghq.com/version: {{ .Values.imageTag | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hinge-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hinge-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "hinge-service.serviceAccountName" -}}
{{- if .Values.serviceAccountCreate }}
{{- default (include "hinge-service.fullName" .) .Values.serviceAccountName }}
{{- else }}
{{- default "default" .Values.serviceAccountName }}
{{- end }}
{{- end }}

{{- define "hinge-service.probes" -}}
livenessProbe:
  {{- .Values.livenessProbeType | default "httpGet" | nindent 2 }}:
    {{- if eq .Values.livenessProbeType "httpGet" }}
    path: {{ .Values.livenessProbePath | default "/healthcheck" }}
    {{- end }}
    port: {{ .Values.livenessProbePort | default .Values.containerPort }}
  initialDelaySeconds: {{ .Values.livenessInitialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.livenessPeriodSeconds | default 5 }}
  failureThreshold: {{ .Values.livenessFailureThreshold | default 10 }}
readinessProbe:
  {{- .Values.readinessProbeType | default "httpGet" | nindent 2 }}:
    {{- if eq .Values.readinessProbeType "httpGet" }}
    path: {{ .Values.readinessProbePath | default "/healthcheck" }}
    {{- end }}
    port: {{ .Values.readinessProbePort | default .Values.containerPort }}
  initialDelaySeconds: {{ .Values.readinessInitialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.readinessPeriodSeconds | default 10 }}
  failureThreshold: {{ .Values.readinessFailureThreshold | default 2 }}
{{- end }}

{{- /*
hinge-service.util.merge will merge two YAML templates and output the result.
This takes an array of three values:
- the top context
- the template name of the overrides (destination)
- the template name of the base (source)
*/}}
{{- define "hinge-service.util.merge" -}}
{{- $top := first . -}}
{{- $overrides := fromYaml (include (index . 1) $top) | default (dict ) -}}
{{- $tpl := fromYaml (include (index . 2) $top) | default (dict ) -}}
{{- toYaml (merge $overrides $tpl) -}}
{{- end -}}

{{- define "hinge-service.youFail" }}
{{- $valid := list "dev" "stage" "prod" }}
{{- if not (has .Values.environment $valid) }}
{{- fail "environment must be dev|stage|prod" }}
{{- end -}}
{{- end -}}

{{- define "hinge-service.imageRepository" -}}
{{- $fullName := include "hinge-service.fullName" $ -}}
{{- if .Values.imageRepository -}}
{{- .Values.imageRepository -}}
{{- else -}}
711154312405.dkr.ecr.us-east-1.amazonaws.com/{{- $fullName -}}
{{- end -}}
{{- end }}