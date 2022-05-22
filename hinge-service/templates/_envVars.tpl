{{- define "hinge-service.envVars" -}}
{{- /* }}
This iterates over containers.<name>.env, and populates k/v pairs. These set
environment variables inside of the given container.
{{- */}}
{{- if .Values.envVars -}}
  {{- range $key, $value := .Values.envVars }}
- name: {{ $key }}
  value: {{ $value | quote }}
  {{- end }}
{{- end }}

{{- /* }}
awsSecretsEnvironment defines environment level secrets. The name of the secret in
k8s is always <deployment-name>-aws
{{- */}}
{{- if .Values.awsSecretsEnvironment -}}
  {{- range $secretName, $secretValue := .Values.awsSecretsEnvironment }}
- name: {{ $secretName }}
  valueFrom:
    secretKeyRef:
      name: "{{ include "hinge-service.fullName" $ }}-aws"
      key: {{ $secretValue | quote }}
  {{- end }}
{{- end }}

{{- /* }}
awsSecretsService defines service level secrets. The name of the secret in k8s is always
<deployment-name>-aws
{{- */}}
{{- if .Values.awsSecretsService }}
  {{- range $secretName, $secretValue := .Values.awsSecretsService }}
- name: {{ $secretName }}
  valueFrom:
    secretKeyRef:
      name: "{{ include "hinge-service.fullName" $ }}-aws"
      key: {{ $secretValue | quote }}
  {{- end }}
{{- end }}

{{- /* }}
This block deals with regular secrets, which are set by containers.<name>.secrets.
The associated secret is always the name of the deployment.
{{- */}}
{{- if .Values.secrets }}
  {{- range $secret, $value := .Values.secrets }}
- name: {{ $secret }}
  valueFrom:
    secretKeyRef:
      name: {{ include "hinge-service.fullName" $ }}
      key: {{ $value | quote }}
  {{- end }}
{{- end }}

{{- /* }}
This sets some additional environment variables for things like Datadog.
{{- */}}
- name: AWS_REGION
  value: {{ .Values.awsRegion }}
- name: DD_AGENT_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: DD_ENV
  valueFrom:
    fieldRef:
      fieldPath: metadata.labels['tags.datadoghq.com/env']
- name: DD_SERVICE
  valueFrom:
    fieldRef:
      fieldPath: metadata.labels['tags.datadoghq.com/service']
- name: DD_VERSION
  valueFrom:
    fieldRef:
      fieldPath: metadata.labels['tags.datadoghq.com/version']
{{- end }}