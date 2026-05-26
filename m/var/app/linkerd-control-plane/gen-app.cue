@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "linkerd-destination": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-destination"
		namespace: "linkerd"
	}
}
objects: ServiceAccount: "linkerd-heartbeat": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "heartbeat"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}
}
objects: ServiceAccount: "linkerd-identity": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-identity"
		namespace: "linkerd"
	}
}
objects: ServiceAccount: "linkerd-proxy-injector": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-proxy-injector"
		namespace: "linkerd"
	}
}
objects: Role: "ext-namespace-metadata-linkerd-config": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		name:      "ext-namespace-metadata-linkerd-config"
		namespace: "linkerd"
	}
	rules: [{
		apiGroups: [""]
		resourceNames: ["linkerd-config"]
		resources: ["configmaps"]
		verbs: ["get"]
	}]
}
objects: Role: "linkerd-heartbeat": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: "linkerd.io/control-plane-ns": "linkerd"
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}
	rules: [{
		apiGroups: [""]
		resourceNames: ["linkerd-config"]
		resources: ["configmaps"]
		verbs: ["get"]
	}]
}
objects: Role: "remote-discovery": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/part-of":          "Linkerd"
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "remote-discovery"
		namespace: "linkerd"
	}
	rules: [{
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "linkerd-heartbeat": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: "linkerd.io/control-plane-ns": "linkerd"
		name: "linkerd-heartbeat"
	}
	rules: [{
		apiGroups: [""]
		resources: ["namespaces"]
		verbs: ["list"]
	}, {
		apiGroups: ["linkerd.io"]
		resources: ["serviceprofiles"]
		verbs: ["list"]
	}]
}
objects: ClusterRole: "linkerd-linkerd-destination": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-destination"
	}
	rules: [{
		apiGroups: ["apps"]
		resources: ["replicasets"]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: ["batch"]
		resources: ["jobs"]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: [
			"pods",
			"endpoints",
			"services",
			"nodes",
		]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: ["linkerd.io"]
		resources: ["serviceprofiles"]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}]
}
objects: ClusterRole: "linkerd-linkerd-identity": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-identity"
	}
	rules: [{
		apiGroups: ["authentication.k8s.io"]
		resources: ["tokenreviews"]
		verbs: ["create"]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}]
}
objects: ClusterRole: "linkerd-linkerd-proxy-injector": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-proxy-injector"
	}
	rules: [{
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}, {
		apiGroups: [""]
		resources: [
			"namespaces",
			"replicationcontrollers",
		]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"apps",
		]
		resources: [
			"deployments",
			"replicasets",
			"daemonsets",
			"statefulsets",
		]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"batch",
		]
		resources: [
			"cronjobs",
			"jobs",
		]
		verbs: [
			"list",
			"get",
			"watch",
		]
	}]
}
objects: ClusterRole: "linkerd-policy": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/part-of":          "Linkerd"
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-policy"
	}
	rules: [{
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: ["deployments"]
		verbs: ["get"]
	}, {
		apiGroups: ["policy.linkerd.io"]
		resources: [
			"authorizationpolicies",
			"httproutes",
			"meshtlsauthentications",
			"networkauthentications",
			"servers",
			"serverauthorizations",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["gateway.networking.k8s.io"]
		resources: ["httproutes"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["policy.linkerd.io"]
		resources: ["httproutes/status"]
		verbs: ["patch"]
	}, {
		apiGroups: ["gateway.networking.k8s.io"]
		resources: ["httproutes/status"]
		verbs: ["patch"]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"create",
			"get",
			"patch",
		]
	}]
}
objects: RoleBinding: "linkerd-destination-remote-discovery": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/part-of":          "Linkerd"
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-destination-remote-discovery"
		namespace: "linkerd"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "remote-discovery"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-destination"
		namespace: "linkerd"
	}]
}
objects: RoleBinding: "linkerd-heartbeat": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: "linkerd.io/control-plane-ns": "linkerd"
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "linkerd-heartbeat"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}]
}
objects: ClusterRoleBinding: "linkerd-destination-policy": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/part-of":          "Linkerd"
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-destination-policy"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "linkerd-policy"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-destination"
		namespace: "linkerd"
	}]
}
objects: ClusterRoleBinding: "linkerd-heartbeat": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: "linkerd.io/control-plane-ns": "linkerd"
		name: "linkerd-heartbeat"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "linkerd-heartbeat"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}]
}
objects: ClusterRoleBinding: "linkerd-linkerd-destination": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-destination"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "linkerd-linkerd-destination"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-destination"
		namespace: "linkerd"
	}]
}
objects: ClusterRoleBinding: "linkerd-linkerd-identity": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-identity"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "linkerd-linkerd-identity"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "linkerd-identity"
		namespace: "linkerd"
	}]
}
objects: ClusterRoleBinding: "linkerd-linkerd-proxy-injector": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-linkerd-proxy-injector"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "linkerd-linkerd-proxy-injector"
	}
	subjects: [{
		apiGroup:  ""
		kind:      "ServiceAccount"
		name:      "linkerd-proxy-injector"
		namespace: "linkerd"
	}]
}
objects: ConfigMap: "linkerd-config": {
	apiVersion: "v1"
	data: {
		"linkerd-crds-chart-version": "linkerd-crds-1.0.0-edge"
		values: """
			clusterDomain: cluster.local
			clusterNetworks: 10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16
			cniEnabled: false
			commonLabels: {}
			controlPlaneTracing: false
			controlPlaneTracingNamespace: linkerd-jaeger
			controllerImage: cr.l5d.io/linkerd/controller
			controllerImageVersion: ""
			controllerLogFormat: plain
			controllerLogLevel: info
			controllerReplicas: 1
			controllerUID: 2103
			debugContainer:
			  image:
			    name: cr.l5d.io/linkerd/debug
			    pullPolicy: ""
			    version: ""
			deploymentStrategy:
			  rollingUpdate:
			    maxSurge: 25%
			    maxUnavailable: 25%
			disableHeartBeat: false
			enableEndpointSlices: true
			enableH2Upgrade: true
			enablePSP: false
			enablePodAntiAffinity: false
			enablePodDisruptionBudget: false
			enablePprof: false
			heartbeatSchedule: 0 8 * * *
			identity:
			  externalCA: true
			  issuer:
			    clockSkewAllowance: 20s
			    issuanceLifetime: 24h0m0s
			    scheme: kubernetes.io/tls
			    tls:
			      crtPEM: ""
			  kubeAPI:
			    clientBurst: 200
			    clientQPS: 100
			  serviceAccountTokenProjection: true
			identityTrustAnchorsPEM: placeholder-for-deterministic-render
			identityTrustDomain: cluster.local
			imagePullPolicy: IfNotPresent
			imagePullSecrets: []
			kubeAPI:
			  clientBurst: 200
			  clientQPS: 100
			linkerdVersion: stable-2.14.10
			networkValidator:
			  connectAddr: 1.1.1.1:20001
			  enableSecurityContext: true
			  listenAddr: 0.0.0.0:4140
			  logFormat: plain
			  logLevel: debug
			  timeout: 10s
			nodeSelector:
			  kubernetes.io/os: linux
			podAnnotations: {}
			podLabels: {}
			podMonitor:
			  controller:
			    enabled: true
			    namespaceSelector: |
			      matchNames:
			        - {{ .Release.Namespace }}
			        - linkerd-viz
			        - linkerd-jaeger
			  enabled: false
			  labels: {}
			  proxy:
			    enabled: true
			  scrapeInterval: 10s
			  scrapeTimeout: 10s
			  serviceMirror:
			    enabled: true
			policyController:
			  image:
			    name: cr.l5d.io/linkerd/policy-controller
			    pullPolicy: ""
			    version: ""
			  logLevel: info
			  probeNetworks:
			  - 0.0.0.0/0
			  resources:
			    cpu:
			      limit: ""
			      request: ""
			    ephemeral-storage:
			      limit: ""
			      request: ""
			    memory:
			      limit: ""
			      request: ""
			policyValidator:
			  caBundle: placeholder
			  crtPEM: ""
			  externalSecret: true
			  injectCaFrom: ""
			  injectCaFromSecret: ""
			  namespaceSelector:
			    matchExpressions:
			    - key: config.linkerd.io/admission-webhooks
			      operator: NotIn
			      values:
			      - disabled
			priorityClassName: ""
			profileValidator:
			  caBundle: placeholder
			  crtPEM: ""
			  externalSecret: true
			  injectCaFrom: ""
			  injectCaFromSecret: ""
			  namespaceSelector:
			    matchExpressions:
			    - key: config.linkerd.io/admission-webhooks
			      operator: NotIn
			      values:
			      - disabled
			prometheusUrl: ""
			proxy:
			  await: true
			  cores: 0
			  defaultInboundPolicy: all-unauthenticated
			  disableInboundProtocolDetectTimeout: false
			  disableOutboundProtocolDetectTimeout: false
			  enableExternalProfiles: false
			  image:
			    name: cr.l5d.io/linkerd/proxy
			    pullPolicy: ""
			    version: ""
			  inboundConnectTimeout: 100ms
			  inboundDiscoveryCacheUnusedTimeout: 90s
			  logFormat: plain
			  logLevel: warn,linkerd=info,trust_dns=error
			  opaquePorts: 25,587,3306,4444,5432,6379,9300,11211
			  outboundConnectTimeout: 1000ms
			  outboundDiscoveryCacheUnusedTimeout: 5s
			  ports:
			    admin: 4191
			    control: 4190
			    inbound: 4143
			    outbound: 4140
			  requireIdentityOnInboundPorts: ""
			  resources:
			    cpu:
			      limit: ""
			      request: ""
			    ephemeral-storage:
			      limit: ""
			      request: ""
			    memory:
			      limit: ""
			      request: ""
			  shutdownGracePeriod: ""
			  uid: 2102
			  waitBeforeExitSeconds: 0
			proxyInit:
			  closeWaitTimeoutSecs: 0
			  ignoreInboundPorts: 4567,4568
			  ignoreOutboundPorts: 4567,4568
			  image:
			    name: cr.l5d.io/linkerd/proxy-init
			    pullPolicy: ""
			    version: v2.2.3
			  iptablesMode: legacy
			  kubeAPIServerPorts: 443,6443
			  logFormat: ""
			  logLevel: ""
			  privileged: false
			  resources:
			    cpu:
			      limit: 100m
			      request: 100m
			    ephemeral-storage:
			      limit: ""
			      request: ""
			    memory:
			      limit: 20Mi
			      request: 20Mi
			  runAsRoot: false
			  runAsUser: 65534
			  skipSubnets: ""
			  xtMountPath:
			    mountPath: /run
			    name: linkerd-proxy-init-xtables-lock
			proxyInjector:
			  caBundle: placeholder
			  crtPEM: ""
			  externalSecret: true
			  injectCaFrom: ""
			  injectCaFromSecret: ""
			  namespaceSelector:
			    matchExpressions:
			    - key: config.linkerd.io/admission-webhooks
			      operator: NotIn
			      values:
			      - disabled
			    - key: kubernetes.io/metadata.name
			      operator: NotIn
			      values:
			      - kube-system
			      - cert-manager
			  objectSelector:
			    matchExpressions:
			    - key: linkerd.io/control-plane-component
			      operator: DoesNotExist
			    - key: linkerd.io/cni-resource
			      operator: DoesNotExist
			runtimeClassName: ""
			webhookFailurePolicy: Ignore

			"""
	}
	kind: "ConfigMap"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "controller"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-config"
		namespace: "linkerd"
	}
}
objects: Service: "linkerd-dst": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-dst"
		namespace: "linkerd"
	}
	spec: {
		ports: [{
			name:       "grpc"
			port:       8086
			targetPort: 8086
		}]
		selector: "linkerd.io/control-plane-component": "destination"
		type: "ClusterIP"
	}
}
objects: Service: "linkerd-dst-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-dst-headless"
		namespace: "linkerd"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			name:       "grpc"
			port:       8086
			targetPort: 8086
		}]
		selector: "linkerd.io/control-plane-component": "destination"
	}
}
objects: Service: "linkerd-identity": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-identity"
		namespace: "linkerd"
	}
	spec: {
		ports: [{
			name:       "grpc"
			port:       8080
			targetPort: 8080
		}]
		selector: "linkerd.io/control-plane-component": "identity"
		type: "ClusterIP"
	}
}
objects: Service: "linkerd-identity-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-identity-headless"
		namespace: "linkerd"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			name:       "grpc"
			port:       8080
			targetPort: 8080
		}]
		selector: "linkerd.io/control-plane-component": "identity"
	}
}
objects: Service: "linkerd-policy": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-policy"
		namespace: "linkerd"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			name:       "grpc"
			port:       8090
			targetPort: 8090
		}]
		selector: "linkerd.io/control-plane-component": "destination"
	}
}
objects: Service: "linkerd-policy-validator": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-policy-validator"
		namespace: "linkerd"
	}
	spec: {
		ports: [{
			name:       "policy-https"
			port:       443
			targetPort: "policy-https"
		}]
		selector: "linkerd.io/control-plane-component": "destination"
		type: "ClusterIP"
	}
}
objects: Service: "linkerd-proxy-injector": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: {
			"config.linkerd.io/opaque-ports": "443"
			"linkerd.io/created-by":          "linkerd/helm stable-2.14.10"
		}
		labels: {
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-proxy-injector"
		namespace: "linkerd"
	}
	spec: {
		ports: [{
			name:       "proxy-injector"
			port:       443
			targetPort: "proxy-injector"
		}]
		selector: "linkerd.io/control-plane-component": "proxy-injector"
		type: "ClusterIP"
	}
}
objects: Service: "linkerd-sp-validator": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-sp-validator"
		namespace: "linkerd"
	}
	spec: {
		ports: [{
			name:       "sp-validator"
			port:       443
			targetPort: "sp-validator"
		}]
		selector: "linkerd.io/control-plane-component": "destination"
		type: "ClusterIP"
	}
}
objects: Deployment: "linkerd-destination": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"app.kubernetes.io/name":             "destination"
			"app.kubernetes.io/part-of":          "Linkerd"
			"app.kubernetes.io/version":          "stable-2.14.10"
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-destination"
		namespace: "linkerd"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
			"linkerd.io/proxy-deployment":        "linkerd-destination"
		}
		strategy: rollingUpdate: {
			maxSurge:       "25%"
			maxUnavailable: "25%"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":                                "93cf325f94c8c88e85ae231c17d7d5f2e546093b1d484ee6cba129afd306a629"
					"cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
					"config.linkerd.io/default-inbound-policy":       "all-unauthenticated"
					"linkerd.io/created-by":                          "linkerd/helm stable-2.14.10"
					"linkerd.io/proxy-version":                       "stable-2.14.10"
					"linkerd.io/trust-root-sha256":                   "f47da48f8dbaee205cf65048ff4cc5f2cde47cb16a2074f4b0a3fd6760939c44"
				}
				labels: {
					"linkerd.io/control-plane-component": "destination"
					"linkerd.io/control-plane-ns":        "linkerd"
					"linkerd.io/proxy-deployment":        "linkerd-destination"
					"linkerd.io/workload-ns":             "linkerd"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "_pod_name"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "_pod_ns"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name: "_pod_nodeName"
						valueFrom: fieldRef: fieldPath: "spec.nodeName"
					}, {
						name:  "LINKERD2_PROXY_LOG"
						value: "warn,linkerd=info,trust_dns=error"
					}, {
						name:  "LINKERD2_PROXY_LOG_FORMAT"
						value: "plain"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_ADDR"
						value: "localhost.:8086"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_ADDR"
						value: "localhost.:8090"
					}, {
						name:  "LINKERD2_PROXY_POLICY_WORKLOAD"
						value: "$(_pod_ns):$(_pod_name)"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DEFAULT_POLICY"
						value: "all-unauthenticated"
					}, {
						name:  "LINKERD2_PROXY_POLICY_CLUSTER_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_CONNECT_TIMEOUT"
						value: "100ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_TIMEOUT"
						value: "1000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "5s"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "90s"
					}, {
						name:  "LINKERD2_PROXY_CONTROL_LISTEN_ADDR"
						value: "0.0.0.0:4190"
					}, {
						name:  "LINKERD2_PROXY_ADMIN_LISTEN_ADDR"
						value: "0.0.0.0:4191"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_LISTEN_ADDR"
						value: "127.0.0.1:4140"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_LISTEN_ADDR"
						value: "0.0.0.0:4143"
					}, {
						name: "LINKERD2_PROXY_INBOUND_IPS"
						valueFrom: fieldRef: fieldPath: "status.podIPs"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS"
						value: "8086,8090,8443,9443,9990,9996,9997"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_SUFFIXES"
						value: "svc.cluster.local."
					}, {
						name:  "LINKERD2_PROXY_INBOUND_ACCEPT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS_DISABLE_PROTOCOL_DETECTION"
						value: "25,587,3306,4444,5432,6379,9300,11211"
					}, {
						name: "LINKERD2_PROXY_DESTINATION_CONTEXT"
						value: """
	{"ns":"$(_pod_ns)", "nodeName":"$(_pod_nodeName)", "pod":"$(_pod_name)"}

	"""
					}, {
						name: "_pod_sa"
						valueFrom: fieldRef: fieldPath: "spec.serviceAccountName"
					}, {
						name:  "_l5d_ns"
						value: "linkerd"
					}, {
						name:  "_l5d_trustdomain"
						value: "cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_DIR"
						value: "/var/run/linkerd/identity/end-entity"
					}, {
						name: "LINKERD2_PROXY_IDENTITY_TRUST_ANCHORS"
						valueFrom: configMapKeyRef: {
							key:  "ca-bundle.crt"
							name: "linkerd-identity-trust-roots"
						}
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_TOKEN_FILE"
						value: "/var/run/secrets/tokens/linkerd-identity-token"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_ADDR"
						value: "linkerd-identity-headless.linkerd.svc.cluster.local.:8080"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_LOCAL_NAME"
						value: "$(_pod_sa).$(_pod_ns).serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_NAME"
						value: "linkerd-identity.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					lifecycle: postStart: exec: command: [
						"/usr/lib/linkerd/linkerd-await",
						"--timeout=2m",
						"--port=4191",
					]
					livenessProbe: {
						httpGet: {
							path: "/live"
							port: 4191
						}
						initialDelaySeconds: 10
					}
					name: "linkerd-proxy"
					ports: [{
						containerPort: 4143
						name:          "linkerd-proxy"
					}, {
						containerPort: 4191
						name:          "linkerd-admin"
					}]
					readinessProbe: {
						httpGet: {
							path: "/ready"
							port: 4191
						}
						initialDelaySeconds: 2
					}
					resources: null
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2102
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/var/run/linkerd/identity/end-entity"
						name:      "linkerd-identity-end-entity"
					}, {
						mountPath: "/var/run/secrets/tokens"
						name:      "linkerd-identity-token"
					}]
				}, {
					args: [
						"destination",
						"-addr=:8086",
						"-controller-namespace=linkerd",
						"-enable-h2-upgrade=true",
						"-log-level=info",
						"-log-format=plain",
						"-enable-endpoint-slices=true",
						"-cluster-domain=cluster.local",
						"-identity-trust-domain=cluster.local",
						"-default-opaque-ports=25,587,3306,4444,5432,6379,9300,11211",
						"-enable-pprof=false",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/ping"
							port: 9996
						}
						initialDelaySeconds: 10
					}
					name: "destination"
					ports: [{
						containerPort: 8086
						name:          "grpc"
					}, {
						containerPort: 9996
						name:          "admin-http"
					}]
					readinessProbe: {
						failureThreshold: 7
						httpGet: {
							path: "/ready"
							port: 9996
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
				}, {
					args: [
						"sp-validator",
						"-log-level=info",
						"-log-format=plain",
						"-enable-pprof=false",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/ping"
							port: 9997
						}
						initialDelaySeconds: 10
					}
					name: "sp-validator"
					ports: [{
						containerPort: 8443
						name:          "sp-validator"
					}, {
						containerPort: 9997
						name:          "admin-http"
					}]
					readinessProbe: {
						failureThreshold: 7
						httpGet: {
							path: "/ready"
							port: 9997
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/var/run/linkerd/tls"
						name:      "sp-tls"
						readOnly:  true
					}]
				}, {
					args: [
						"--admin-addr=0.0.0.0:9990",
						"--control-plane-namespace=linkerd",
						"--grpc-addr=0.0.0.0:8090",
						"--server-addr=0.0.0.0:9443",
						"--server-tls-key=/var/run/linkerd/tls/tls.key",
						"--server-tls-certs=/var/run/linkerd/tls/tls.crt",
						"--cluster-networks=10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16",
						"--identity-domain=cluster.local",
						"--cluster-domain=cluster.local",
						"--default-policy=all-unauthenticated",
						"--log-level=info",
						"--log-format=plain",
						"--default-opaque-ports=25,587,3306,4444,5432,6379,9300,11211",
						"--probe-networks=0.0.0.0/0",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/policy-controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: httpGet: {
						path: "/live"
						port: "admin-http"
					}
					name: "policy"
					ports: [{
						containerPort: 8090
						name:          "grpc"
					}, {
						containerPort: 9990
						name:          "admin-http"
					}, {
						containerPort: 9443
						name:          "policy-https"
					}]
					readinessProbe: {
						failureThreshold: 7
						httpGet: {
							path: "/ready"
							port: "admin-http"
						}
						initialDelaySeconds: 10
					}
					resources: null
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/var/run/linkerd/tls"
						name:      "policy-tls"
						readOnly:  true
					}]
				}]
				initContainers: [{
					args: [
						"--incoming-proxy-port",
						"4143",
						"--outgoing-proxy-port",
						"4140",
						"--proxy-uid",
						"2102",
						"--inbound-ports-to-ignore",
						"4190,4191,4567,4568",
						"--outbound-ports-to-ignore",
						"443,6443",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy-init:v2.2.3"
					imagePullPolicy: "IfNotPresent"
					name:            "linkerd-init"
					resources: {
						limits: {
							cpu:    "100m"
							memory: "20Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "20Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: add: [
							"NET_ADMIN",
							"NET_RAW",
						]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              65534
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/run"
						name:      "linkerd-proxy-init-xtables-lock"
					}]
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: seccompProfile: type: "RuntimeDefault"
				serviceAccountName: "linkerd-destination"
				volumes: [{
					name: "sp-tls"
					secret: secretName: "linkerd-sp-validator-k8s-tls"
				}, {
					name: "policy-tls"
					secret: secretName: "linkerd-policy-validator-k8s-tls"
				}, {
					emptyDir: {}
					name: "linkerd-proxy-init-xtables-lock"
				}, {
					name: "linkerd-identity-token"
					projected: sources: [{
						serviceAccountToken: {
							audience:          "identity.l5d.io"
							expirationSeconds: 86400
							path:              "linkerd-identity-token"
						}
					}]
				}, {
					emptyDir: medium: "Memory"
					name: "linkerd-identity-end-entity"
				}]
			}
		}
	}
}
objects: Deployment: "linkerd-identity": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"app.kubernetes.io/name":             "identity"
			"app.kubernetes.io/part-of":          "Linkerd"
			"app.kubernetes.io/version":          "stable-2.14.10"
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-identity"
		namespace: "linkerd"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"linkerd.io/control-plane-component": "identity"
			"linkerd.io/control-plane-ns":        "linkerd"
			"linkerd.io/proxy-deployment":        "linkerd-identity"
		}
		strategy: rollingUpdate: {
			maxSurge:       "25%"
			maxUnavailable: "25%"
		}
		template: {
			metadata: {
				annotations: {
					"cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
					"config.linkerd.io/default-inbound-policy":       "all-unauthenticated"
					"linkerd.io/created-by":                          "linkerd/helm stable-2.14.10"
					"linkerd.io/proxy-version":                       "stable-2.14.10"
					"linkerd.io/trust-root-sha256":                   "f47da48f8dbaee205cf65048ff4cc5f2cde47cb16a2074f4b0a3fd6760939c44"
				}
				labels: {
					"linkerd.io/control-plane-component": "identity"
					"linkerd.io/control-plane-ns":        "linkerd"
					"linkerd.io/proxy-deployment":        "linkerd-identity"
					"linkerd.io/workload-ns":             "linkerd"
				}
			}
			spec: {
				containers: [{
					args: [
						"identity",
						"-log-level=info",
						"-log-format=plain",
						"-controller-namespace=linkerd",
						"-identity-trust-domain=cluster.local",
						"-identity-issuance-lifetime=24h0m0s",
						"-identity-clock-skew-allowance=20s",
						"-identity-scheme=kubernetes.io/tls",
						"-enable-pprof=false",
						"-kube-apiclient-qps=100",
						"-kube-apiclient-burst=200",
					]
					env: [{
						name:  "LINKERD_DISABLED"
						value: "linkerd-await cannot block the identity controller"
					}]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/ping"
							port: 9990
						}
						initialDelaySeconds: 10
					}
					name: "identity"
					ports: [{
						containerPort: 8080
						name:          "grpc"
					}, {
						containerPort: 9990
						name:          "admin-http"
					}]
					readinessProbe: {
						failureThreshold: 7
						httpGet: {
							path: "/ready"
							port: 9990
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/var/run/linkerd/identity/issuer"
						name:      "identity-issuer"
					}, {
						mountPath: "/var/run/linkerd/identity/trust-roots/"
						name:      "trust-roots"
					}]
				}, {
					env: [{
						name: "_pod_name"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "_pod_ns"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name: "_pod_nodeName"
						valueFrom: fieldRef: fieldPath: "spec.nodeName"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS_REQUIRE_TLS"
						value: "8080"
					}, {
						name:  "LINKERD2_PROXY_LOG"
						value: "warn,linkerd=info,trust_dns=error"
					}, {
						name:  "LINKERD2_PROXY_LOG_FORMAT"
						value: "plain"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_ADDR"
						value: "linkerd-dst-headless.linkerd.svc.cluster.local.:8086"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_ADDR"
						value: "linkerd-policy.linkerd.svc.cluster.local.:8090"
					}, {
						name:  "LINKERD2_PROXY_POLICY_WORKLOAD"
						value: "$(_pod_ns):$(_pod_name)"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DEFAULT_POLICY"
						value: "all-unauthenticated"
					}, {
						name:  "LINKERD2_PROXY_POLICY_CLUSTER_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_CONNECT_TIMEOUT"
						value: "100ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_TIMEOUT"
						value: "1000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "5s"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "90s"
					}, {
						name:  "LINKERD2_PROXY_CONTROL_LISTEN_ADDR"
						value: "0.0.0.0:4190"
					}, {
						name:  "LINKERD2_PROXY_ADMIN_LISTEN_ADDR"
						value: "0.0.0.0:4191"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_LISTEN_ADDR"
						value: "127.0.0.1:4140"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_LISTEN_ADDR"
						value: "0.0.0.0:4143"
					}, {
						name: "LINKERD2_PROXY_INBOUND_IPS"
						valueFrom: fieldRef: fieldPath: "status.podIPs"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS"
						value: "8080,9990"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_SUFFIXES"
						value: "svc.cluster.local."
					}, {
						name:  "LINKERD2_PROXY_INBOUND_ACCEPT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS_DISABLE_PROTOCOL_DETECTION"
						value: "25,587,3306,4444,5432,6379,9300,11211"
					}, {
						name: "LINKERD2_PROXY_DESTINATION_CONTEXT"
						value: """
	{"ns":"$(_pod_ns)", "nodeName":"$(_pod_nodeName)", "pod":"$(_pod_name)"}

	"""
					}, {
						name: "_pod_sa"
						valueFrom: fieldRef: fieldPath: "spec.serviceAccountName"
					}, {
						name:  "_l5d_ns"
						value: "linkerd"
					}, {
						name:  "_l5d_trustdomain"
						value: "cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_DIR"
						value: "/var/run/linkerd/identity/end-entity"
					}, {
						name: "LINKERD2_PROXY_IDENTITY_TRUST_ANCHORS"
						valueFrom: configMapKeyRef: {
							key:  "ca-bundle.crt"
							name: "linkerd-identity-trust-roots"
						}
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_TOKEN_FILE"
						value: "/var/run/secrets/tokens/linkerd-identity-token"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_ADDR"
						value: "localhost.:8080"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_LOCAL_NAME"
						value: "$(_pod_sa).$(_pod_ns).serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_NAME"
						value: "linkerd-identity.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/live"
							port: 4191
						}
						initialDelaySeconds: 10
					}
					name: "linkerd-proxy"
					ports: [{
						containerPort: 4143
						name:          "linkerd-proxy"
					}, {
						containerPort: 4191
						name:          "linkerd-admin"
					}]
					readinessProbe: {
						httpGet: {
							path: "/ready"
							port: 4191
						}
						initialDelaySeconds: 2
					}
					resources: null
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2102
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/var/run/linkerd/identity/end-entity"
						name:      "linkerd-identity-end-entity"
					}, {
						mountPath: "/var/run/secrets/tokens"
						name:      "linkerd-identity-token"
					}]
				}]
				initContainers: [{
					args: [
						"--incoming-proxy-port",
						"4143",
						"--outgoing-proxy-port",
						"4140",
						"--proxy-uid",
						"2102",
						"--inbound-ports-to-ignore",
						"4190,4191,4567,4568",
						"--outbound-ports-to-ignore",
						"443,6443",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy-init:v2.2.3"
					imagePullPolicy: "IfNotPresent"
					name:            "linkerd-init"
					resources: {
						limits: {
							cpu:    "100m"
							memory: "20Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "20Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: add: [
							"NET_ADMIN",
							"NET_RAW",
						]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              65534
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/run"
						name:      "linkerd-proxy-init-xtables-lock"
					}]
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: seccompProfile: type: "RuntimeDefault"
				serviceAccountName: "linkerd-identity"
				volumes: [{
					name: "identity-issuer"
					secret: secretName: "linkerd-identity-issuer"
				}, {
					configMap: name: "linkerd-identity-trust-roots"
					name: "trust-roots"
				}, {
					emptyDir: {}
					name: "linkerd-proxy-init-xtables-lock"
				}, {
					name: "linkerd-identity-token"
					projected: sources: [{
						serviceAccountToken: {
							audience:          "identity.l5d.io"
							expirationSeconds: 86400
							path:              "linkerd-identity-token"
						}
					}]
				}, {
					emptyDir: medium: "Memory"
					name: "linkerd-identity-end-entity"
				}]
			}
		}
	}
}
objects: Deployment: "linkerd-proxy-injector": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"app.kubernetes.io/name":             "proxy-injector"
			"app.kubernetes.io/part-of":          "Linkerd"
			"app.kubernetes.io/version":          "stable-2.14.10"
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-proxy-injector"
		namespace: "linkerd"
	}
	spec: {
		replicas: 1
		selector: matchLabels: "linkerd.io/control-plane-component": "proxy-injector"
		strategy: rollingUpdate: {
			maxSurge:       "25%"
			maxUnavailable: "25%"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":                                "5eafc731f1207a98b899385388ca9a1e15761423f8e42c638fbb87779e6c3a66"
					"cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
					"config.linkerd.io/default-inbound-policy":       "all-unauthenticated"
					"config.linkerd.io/opaque-ports":                 "8443"
					"linkerd.io/created-by":                          "linkerd/helm stable-2.14.10"
					"linkerd.io/proxy-version":                       "stable-2.14.10"
					"linkerd.io/trust-root-sha256":                   "f47da48f8dbaee205cf65048ff4cc5f2cde47cb16a2074f4b0a3fd6760939c44"
				}
				labels: {
					"linkerd.io/control-plane-component": "proxy-injector"
					"linkerd.io/control-plane-ns":        "linkerd"
					"linkerd.io/proxy-deployment":        "linkerd-proxy-injector"
					"linkerd.io/workload-ns":             "linkerd"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "_pod_name"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "_pod_ns"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name: "_pod_nodeName"
						valueFrom: fieldRef: fieldPath: "spec.nodeName"
					}, {
						name:  "LINKERD2_PROXY_LOG"
						value: "warn,linkerd=info,trust_dns=error"
					}, {
						name:  "LINKERD2_PROXY_LOG_FORMAT"
						value: "plain"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_ADDR"
						value: "linkerd-dst-headless.linkerd.svc.cluster.local.:8086"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_ADDR"
						value: "linkerd-policy.linkerd.svc.cluster.local.:8090"
					}, {
						name:  "LINKERD2_PROXY_POLICY_WORKLOAD"
						value: "$(_pod_ns):$(_pod_name)"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DEFAULT_POLICY"
						value: "all-unauthenticated"
					}, {
						name:  "LINKERD2_PROXY_POLICY_CLUSTER_NETWORKS"
						value: "10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_CONNECT_TIMEOUT"
						value: "100ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_TIMEOUT"
						value: "1000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "5s"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_DISCOVERY_IDLE_TIMEOUT"
						value: "90s"
					}, {
						name:  "LINKERD2_PROXY_CONTROL_LISTEN_ADDR"
						value: "0.0.0.0:4190"
					}, {
						name:  "LINKERD2_PROXY_ADMIN_LISTEN_ADDR"
						value: "0.0.0.0:4191"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_LISTEN_ADDR"
						value: "127.0.0.1:4140"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_LISTEN_ADDR"
						value: "0.0.0.0:4143"
					}, {
						name: "LINKERD2_PROXY_INBOUND_IPS"
						valueFrom: fieldRef: fieldPath: "status.podIPs"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS"
						value: "8443,9995"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_PROFILE_SUFFIXES"
						value: "svc.cluster.local."
					}, {
						name:  "LINKERD2_PROXY_INBOUND_ACCEPT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_OUTBOUND_CONNECT_KEEPALIVE"
						value: "10000ms"
					}, {
						name:  "LINKERD2_PROXY_INBOUND_PORTS_DISABLE_PROTOCOL_DETECTION"
						value: "25,587,3306,4444,5432,6379,9300,11211"
					}, {
						name: "LINKERD2_PROXY_DESTINATION_CONTEXT"
						value: """
	{"ns":"$(_pod_ns)", "nodeName":"$(_pod_nodeName)", "pod":"$(_pod_name)"}

	"""
					}, {
						name: "_pod_sa"
						valueFrom: fieldRef: fieldPath: "spec.serviceAccountName"
					}, {
						name:  "_l5d_ns"
						value: "linkerd"
					}, {
						name:  "_l5d_trustdomain"
						value: "cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_DIR"
						value: "/var/run/linkerd/identity/end-entity"
					}, {
						name: "LINKERD2_PROXY_IDENTITY_TRUST_ANCHORS"
						valueFrom: configMapKeyRef: {
							key:  "ca-bundle.crt"
							name: "linkerd-identity-trust-roots"
						}
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_TOKEN_FILE"
						value: "/var/run/secrets/tokens/linkerd-identity-token"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_ADDR"
						value: "linkerd-identity-headless.linkerd.svc.cluster.local.:8080"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_LOCAL_NAME"
						value: "$(_pod_sa).$(_pod_ns).serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_IDENTITY_SVC_NAME"
						value: "linkerd-identity.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_DESTINATION_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}, {
						name:  "LINKERD2_PROXY_POLICY_SVC_NAME"
						value: "linkerd-destination.linkerd.serviceaccount.identity.linkerd.cluster.local"
					}]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					lifecycle: postStart: exec: command: [
						"/usr/lib/linkerd/linkerd-await",
						"--timeout=2m",
						"--port=4191",
					]
					livenessProbe: {
						httpGet: {
							path: "/live"
							port: 4191
						}
						initialDelaySeconds: 10
					}
					name: "linkerd-proxy"
					ports: [{
						containerPort: 4143
						name:          "linkerd-proxy"
					}, {
						containerPort: 4191
						name:          "linkerd-admin"
					}]
					readinessProbe: {
						httpGet: {
							path: "/ready"
							port: 4191
						}
						initialDelaySeconds: 2
					}
					resources: null
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2102
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/var/run/linkerd/identity/end-entity"
						name:      "linkerd-identity-end-entity"
					}, {
						mountPath: "/var/run/secrets/tokens"
						name:      "linkerd-identity-token"
					}]
				}, {
					args: [
						"proxy-injector",
						"-log-level=info",
						"-log-format=plain",
						"-linkerd-namespace=linkerd",
						"-enable-pprof=false",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/ping"
							port: 9995
						}
						initialDelaySeconds: 10
					}
					name: "proxy-injector"
					ports: [{
						containerPort: 8443
						name:          "proxy-injector"
					}, {
						containerPort: 9995
						name:          "admin-http"
					}]
					readinessProbe: {
						failureThreshold: 7
						httpGet: {
							path: "/ready"
							port: 9995
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/var/run/linkerd/config"
						name:      "config"
					}, {
						mountPath: "/var/run/linkerd/identity/trust-roots"
						name:      "trust-roots"
					}, {
						mountPath: "/var/run/linkerd/tls"
						name:      "tls"
						readOnly:  true
					}]
				}]
				initContainers: [{
					args: [
						"--incoming-proxy-port",
						"4143",
						"--outgoing-proxy-port",
						"4140",
						"--proxy-uid",
						"2102",
						"--inbound-ports-to-ignore",
						"4190,4191,4567,4568",
						"--outbound-ports-to-ignore",
						"443,6443",
					]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/proxy-init:v2.2.3"
					imagePullPolicy: "IfNotPresent"
					name:            "linkerd-init"
					resources: {
						limits: {
							cpu:    "100m"
							memory: "20Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "20Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: add: [
							"NET_ADMIN",
							"NET_RAW",
						]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              65534
						seccompProfile: type: "RuntimeDefault"
					}
					terminationMessagePolicy: "FallbackToLogsOnError"
					volumeMounts: [{
						mountPath: "/run"
						name:      "linkerd-proxy-init-xtables-lock"
					}]
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: seccompProfile: type: "RuntimeDefault"
				serviceAccountName: "linkerd-proxy-injector"
				volumes: [{
					configMap: name: "linkerd-config"
					name: "config"
				}, {
					configMap: name: "linkerd-identity-trust-roots"
					name: "trust-roots"
				}, {
					name: "tls"
					secret: secretName: "linkerd-proxy-injector-k8s-tls"
				}, {
					emptyDir: {}
					name: "linkerd-proxy-init-xtables-lock"
				}, {
					name: "linkerd-identity-token"
					projected: sources: [{
						serviceAccountToken: {
							audience:          "identity.l5d.io"
							expirationSeconds: 86400
							path:              "linkerd-identity-token"
						}
					}]
				}, {
					emptyDir: medium: "Memory"
					name: "linkerd-identity-end-entity"
				}]
			}
		}
	}
}
objects: CronJob: "linkerd-heartbeat": {
	apiVersion: "batch/v1"
	kind:       "CronJob"
	metadata: {
		annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
		labels: {
			"app.kubernetes.io/name":             "heartbeat"
			"app.kubernetes.io/part-of":          "Linkerd"
			"app.kubernetes.io/version":          "stable-2.14.10"
			"linkerd.io/control-plane-component": "heartbeat"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name:      "linkerd-heartbeat"
		namespace: "linkerd"
	}
	spec: {
		concurrencyPolicy: "Replace"
		jobTemplate: spec: template: {
			metadata: {
				annotations: "linkerd.io/created-by": "linkerd/helm stable-2.14.10"
				labels: {
					"linkerd.io/control-plane-component": "heartbeat"
					"linkerd.io/workload-ns":             "linkerd"
				}
			}
			spec: {
				containers: [{
					args: [
						"heartbeat",
						"-controller-namespace=linkerd",
						"-log-level=info",
						"-log-format=plain",
						"-prometheus-url=http://prometheus.linkerd-viz.svc.cluster.local:9090",
					]
					env: [{
						name:  "LINKERD_DISABLED"
						value: "the heartbeat controller does not use the proxy"
					}]
					image:           "host.k3d.internal:5000/mirror/cr.l5d.io/linkerd/controller:stable-2.14.10"
					imagePullPolicy: "IfNotPresent"
					name:            "heartbeat"
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						runAsUser:              2103
						seccompProfile: type: "RuntimeDefault"
					}
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				restartPolicy: "Never"
				securityContext: seccompProfile: type: "RuntimeDefault"
				serviceAccountName: "linkerd-heartbeat"
			}
		}
		schedule:                   "0 8 * * *"
		successfulJobsHistoryLimit: 0
	}
}
objects: MutatingWebhookConfiguration: "linkerd-proxy-injector-webhook-config": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "MutatingWebhookConfiguration"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "proxy-injector"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-proxy-injector-webhook-config"
	}
	webhooks: [{
		admissionReviewVersions: [
			"v1",
			"v1beta1",
		]
		clientConfig: {
			caBundle: ""
			service: {
				name:      "linkerd-proxy-injector"
				namespace: "linkerd"
				path:      "/"
			}
		}
		failurePolicy: "Ignore"
		name:          "linkerd-proxy-injector.linkerd.io"
		namespaceSelector: matchExpressions: [{
			key:      "config.linkerd.io/admission-webhooks"
			operator: "NotIn"
			values: ["disabled"]
		}, {
			key:      "kubernetes.io/metadata.name"
			operator: "NotIn"
			values: [
				"kube-system",
				"cert-manager",
			]
		}]
		objectSelector: matchExpressions: [{
			key:      "linkerd.io/control-plane-component"
			operator: "DoesNotExist"
		}, {
			key:      "linkerd.io/cni-resource"
			operator: "DoesNotExist"
		}]
		rules: [{
			apiGroups: [""]
			apiVersions: ["v1"]
			operations: ["CREATE"]
			resources: [
				"pods",
				"services",
			]
		}]
		sideEffects: "None"
	}]
}
objects: ValidatingWebhookConfiguration: "linkerd-policy-validator-webhook-config": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "ValidatingWebhookConfiguration"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-policy-validator-webhook-config"
	}
	webhooks: [{
		admissionReviewVersions: [
			"v1",
			"v1beta1",
		]
		clientConfig: {
			caBundle: ""
			service: {
				name:      "linkerd-policy-validator"
				namespace: "linkerd"
				path:      "/"
			}
		}
		failurePolicy: "Ignore"
		name:          "linkerd-policy-validator.linkerd.io"
		namespaceSelector: matchExpressions: [{
			key:      "config.linkerd.io/admission-webhooks"
			operator: "NotIn"
			values: ["disabled"]
		}]
		rules: [{
			apiGroups: ["policy.linkerd.io"]
			apiVersions: ["*"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: [
				"authorizationpolicies",
				"httproutes",
				"networkauthentications",
				"meshtlsauthentications",
				"serverauthorizations",
				"servers",
			]
		}]
		sideEffects: "None"
	}]
}
objects: ValidatingWebhookConfiguration: "linkerd-sp-validator-webhook-config": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "ValidatingWebhookConfiguration"
	metadata: {
		labels: {
			"linkerd.io/control-plane-component": "destination"
			"linkerd.io/control-plane-ns":        "linkerd"
		}
		name: "linkerd-sp-validator-webhook-config"
	}
	webhooks: [{
		admissionReviewVersions: [
			"v1",
			"v1beta1",
		]
		clientConfig: {
			caBundle: ""
			service: {
				name:      "linkerd-sp-validator"
				namespace: "linkerd"
				path:      "/"
			}
		}
		failurePolicy: "Ignore"
		name:          "linkerd-sp-validator.linkerd.io"
		namespaceSelector: matchExpressions: [{
			key:      "config.linkerd.io/admission-webhooks"
			operator: "NotIn"
			values: ["disabled"]
		}]
		rules: [{
			apiGroups: ["linkerd.io"]
			apiVersions: [
				"v1alpha1",
				"v1alpha2",
			]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["serviceprofiles"]
		}]
		sideEffects: "None"
	}]
}
