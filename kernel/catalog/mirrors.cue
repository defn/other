@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

// mirror_images is the catalog lockfile for all external container images
// used by apps in the platform. Each key is the fully-qualified source
// image (e.g. "ghcr.io/coder/coder").
//
// Lifecycle:
//   1. Discover images in rendered manifests (kubectl get pods -A)
//   2. Add entries with source + tag + digest (crane digest)
//   3. sync-mirrors copies upstream → local OCI registry
//   4. kustomize images entries rewrite refs to local mirror
// Invariant: every entry key must equal "source:tag". Any drift between
// the lookup key and the inner fields fails cue vet immediately with a
// "conflicting values" error naming the entry, rather than silently
// producing stale kustomize image rewrites.
//
// Background: app generator (go/lib/gen/app/app.go) builds
// kustomization.yaml's `images:` `newTag` fields by looking up each
// image's entry in this catalog and using the INNER `tag` field -- NOT
// the entry key. The buggy shape was:
//     "source:vNEW": {source: "source", tag: "vOLD", digest: <old>}
// which made kustomize pin vOLD while everything else said vNEW. The
// `_keyCheck` field is a hidden (underscore-prefixed) CUE field that
// unifies K (the aliased entry key, via aliasv2 ~(K,_) syntax) with the
// string "\(source):\(tag)". If the two disagree, unification fails at
// `cue vet` time. See AIDR-00066 and go/lib/stamp/mirror.go.
mirror_images: [string]~(K,_): schema.#MirrorImage & {
	source:    string
	tag:       string
	_keyCheck: K & "\(source):\(tag)"
}

// mirror_registry is the OCI registry used for mirroring.
// All environments share the same local registry.
mirror_registry: "host.k3d.internal:5000"

mirror_images: {
	// ArgoCD
	"ecr-public.aws.com/docker/library/redis:8.2.3-alpine": {
		source: "ecr-public.aws.com/docker/library/redis"
		tag:    "8.2.3-alpine"
		digest: "sha256:835a74c1f6fd19b4f4643b71d47c2fcf63c648cdc558585b0910c18dfb208b0f"
	}

	// Capsule
	"ghcr.io/projectcapsule/capsule:v0.12.4": {
		source: "ghcr.io/projectcapsule/capsule"
		tag:    "v0.12.4"
		digest: "sha256:4b4c69c92d8907580e18e1bb44e9641467df2caa94e6ad33913f30b0b1cb3aa9"
	}
	"docker.io/clastix/kubectl:v1.35": {
		source: "docker.io/clastix/kubectl"
		tag:    "v1.35"
		digest: "sha256:245d1a9020b8b1369918cede56087e1ea42f69d3bf05c2ebd37afead56c0300c"
	}

	// cert-manager
	"quay.io/jetstack/cert-manager-controller:v1.20.2": {
		source: "quay.io/jetstack/cert-manager-controller"
		tag:    "v1.20.2"
		digest: "sha256:fe0623d7d04a382c888f03343a3a2da716e0d96ad3d5d790c0ebcbcb2a4329a5"
	}
	"quay.io/jetstack/cert-manager-cainjector:v1.20.2": {
		source: "quay.io/jetstack/cert-manager-cainjector"
		tag:    "v1.20.2"
		digest: "sha256:6f5a644135887b2aa7d5cc145072fa56421560e3586ff1f184358022d490f4e1"
	}
	"quay.io/jetstack/cert-manager-webhook:v1.20.2": {
		source: "quay.io/jetstack/cert-manager-webhook"
		tag:    "v1.20.2"
		digest: "sha256:baf651128b9f05c426cbd5e60e2036bf382c99ca270f49d0757d6f7d2452f4e5"
	}
	"quay.io/jetstack/cert-manager-startupapicheck:v1.20.2": {
		source: "quay.io/jetstack/cert-manager-startupapicheck"
		tag:    "v1.20.2"
		digest: "sha256:4e2a69b4a0cc9627905bbeecf720f95d5153ca39cacdab923d2748e73556792b"
	}

	// Reloader
	"ghcr.io/stakater/reloader:v1.4.16": {
		source: "ghcr.io/stakater/reloader"
		tag:    "v1.4.16"
		digest: "sha256:4e0db5b629ad5b50ccadae6f31f5916adab300dc3801482503f4984da4727e30"
	}

	// trust-manager
	"quay.io/jetstack/trust-manager:v0.22.1": {
		source: "quay.io/jetstack/trust-manager"
		tag:    "v0.22.1"
		digest: "sha256:23e2ab0711d77c3d25a7297d480883e8d037659db88dcdc0dab788a08a1b2097"
	}
	"quay.io/jetstack/trust-pkg-debian-bookworm:20230311-deb12u1.5": {
		source: "quay.io/jetstack/trust-pkg-debian-bookworm"
		tag:    "20230311-deb12u1.5"
		digest: "sha256:66657fde11b4b28718d5fa698d79906a6807f2697dd43f4166581410aa045b71"
	}

	// ACK IAM
	"public.ecr.aws/aws-controllers-k8s/iam-controller:1.6.3": {
		source: "public.ecr.aws/aws-controllers-k8s/iam-controller"
		tag:    "1.6.3"
		digest: "sha256:c32e2037335fd03695e064efe56b1a3776e2bd57593f77e91429d1f94963614a"
	}

	// Argo Rollouts
	"quay.io/argoproj/argo-rollouts:v1.9.0": {
		source: "quay.io/argoproj/argo-rollouts"
		tag:    "v1.9.0"
		digest: "sha256:fd2f03738e743b6634f5b087bdc959a3777cfb41c0ef32fc88f118b2e6d00270"
	}

	// BuildBuddy

	// CloudNativePG
	"ghcr.io/cloudnative-pg/cloudnative-pg:1.29.0": {
		source: "ghcr.io/cloudnative-pg/cloudnative-pg"
		tag:    "1.29.0"
		digest: "sha256:2da1c2ff083d6fc38a9e60cd915e2629411709dca2465c9d8f87ac4c3cbe2806"
	}

	// Coder

	// External DNS
	"registry.k8s.io/external-dns/external-dns:v0.20.0": {
		source: "registry.k8s.io/external-dns/external-dns"
		tag:    "v0.20.0"
		digest: "sha256:69eba9f08bd21ee5e16fb8055862a844e3d0e753421cecac123e2d80912543d5"
	}

	// External Secrets
	"ghcr.io/external-secrets/external-secrets:v2.3.0": {
		source: "ghcr.io/external-secrets/external-secrets"
		tag:    "v2.3.0"
		digest: "sha256:c425f51f422506c380550ad32fbf155412c7be84dd1c4b196130dcf04497be80"
	}

	// Goldilocks
	"us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.14.1": {
		source: "us-docker.pkg.dev/fairwinds-ops/oss/goldilocks"
		tag:    "v4.14.1"
		digest: "sha256:0286dbeee240ebb04f3e4287f5a997869b1dcce5c246504aa20d9335cf48d0c0"
	}

	// Karpenter
	"public.ecr.aws/karpenter/controller:1.11.1": {
		source: "public.ecr.aws/karpenter/controller"
		tag:    "1.11.1"
		digest: "sha256:001bce8d2de3e095b910df23859a02c6744358f13339076e9408bd912d078abb"
	}

	// KEDA
	"ghcr.io/kedacore/keda:2.19.0": {
		source: "ghcr.io/kedacore/keda"
		tag:    "2.19.0"
		digest: "sha256:a70fa9a8b0dcb888f7a2af1b0a6ebfdee1b159c169fbaea113b011db948a6b3a"
	}
	"ghcr.io/kedacore/keda-metrics-apiserver:2.19.0": {
		source: "ghcr.io/kedacore/keda-metrics-apiserver"
		tag:    "2.19.0"
		digest: "sha256:21cf76cfdb67ec8aee54396b9aa8cfdb1b7942cb71f5722e80ae9deff8e70ebb"
	}
	"ghcr.io/kedacore/keda-admission-webhooks:2.19.0": {
		source: "ghcr.io/kedacore/keda-admission-webhooks"
		tag:    "2.19.0"
		digest: "sha256:342c975281dd7e1ae80d602981e3e1316251e1c0c336d18034b475a47a9d563d"
	}

	// Kyverno
	"registry.k8s.io/kubectl:v1.34.3": {
		source: "registry.k8s.io/kubectl"
		tag:    "v1.34.3"
		digest: "sha256:6ce78c335505eb75728df3eb77f8a86786ca93108a656466a2f30b51cb05e4f0"
	}

	// Linkerd
	"cr.l5d.io/linkerd/controller:stable-2.14.10": {
		source: "cr.l5d.io/linkerd/controller"
		tag:    "stable-2.14.10"
		digest: "sha256:8ea58190a619c7a830378e994bd5fb1b93671a6e3df48fd4bc76fb88eafc2df1"
	}
	"cr.l5d.io/linkerd/policy-controller:stable-2.14.10": {
		source: "cr.l5d.io/linkerd/policy-controller"
		tag:    "stable-2.14.10"
		digest: "sha256:29beaf12ef0b790196129b2d9dc1409b62c31d1de5c60d9b6dde478d9d701bbc"
	}
	"cr.l5d.io/linkerd/proxy:stable-2.14.10": {
		source: "cr.l5d.io/linkerd/proxy"
		tag:    "stable-2.14.10"
		digest: "sha256:4537d922e55bb227a758f2b142fbaaeb087ddab42d0ca09ce7a6a6348d656ea8"
	}
	"cr.l5d.io/linkerd/proxy-init:v2.2.3": {
		source: "cr.l5d.io/linkerd/proxy-init"
		tag:    "v2.2.3"
		digest: "sha256:c671ff86e0d370e80cc6e3e8220e375efebbeeca263d28c9bb53a4b37684f308"
	}

	// Metrics Server
	"registry.k8s.io/metrics-server/metrics-server:v0.8.0": {
		source: "registry.k8s.io/metrics-server/metrics-server"
		tag:    "v0.8.0"
		digest: "sha256:b7397ab392a571d81d9cf09cab8ef8d559fae5f4b3c04d283d7eb936aba2b360"
	}

	// OAuth2 Proxy
	"quay.io/oauth2-proxy/oauth2-proxy:v7.15.2": {
		source: "quay.io/oauth2-proxy/oauth2-proxy"
		tag:    "v7.15.2"
		digest: "sha256:aa0bd8dd5ab0c78e4c91c92755ad573a5f92241f88138b4141b8ec803463b4fd"
	}

	// Redis Operator
	"quay.io/opstree/redis-operator:v0.24.0": {
		source: "quay.io/opstree/redis-operator"
		tag:    "v0.24.0"
		digest: "sha256:b37aa7d2ff16aae03b8805847bc8977728667dd39e1fa98dbbc06ec52e94b3ab"
	}

	// Tailscale
	"tailscale/k8s-operator:v1.94.2": {
		source: "tailscale/k8s-operator"
		tag:    "v1.94.2"
		digest: "sha256:4c65ad47d3cbf5c001f5f3a51efd96b48669a7bb26ee6f87b17c7a59933d1203"
	}

	// TopoLVM
	"ghcr.io/topolvm/topolvm-with-sidecar:0.40.2": {
		source: "ghcr.io/topolvm/topolvm-with-sidecar"
		tag:    "0.40.2"
		digest: "sha256:887ca1c4fb62bd5cbe5df655a549479ac0ea8485d9bd6d8c3da89990bccfa1da"
	}

	// Traefik

	// VPA
	"registry.k8s.io/autoscaling/vpa-recommender:1.6.0": {
		source: "registry.k8s.io/autoscaling/vpa-recommender"
		tag:    "1.6.0"
		digest: "sha256:e157effc31888d150b2897f752cdba20d55497e62f7ec41fda2b6ed405c83d8a"
	}
	"registry.k8s.io/autoscaling/vpa-updater:1.6.0": {
		source: "registry.k8s.io/autoscaling/vpa-updater"
		tag:    "1.6.0"
		digest: "sha256:e157effc31888d150b2897f752cdba20d55497e62f7ec41fda2b6ed405c83d8a"
	}
	"registry.k8s.io/autoscaling/vpa-admission-controller:1.6.0": {
		source: "registry.k8s.io/autoscaling/vpa-admission-controller"
		tag:    "1.6.0"
		digest: "sha256:e157effc31888d150b2897f752cdba20d55497e62f7ec41fda2b6ed405c83d8a"
	}
	"alpine/kubectl:1.35.2": {
		source: "alpine/kubectl"
		tag:    "1.35.2"
		digest: "sha256:b017b9c0084a99fdf56053e58cbb16ec61be8b0c622ee4e06f1ec1804fbc7ff9"
	}
	"registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794": {
		source: "registry.k8s.io/ingress-nginx/kube-webhook-certgen"
		tag:    "v20230312-helm-chart-4.5.2-28-g66a760794"
		digest: "sha256:eb9e261b1e29eb33781dffee76a83d3bea848d8a0c18c38c0443f98f84b711a3"
	}

	// Actions Runner Controller
	"ghcr.io/actions/gha-runner-scale-set-controller:0.14.2": {
		source: "ghcr.io/actions/gha-runner-scale-set-controller"
		tag:    "0.14.2"
		digest: "sha256:1b4c7f62e971ab259a4b8798e48e2adaad4af747f45990f474ea5feefa03531d"
	}
	"ghcr.io/actions/actions-runner:2.323.0": {
		source: "ghcr.io/actions/actions-runner"
		tag:    "2.323.0"
		digest: "sha256:831a2607a2618e4b79d9323b4c72330f3861768a061c2b92a845e9d214d80e5b"
	}

	// River Queue
	"ghcr.io/riverqueue/riverui:0.15.0": {
		source: "ghcr.io/riverqueue/riverui"
		tag:    "0.15.0"
		digest: "sha256:1c6d3ae89e5cb3409d3013504d0fb06fb063b7ca50ac3014bc350735d84046e5"
	}

	// Temporal
	"temporalio/server:1.30.3": {
		source: "temporalio/server"
		tag:    "1.30.3"
		digest: "sha256:30b50f53d09210d6f81b2039e60911dfbc35df44b6ec7aafebb8b9e443174d3c"
	}
	"temporalio/admin-tools:1.30.3": {
		source: "temporalio/admin-tools"
		tag:    "1.30.3"
		digest: "sha256:30b50f53d09210d6f81b2039e60911dfbc35df44b6ec7aafebb8b9e443174d3c"
	}
	"temporalio/ui:2.48.1": {
		source: "temporalio/ui"
		tag:    "2.48.1"
		digest: "sha256:edb5dd1b3e0ddb35611939dde9b573533afd6fbafbbf077b73c7131a30ca91ff"
	}

	// k3k -- controller, k3s server (for nested clusters), shared-mode kubelet.
	// k3s is a fixed pin per AIDR-00129; nested clusters that need a different
	// k3s version add their own mirror entry here.
	"rancher/k3k:v1.1.0-rc6": {
		source: "rancher/k3k"
		tag:    "v1.1.0-rc6"
		digest: "sha256:d560433043d23ac4ae4193faaf93b543902b7d3dc435dc842637a888769cde86"
	}
	"rancher/k3s:v1.35.4-k3s1": {
		source: "rancher/k3s"
		tag:    "v1.35.4-k3s1"
		digest: "sha256:475e036b3fd595472c13ec708c148ffd95459d5f9e40e6df76ba4d5b27098570"
	}
	"rancher/k3k-kubelet:v1.1.0-rc6": {
		source: "rancher/k3k-kubelet"
		tag:    "v1.1.0-rc6"
		digest: "sha256:b286cd7536d9f14a5233948dde1995c047ce53c0071a8e1636746cd3d6e11d7b"
	}

	"ghcr.io/dexidp/dex:v2.45.1": {
		source: "ghcr.io/dexidp/dex"
		tag:    "v2.45.1"
		digest: "sha256:8499afd690c437f52301efd2b05b2455da5bd2dfc20332cd697dc9937f808462"
	}

	"ghcr.io/external-secrets/external-secrets:v2.4.1": {
		source: "ghcr.io/external-secrets/external-secrets"
		tag:    "v2.4.1"
		digest: "sha256:9440a40b394791a5e93f3f7e1b33399ecbdc0e38273de1d69ed83fe12936fc09"
	}

	"registry.k8s.io/external-dns/external-dns:v0.21.0": {
		source: "registry.k8s.io/external-dns/external-dns"
		tag:    "v0.21.0"
		digest: "sha256:f53faaf71cb270d1ca9dce6ea0c94bfebf1a18696263487f0fbc74b9bf2bd7ff"
	}

	"ghcr.io/kyverno/readiness-checker:v1.18.0": {
		source: "ghcr.io/kyverno/readiness-checker"
		tag:    "v1.18.0"
		digest: "sha256:7aa69cb6f70c3264ab45eef50a401d93687cbaceecad608e074e0776724d6012"
	}

	"reg.kyverno.io/kyverno/background-controller:v1.18.0": {
		source: "reg.kyverno.io/kyverno/background-controller"
		tag:    "v1.18.0"
		digest: "sha256:fd6d30964297f1c94c2d741a1c44d055994cd4354e6f7e718cad59e6b5aa6c66"
	}

	"reg.kyverno.io/kyverno/cleanup-controller:v1.18.0": {
		source: "reg.kyverno.io/kyverno/cleanup-controller"
		tag:    "v1.18.0"
		digest: "sha256:a2a060b731f1ea54de2295b886c600d65af032fec18096a816424acfe8dec7d2"
	}

	"reg.kyverno.io/kyverno/kyverno-cli:v1.18.0": {
		source: "reg.kyverno.io/kyverno/kyverno-cli"
		tag:    "v1.18.0"
		digest: "sha256:1e99a199adb36cedddf5c3e2fc24a150e26cf2e18b9e8dfe505a3c862647a4eb"
	}

	"reg.kyverno.io/kyverno/kyverno:v1.18.0": {
		source: "reg.kyverno.io/kyverno/kyverno"
		tag:    "v1.18.0"
		digest: "sha256:cb033c200dc85be0a4d38e1a72894038a0c067d73f1ce6aedd569f9769a3d262"
	}

	"reg.kyverno.io/kyverno/kyvernopre:v1.18.0": {
		source: "reg.kyverno.io/kyverno/kyvernopre"
		tag:    "v1.18.0"
		digest: "sha256:60b53ebf646f788e6e5d312f9cbf267d7537ec14afec68bde2e1dad55c552cc7"
	}

	"reg.kyverno.io/kyverno/reports-controller:v1.18.0": {
		source: "reg.kyverno.io/kyverno/reports-controller"
		tag:    "v1.18.0"
		digest: "sha256:0090bf10eabae091ceb48c38fb894580b63c4e76e40137b7972f5895f0402110"
	}

	"temporalio/admin-tools:1.31.0": {
		source: "temporalio/admin-tools"
		tag:    "1.31.0"
		digest: "sha256:3e68adcd54195a7c1222e99f2dbc32a4fdbf44ad69e3bb48e21e85c4bf417c2e"
	}

	"temporalio/server:1.31.0": {
		source: "temporalio/server"
		tag:    "1.31.0"
		digest: "sha256:b021b3b58c3f169634cdbb0451fcc0e69e8190b40454323362c7c52bbd4ff7b9"
	}

	"temporalio/ui:2.49.1": {
		source: "temporalio/ui"
		tag:    "2.49.1"
		digest: "sha256:a066bdf5c4de689cabaf80cc357871f1db5e6d750a6bcfc42e877b913e31ef24"
	}

	"docker.io/traefik:v3.7.0": {
		source: "docker.io/traefik"
		tag:    "v3.7.0"
		digest: "sha256:eb328e2c806c53aafbbace6c451fa54d268961261a85452fcf0fb752a30c17be"
	}

	"ghcr.io/topolvm/topolvm-with-sidecar:0.41.0": {
		source: "ghcr.io/topolvm/topolvm-with-sidecar"
		tag:    "0.41.0"
		digest: "sha256:5faf5b94557516ae0f6fa7d329a5a4305e22aa2dc464af7641b31f2aca618036"
	}

	"quay.io/argoproj/argocd:v3.4.2": {
		source: "quay.io/argoproj/argocd"
		tag:    "v3.4.2"
		digest: "sha256:c612d570cb6d6ff29afb72932c1bfe98a1ecc234df50f8ea4873fb7066e760fc"
	}

	"ghcr.io/cloudnative-pg/cloudnative-pg:1.29.1": {
		source: "ghcr.io/cloudnative-pg/cloudnative-pg"
		tag:    "1.29.1"
		digest: "sha256:0dfff19ba7b52ca25851a1010028b6940fff2e233290465af1cfb08a5f3f4661"
	}

	"ghcr.io/coder/coder:v2.33.3": {
		source: "ghcr.io/coder/coder"
		tag:    "v2.33.3"
		digest: "sha256:56cced9a62e8d5e7e02a61ca5798f201e0aafe2a75ad1fd63e400eae045d59cd"
	}

	"buildbuddy.bbcr.io/public/buildbuddy-app-onprem:v2.269.0": {
		source: "buildbuddy.bbcr.io/public/buildbuddy-app-onprem"
		tag:    "v2.269.0"
		digest: "sha256:7656a5ddb7d717144b2f356919ada9a14ca6cfcb29166d97a223215cb4d66729"
	}

	"ghcr.io/external-secrets/external-secrets:v2.5.0": {
		source: "ghcr.io/external-secrets/external-secrets"
		tag:    "v2.5.0"
		digest: "sha256:45e7bee4e743331288df01efce0e35b41738cffdc89c86a235359a5153257489"
	}

	"docker.io/traefik:v3.7.1": {
		source: "docker.io/traefik"
		tag:    "v3.7.1"
		digest: "sha256:6b9cbca6fac42ab0075f5437d8dc1685cfd188626d8d515839ea94f8b6271c42"
	}

	"public.ecr.aws/karpenter/controller:1.12.1": {
		source: "public.ecr.aws/karpenter/controller"
		tag:    "1.12.1"
		digest: "sha256:61c1872a00f6eb4ba89d830d359d4c61757d0239a89ecfb748d609a9a81ea1f2"
	}

	"public.ecr.aws/aws-controllers-k8s/iam-controller:1.6.4": {
		source: "public.ecr.aws/aws-controllers-k8s/iam-controller"
		tag:    "1.6.4"
		digest: "sha256:aa74603041cab1cb3e039f6869b892414459bd5a4ee53b55998d0a8ddeeda53d"
	}

	"rancher/k3k:v1.1.0": {
		source: "rancher/k3k"
		tag:    "v1.1.0"
		digest: "sha256:878703e38a543cb36734193fc3d74c0a4609450f619d801d45904b9d73a96fbb"
	}
}
