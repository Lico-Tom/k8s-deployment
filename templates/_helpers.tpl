{{/*
通用命名与标签助手模板。
所有模板通过 include "..." 引用，避免各处重复拼接。
*/}}

{{/*
展开成 "name" 或 "name-override"（nameOverride 生效时）
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
资源名全称：优先 fullnameOverride，其次 release 名 + chart 名拼接，总长不超过 63 字符
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
用于 metadata 里的 app.kubernetes.io/name 等标签的 chart 名
*/}}
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
公共标签集，所有资源都应引用
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: openapi-generator-python
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
选择器标签，Deployment/Service/HPA 必须保持一致，且不可变
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount 名称
*/}}
{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
镜像地址：image.tag 为空时回落到 Chart.AppVersion
*/}}
{{- define "chart.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) }}
{{- end }}

{{/*
ConfigMap 名称（外部引用或本 chart 自建）
*/}}
{{- define "chart.configMapName" -}}
{{- if .Values.configMap.create }}
{{- printf "%s-config" (include "chart.fullname" .) }}
{{- else }}
{{- .Values.configMap.existingName }}
{{- end }}
{{- end }}

{{/*
Secret 名称
*/}}
{{- define "chart.secretName" -}}
{{- if .Values.secret.create }}
{{- printf "%s-secret" (include "chart.fullname" .) }}
{{- else }}
{{- .Values.secret.existingName }}
{{- end }}
{{- end }}

{{/*
PVC 名称：复用已有卷时返回其名字，否则固定为 <fullname>-data
*/}}
{{- define "chart.pvcName" -}}
{{- if .Values.persistence.enabled }}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- printf "%s-data" (include "chart.fullname" .) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
ServiceMonitor 名称，按 Prometheus Operator 惯例加 -metrics 后缀
*/}}
{{- define "chart.serviceMonitorName" -}}
{{- printf "%s-metrics" (include "chart.fullname" .) }}
{{- end }}
