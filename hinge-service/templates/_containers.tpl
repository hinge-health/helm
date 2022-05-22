{{- define "hinge-service.mainContainer" -}}
{{ $awsSecretsEnabled := false }}
{{- if .Values.awsSecretsService -}}
  {{- $awsSecretsEnabled = true -}}
{{- end -}}
{{- if .Values.awsSecretsEnvironment -}}
  {{- $awsSecretsEnabled = true -}}
{{- end -}}
- name: "main"
  image: "{{ include "hinge-service.imageRepository" . }}:{{ .Values.imageTag }}"
  imagePullPolicy: "{{ .Values.imagePullPolicy | default "Always" }}"
  stdin: true
  tty: true
  command:
    {{- toYaml .Values.command | default "[]" | nindent 4 }}
  args:
    {{- toYaml .Values.entrypoint | default "[]" | nindent 4 }}
  env:
    {{- include "hinge-service.envVars" . | nindent 2 }}
  securityContext:
    {{- toYaml .securityContext | nindent 4 }}
  ports:
    - containerPort: {{ required "container containerPort is required" .Values.containerPort }}
      protocol: TCP
  {{- include "hinge-service.probes" . | nindent 2 }}
  {{- if .Values.noTerm }}
  lifecycle:
    preStop:
      exec:
        command: [ "sleep", "inf" ]
  {{- end }}
  resources:
    {{- toYaml .resources | nindent 4 }}

{{- /* }}
For AWS secrets sync to work, we need to mount the secrets-store volume to the pod.
If we're not using AWS secrets, let's not bother mounting this.
Furthermore - none of our services have or will have persistent state outside of the
usual database culprits - if this changes, we'll need to change this to accommodate that.
{{- */}}
  {{- if $awsSecretsEnabled }}
  volumeMounts:
  - name: 'service-secrets'
    mountPath: '/mnt/secrets-store'
    readOnly: true
  {{- end}}
{{- end }}

{{- define "hinge-service.additionalContainer" -}}
{{ $awsSecretsEnabled := false }}
{{- if .Values.awsSecretsService -}}
  {{- $awsSecretsEnabled = true -}}
{{- end -}}
{{- if .Values.awsSecretsEnvironment -}}
  {{- $awsSecretsEnabled = true -}}
{{- end -}}
image: "{{ include "hinge-service.imageRepository" . }}:{{ .Values.imageTag }}"
imagePullPolicy: "{{ .Values.imagePullPolicy | default "Always" }}"
stdin: true
tty: true
env:
  {{- include "hinge-service.envVars" . | nindent 2 }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 4 }}
{{- if .Values.noTerm }}
lifecycle:
  preStop:
    exec:
      command: [ "sleep", "inf" ]
{{- end }}

{{- /* }}
For AWS secrets sync to work, we need to mount the secrets-store volume to the pod.
If we're not using AWS secrets, let's not bother mounting this.
Furthermore - none of our services have or will have persistent state outside of the
usual database culprits - if this changes, we'll need to change this to accommodate that.
{{- */}}
{{- if $awsSecretsEnabled }}
volumeMounts:
- name: 'service-secrets'
  mountPath: '/mnt/secrets-store'
  readOnly: true
{{- end}}
{{- end }}
