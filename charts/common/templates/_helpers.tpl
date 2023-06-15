{{/*
Expand the name of the chart.
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Create a default fully qualified app name.
*/}}
{{- define "common.fullname" -}}
{{- if .Values.name -}}
{{- .Values.name -}}
{{- else if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{/*
  Create chart name and version as used by the chart label.
*/}}
{{- define "common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}


{{/*
  Set the serviceAccount name, if created
*/}}
{{- define "common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}


{{/*
  PodConfig holds the standard configuration for a Pod definition
*/}}
{{- define "common.podConfig" -}}
{{- with .Values.global.image.pullSecrets -}}
imagePullSecrets:
{{- toYaml . | nindent 2 }}
{{ end -}}
serviceAccountName: {{ include "common.serviceAccountName" . }}
securityContext: {{- toYaml .Values.podSecurityContext | nindent 2 }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
affinity:
  {{- if and (hasKey .Values "affinity") (.Values.affinity) -}}
    {{ toYaml .Values.affinity | nindent 2 }}
  {{- else if .affinitySelector }}
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        {{- range $key, $value := .affinitySelector }}
        - key: {{ $key }}
          operator: In
          values:
          - {{ $value }}
        {{- end }}
      topologyKey: "kubernetes.io/hostname"
  {{- else -}}
    {{ toYaml .Values.affinity | nindent 2 }}
  {{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}


{{/*
  Common labels to identify the Helm release
*/}}
{{- define "common.labels" -}}
helm.sh/chart: {{ include "common.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "common.selectorLabels" . }}
{{- end }}


{{/*
  Definition of the selector labels
*/}}
{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if hasKey .Values "serviceName" }}
app.kubernetes.io/component: {{ printf "%s" .Values.serviceName }}
{{- else if hasKey . "serviceName" }}
app.kubernetes.io/component: {{ printf "%s" .serviceName }}
{{- else }}
app.kubernetes.io/component: main
{{- end }}
{{- end }}

{{- define "common.podMetadata" -}}
labels: {{ include "common.selectorLabels" . | nindent 2 }}
{{- with .Values.podLabels }}
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.podAnnotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
  Standard container definition
*/}}
{{- define "common.containerConfig" -}}
securityContext: {{- toYaml .root.Values.securityContext | nindent 2 }}
{{- if .container.image.sha }}
image: "{{ .container.image.repository }}@sha256:{{ .container.image.sha }}"
{{- else }}
image: "{{ .container.image.repository }}:{{ .container.image.tag }}"
{{- end }}
{{- if .container.image.pullPolicy }}
imagePullPolicy: {{ .container.image.pullPolicy }}
{{- else }}
imagePullPolicy: {{ .root.Values.global.image.pullPolicy }}
{{- end }}
{{- if not ( empty .container.env ) }}
env:
  {{- $configMapNameOverride := .root.Values.global.configMapNameOverride }}
  {{- $root := .root }}
  {{- range $name, $value := .container.env }}
    {{- $order := int ( default 0 $value.order ) -}}
    {{- if ( le $order 0 ) }}
      {{- include "common.envVars" ( dict "root" $root "name" $name "value" $value "configMapNameOverride" $configMapNameOverride ) | indent 2 -}}
    {{- end }}
  {{- end }}
  {{- range $name, $value := .container.env }}
    {{- $order := int ( default 0 $value.order ) -}}
    {{- if ( gt $order 0 ) }}
      {{- include "common.envVars" ( dict "root" $root "name" $name "value" $value "configMapNameOverride" $configMapNameOverride ) | indent 2 -}}
    {{- end }}
  {{- end }}
{{- end }}
terminationMessagePolicy: FallbackToLogsOnError
resources: {{- toYaml .container.resources | nindent 2 }}
{{- end }}

{{/*
  Environment variables definition
*/}}
{{- define "common.envVars" }}
{{- if eq ( default "value" .value.type ) "value" }}
- name: {{ .name | quote }}
  {{- dict "value" .value.value | toYaml | nindent 2 }}
{{- else if or (eq ( default "value" .value.type ) "configMap") (eq ( default "value" .value.type ) "secret") }}
- name: {{ .name | quote }}
  valueFrom:
    {{ .value.type }}KeyRef:
      {{ if and (hasKey .value "name" ) ( eq .value.name "self" ) -}}
      name: {{ include "common.fullname" . }}
      {{ else -}}
      name: {{ default .value.name ( get .configMapNameOverride .value.name ) | quote }}
      {{ end -}}
      key: {{ .value.key | quote }}
{{- else }}
{{- if ne .value.type "none" }}
- name: {{ .name | quote }}
  valueFrom:
  {{- toYaml .value.valueFrom | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}