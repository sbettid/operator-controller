{{/*
Expand the name of the chart.
*/}}
{{- define "olmv1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "olmv1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the name of the active component for a prefix, but _only_ if one is enabled
*/}}
{{- define "component.name.prefix" -}}
{{- if and (not .Values.options.operatorController.enabled) (not .Values.options.catalogd.enabled) (include "objectController.enabled" .) -}}
object-controller-
{{- else if and (.Values.options.operatorController.enabled) (not .Values.options.catalogd.enabled) -}}
operator-controller-
{{- else if and (not .Values.options.operatorController.enabled) (.Values.options.catalogd.enabled) -}}
catalogd-
{{- end -}}
{{- end -}}

{{/*
Return the version of OLMv1 deployed by the chart.
*/}}
{{- define "olmv1.version" -}}
{{- .Chart.AppVersion | default "devel" -}}
{{- end -}}

{{/*
Return a container image reference. If the given image has neither a tag nor a digest,
the chart appVersion is appended as tag. Registry ports (e.g. localhost:5000/foo) are not
considered a tag.
Usage: {{ include "olmv1.image" (dict "image" .Values.options.catalogd.deployment.image "context" $) }}
*/}}
{{- define "olmv1.image" -}}
{{- $image := required "an image must be set for each enabled component" .image -}}
{{- $lastSegment := last (splitList "/" $image) -}}
{{- if or (contains "@" $image) (contains ":" $lastSegment) -}}
{{- $image -}}
{{- else -}}
{{- printf "%s:%s" $image (include "olmv1.version" .context) -}}
{{- end -}}
{{- end -}}

{{/*
Return the version suffix used for versioned certificate secret names.
Development builds render the "git-version" placeholder, which the Makefile replaces when
generating release and e2e manifests.
*/}}
{{- define "olmv1.certVersion" -}}
{{- $version := include "olmv1.version" . -}}
{{- if eq $version "devel" -}}
git-version
{{- else -}}
{{- $version -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "olmv1.labels" -}}
app.kubernetes.io/part-of: olm
{{- end }}

{{/*
Common annoations
*/}}
{{- define "olmv1.annotations" -}}
olm.operatorframework.io/feature-set: {{ .Values.options.featureSet -}}{{- if .Values.options.e2e.enabled -}}-e2e{{- end -}}
{{- end }}

{{/*
Insertion of additional rules for RBAC
*/}}

{{/*
Returns "operator-controller", "catalogd" or "olmv1" depending on enabled components
*/}}
{{- define "olmv1.label.name" -}}
{{- if and (not .Values.options.operatorController.enabled) (not .Values.options.catalogd.enabled) (include "objectController.enabled" .) -}}
object-controller
{{- else if (and .Values.options.operatorController.enabled (not .Values.options.catalogd.enabled)) -}}
operator-controller
{{- else if (and (not .Values.options.operatorController.enabled) .Values.options.catalogd.enabled) -}}
catalogd
{{- else -}}
olmv1
{{- end -}}
{{- end -}}

{{/*
Default to a separate object-controller whenever operator-controller uses Boxcutter.
An explicit enabled value also permits installing object-controller on its own.
Disabling it while Boxcutter is active would leave ClusterObjectSets without a controller.
Return an empty string when disabled so the helper can be used in conditionals.
*/}}
{{- define "objectController.enabled" -}}
{{- $operatorController := .Values.options.operatorController | default dict -}}
{{- $features := $operatorController.features | default dict -}}
{{- if and $operatorController.enabled (has "BoxcutterRuntime" $features.enabled) (has "BoxcutterRuntime" $features.disabled) -}}
{{- fail "BoxcutterRuntime cannot appear in both options.operatorController.features.enabled and options.operatorController.features.disabled" -}}
{{- end -}}
{{- $boxcutterEnabled := and $operatorController.enabled (has "BoxcutterRuntime" $features.enabled) (not (has "BoxcutterRuntime" $features.disabled)) -}}
{{- if and $boxcutterEnabled (eq (toJson .Values.options.objectController.enabled) "false") -}}
{{- fail "options.objectController.enabled=false is incompatible with enabled BoxcutterRuntime" -}}
{{- end -}}
{{- $enabled := .Values.options.objectController.enabled -}}
{{- if eq (toJson $enabled) "null" -}}
{{- $enabled = $boxcutterEnabled -}}
{{- end -}}
{{- if $enabled -}}
{{- if ne .Values.options.featureSet "experimental" -}}
{{- fail "objectController requires options.featureSet=experimental" -}}
{{- end -}}
true
{{- end -}}
{{- end -}}

{{/*
When rendering with OpenShift, only one of the main components (catalogd, operatorController)
should be enabled
*/}}
{{- if .Values.options.openshift.enabled -}}
{{- if and .Values.options.catalogd.enabled .Values.options.operatorController.enabled -}}
{{- fail "When rendering Openshift, only one of {catalogd, operatorController} should also be enabled" -}}
{{- end -}}
{{- end -}}
