package controllers

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"math"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/MakeNowJust/heredoc"
	tfv1beta1 "github.com/defn/other/m/v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1"
	"github.com/defn/other/m/v/galleybytes--terraform-operator/pkg/utils"
	"github.com/go-logr/logr"
	getter "github.com/hashicorp/go-getter"
	localcache "github.com/patrickmn/go-cache"
	appsv1 "k8s.io/api/apps/v1"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/uuid"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	runtimecontroller "sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

//go:embed scripts/tf.sh
var defaultInlineTerraformTaskExecutionFile string

//go:embed scripts/setup.sh
var defaultInlineSetupTaskExecutionFile string

//go:embed scripts/noop.sh
var defaultInlineNoOpExecutionFile string

// ReconcileTofu reconciles a Tofu object
type ReconcileTofu struct {
	// This client, initialized using mgr.Client() above, is a split client
	// that reads objects from the cache and writes to the apiserver
	Client                  client.Client
	Scheme                  *runtime.Scheme
	Recorder                record.EventRecorder
	Log                     logr.Logger
	MaxConcurrentReconciles int
	Cache                   *localcache.Cache

	GlobalEnvFromConfigmapData map[string]string
	GlobalEnvFromSecretData    map[string][]byte
	GlobalEnvSuffix            string

	// InheritNodeSelector to use the controller's nodeSelectors for every task created by the controller.
	// Value of this field will come from the owning deployment and cached.
	InheritNodeSelector  bool
	NodeSelectorCacheKey string

	// InheritAffinity to use the controller's affinity rules for every task created by the controller
	// Value of this field will come from the owning deployment and cached.
	InheritAffinity  bool
	AffinityCacheKey string

	// InheritTolerations to use the controller's tolerations for every task created by the controller
	// Value of this field will come from the owning deployment and cached.
	InheritTolerations  bool
	TolerationsCacheKey string

	// When requireApproval is true, the require-approval plugin is injected into the plan pod
	// when generating the pod manifest. The require-approval image is not modifiable via the Tofu
	// Resource in order to ensure the highest compatibility with the other TFO projects (like
	// terraform-operator-api and terraform-operator-dashboard).
	RequireApprovalImage string
}

// createEnvFromSources adds any of the global environment vars defined at the controller scope
// and generates a configmap or secret that will be loaded into the resource Task pods.
//
// TODO Each time a new generation is created of the tfo resource, this "global" env from vars should
// generate a new configap and secret. The reason for this is to prevent a generation from producing a
// different plan when is was the controller that changed options. A new generation should be forced
// if the plan needs to change.
func (r ReconcileTofu) createEnvFromSources(ctx context.Context, tf *tfv1beta1.Tofu) error {

	resourceName := tf.Name
	resourceNamespace := tf.Namespace
	name := fmt.Sprintf("%s-%s", resourceName, r.GlobalEnvSuffix)
	if len(r.GlobalEnvFromConfigmapData) > 0 {
		configMap := corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Name:      name,
				Namespace: resourceNamespace,
			},
			Data: r.GlobalEnvFromConfigmapData,
		}
		controllerutil.SetControllerReference(tf, &configMap, r.Scheme)
		errOnCreate := r.Client.Create(ctx, &configMap)
		if errOnCreate != nil {
			if errors.IsAlreadyExists(errOnCreate) {
				errOnUpdate := r.Client.Update(ctx, &configMap)
				if errOnUpdate != nil {
					return errOnUpdate
				}
			} else {
				return errOnCreate
			}
		}
	}

	if len(r.GlobalEnvFromSecretData) > 0 {
		secret := corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      name,
				Namespace: resourceNamespace,
			},
			Data: r.GlobalEnvFromSecretData,
		}
		controllerutil.SetControllerReference(tf, &secret, r.Scheme)
		errOnCreate := r.Client.Create(ctx, &secret)
		if errOnCreate != nil {
			if errors.IsAlreadyExists(errOnCreate) {
				errOnUpdate := r.Client.Update(ctx, &secret)
				if errOnUpdate != nil {
					return errOnUpdate
				}
			} else {
				return errOnCreate
			}
		}
	}

	return nil
}

// listEnvFromSources makes an assumption that if global envs are defined in the controller, the
// configmap and secrets for the envs have been created or updated when initializing the workflow.
//
// This function will return the envFrom of the resources that should exist but does not validate that
// they do exist. If the configmap or secret is missing, force the generation of the tfo resource to update
// and the controller will recreate the missing resources.
func (r ReconcileTofu) listEnvFromSources(tf *tfv1beta1.Tofu) []corev1.EnvFromSource {
	envFrom := []corev1.EnvFromSource{}
	resourceName := tf.Name
	name := fmt.Sprintf("%s-%s", resourceName, r.GlobalEnvSuffix)

	if len(r.GlobalEnvFromConfigmapData) > 0 {
		// ConfigMap that should exist
		envFrom = append(envFrom, corev1.EnvFromSource{
			ConfigMapRef: &corev1.ConfigMapEnvSource{
				LocalObjectReference: corev1.LocalObjectReference{
					Name: name,
				},
			},
		})
	}

	if len(r.GlobalEnvFromSecretData) > 0 {
		// Secret that should exist
		envFrom = append(envFrom, corev1.EnvFromSource{
			SecretRef: &corev1.SecretEnvSource{
				LocalObjectReference: corev1.LocalObjectReference{
					Name: name,
				},
			},
		})
	}

	return envFrom
}

// SetupWithManager sets up the controller with the Manager.
func (r *ReconcileTofu) SetupWithManager(mgr ctrl.Manager) error {
	controllerOptions := runtimecontroller.Options{
		MaxConcurrentReconciles: r.MaxConcurrentReconciles,
	}

	err := ctrl.NewControllerManagedBy(mgr).
		For(&tfv1beta1.Tofu{}).
		Owns(&corev1.Pod{}).
		WithOptions(controllerOptions).
		Complete(r)
	if err != nil {
		return err
	}
	return nil
}

func terraformTaskList() []tfv1beta1.TaskName {
	return []tfv1beta1.TaskName{
		tfv1beta1.RunInit,
		tfv1beta1.RunInitDelete,
		tfv1beta1.RunPlan,
		tfv1beta1.RunPlanDelete,
		tfv1beta1.RunApply,
		tfv1beta1.RunApplyDelete,
	}
}

func scriptTaskList() []tfv1beta1.TaskName {
	return []tfv1beta1.TaskName{
		tfv1beta1.RunPreInit,
		tfv1beta1.RunPreInitDelete,
		tfv1beta1.RunPostInit,
		tfv1beta1.RunPostInitDelete,
		tfv1beta1.RunPrePlan,
		tfv1beta1.RunPrePlanDelete,
		tfv1beta1.RunPostPlan,
		tfv1beta1.RunPostPlanDelete,
		tfv1beta1.RunPreApply,
		tfv1beta1.RunPreApplyDelete,
		tfv1beta1.RunPostApply,
		tfv1beta1.RunPostApplyDelete,
	}
}

func setupTaskList() []tfv1beta1.TaskName {
	return []tfv1beta1.TaskName{
		tfv1beta1.RunSetup,
		tfv1beta1.RunSetupDelete,
	}
}

// ParsedAddress uses go-getter's detect mechanism to get the parsed url
// TODO ParsedAddress can be moved into it's own package
type ParsedAddress struct {
	// DetectedScheme is the name of the bin or protocol to use to fetch. For
	// example, git will be used to fetch git repos (over https or ssh
	// "protocol").
	DetectedScheme string `json:"detect"`

	// Path the target path for the downloaded file or directory
	Path string `json:"path"`

	// The files downloaded get called out in the terraform plan as -var-file
	UseAsVar bool `json:"useAsVar"`

	// Url is the raw address + query
	Url string `json:"url"`

	// Files are the files to find with a repo.
	Files []string `json:"files"`

	// Hash is also known as the `ref` query argument. For git this is the
	// commit-sha or branch-name to checkout.
	Hash string `json:"hash"`

	// UrlScheme is the protocol of the URL
	UrlScheme string `json:"protocol"`

	// Uri is the path of the URL after the proto://host.
	Uri string `json:"uri"`

	// Host is the host of the URL.
	Host string `json:"host"`

	// Port is the port to use when fetching the URL.
	Port string `json:"port"`

	// User is the user to use when fetching the URL.
	User string `json:"user"`

	// Repo when using a SCM is the URL of the repo which is the same as the
	// URL and omitting the query args.
	Repo string `json:"repo"`
}

type TaskOptions struct {
	annotations map[string]string

	// configMapSourceName (and configMapSourceKey) is used to populate an environment variable of the task pod.
	// When not empty should be understood by the task to use the configmap as the execution script
	configMapSourceName string
	// configMapSourceKey (and configMapSourceName) is used to populate an environment variable of the task pod.
	// When not empty should be understood by the task to use the configmap as the execution script
	configMapSourceKey string

	credentials           []tfv1beta1.Credentials
	env                   []corev1.EnvVar
	envFrom               []corev1.EnvFromSource
	generation            int64
	image                 string
	imagePullPolicy       corev1.PullPolicy
	inheritedAffinity     *corev1.Affinity
	inheritedNodeSelector map[string]string
	inheritedTolerations  []corev1.Toleration

	// inlineTaskExecutionFile is used to populate an environment variable of the task pod. When not empty the
	// task should use this filename which should exist from a configmap mount in the pod.
	inlineTaskExecutionFile string

	labels                              map[string]string
	mainModulePluginData                map[string]string
	namespace                           string
	outputsSecretName                   string
	outputsToInclude                    []string
	outputsToOmit                       []string
	policyRules                         []rbacv1.PolicyRule
	prefixedName                        string
	resourceLabels                      map[string]string
	resourceName                        string
	resourceUUID                        string
	task                                tfv1beta1.TaskName
	saveOutputs                         bool
	secretData                          map[string][]byte
	serviceAccount                      string
	cleanupDisk                         bool
	stripGenerationLabelOnOutputsSecret bool
	terraformModuleParsed               ParsedAddress
	terraformVersion                    string

	// urlSource is used to populate an environment variable of the task pod. When not empty is used by the task
	// as the download location for the script to execute in the task.
	urlSource string

	versionedName        string
	requireApproval      bool
	requireApprovalImage string
	restartPolicy        corev1.RestartPolicy

	volumes      []corev1.Volume
	volumeMounts []corev1.VolumeMount

	// When a plugin is defined to run as a sidecar, this field will be filled in and attached to current task
	sidecarPlugins []corev1.Pod
}

// taskOptionsFromSpec holds options extracted from the Tofu spec's TaskOptions.
type taskOptionsFromSpec struct {
	policyRules             []rbacv1.PolicyRule
	labels                  map[string]string
	annotations             map[string]string
	env                     []corev1.EnvVar
	envFrom                 []corev1.EnvFromSource
	restartPolicy           corev1.RestartPolicy
	volumes                 []corev1.Volume
	volumeMounts            []corev1.VolumeMount
	urlSource               string
	configMapSourceName     string
	configMapSourceKey      string
	inlineTaskExecutionFile string
}

// extractTaskOptionsFromSpec processes tf.Spec.TaskOptions and extracts settings
// applicable to the given task.
func extractTaskOptionsFromSpec(tf *tfv1beta1.Tofu, task tfv1beta1.TaskName, globalEnvFrom []corev1.EnvFromSource) taskOptionsFromSpec {
	opts := taskOptionsFromSpec{
		policyRules:   []rbacv1.PolicyRule{},
		labels:        make(map[string]string),
		annotations:   make(map[string]string),
		env:           []corev1.EnvVar{},
		envFrom:       globalEnvFrom,
		restartPolicy: corev1.RestartPolicyNever,
		volumes:       []corev1.Volume{},
		volumeMounts:  []corev1.VolumeMount{},
	}

	for _, taskOption := range tf.Spec.TaskOptions {
		appliesToThisTask := tfv1beta1.ListContainsTask(taskOption.For, task)
		appliesToAllTasks := tfv1beta1.ListContainsTask(taskOption.For, "*")

		// Collect options that apply to this task or all tasks
		if appliesToThisTask || appliesToAllTasks {
			opts.policyRules = append(opts.policyRules, taskOption.PolicyRules...)
			for key, value := range taskOption.Annotations {
				opts.annotations[key] = value
			}
			for key, value := range taskOption.Labels {
				opts.labels[key] = value
			}
			opts.env = append(opts.env, taskOption.Env...)
			opts.envFrom = append(opts.envFrom, taskOption.EnvFrom...)
			if taskOption.RestartPolicy != "" {
				opts.restartPolicy = taskOption.RestartPolicy
			}
			opts.volumes = append(opts.volumes, taskOption.Volumes...)
			opts.volumeMounts = append(opts.volumeMounts, taskOption.VolumeMounts...)
		}

		// Script configuration only applies to exact task matches (not wildcards)
		if appliesToThisTask {
			opts.urlSource = taskOption.Script.Source
			if configMapSelector := taskOption.Script.ConfigMapSelector; configMapSelector != nil {
				opts.configMapSourceName = configMapSelector.Name
				opts.configMapSourceKey = configMapSelector.Key
			}
			if taskOption.Script.Inline != "" {
				opts.inlineTaskExecutionFile = fmt.Sprintf("inline-%s.sh", task)
			}
		}
	}

	return opts
}

// resolveImages ensures all image configs have defaults set and returns the resolved images.
func resolveImages(spec *tfv1beta1.Images, terraformVersion string) *tfv1beta1.Images {
	images := spec
	if images == nil {
		images = &tfv1beta1.Images{}
	}

	// Tofu image
	if images.Tofu == nil {
		images.Tofu = &tfv1beta1.ImageConfig{ImagePullPolicy: corev1.PullIfNotPresent}
	}
	if images.Tofu.Image == "" {
		images.Tofu.Image = fmt.Sprintf("%s:%s", tfv1beta1.TerraformTaskImageRepoDefault, terraformVersion)
	} else {
		// Replace the tag with the specified terraform version
		baseImage := images.Tofu.Image
		if parts := strings.Split(baseImage, ":"); len(parts) > 1 {
			baseImage = strings.Join(parts[:len(parts)-1], ":")
		}
		images.Tofu.Image = fmt.Sprintf("%s:%s", baseImage, terraformVersion)
	}

	// Setup image
	if images.Setup == nil {
		images.Setup = &tfv1beta1.ImageConfig{ImagePullPolicy: corev1.PullIfNotPresent}
	}
	if images.Setup.Image == "" {
		images.Setup.Image = fmt.Sprintf("%s:%s", tfv1beta1.SetupTaskImageRepoDefault, tfv1beta1.SetupTaskImageTagDefault)
	}

	// Script image
	if images.Script == nil {
		images.Script = &tfv1beta1.ImageConfig{ImagePullPolicy: corev1.PullIfNotPresent}
	}
	if images.Script.Image == "" {
		images.Script.Image = fmt.Sprintf("%s:%s", tfv1beta1.ScriptTaskImageRepoDefault, tfv1beta1.ScriptTaskImageTagDefault)
	}

	return images
}

// taskImageConfig holds the resolved image and execution file for a task.
type taskImageConfig struct {
	image                   string
	imagePullPolicy         corev1.PullPolicy
	inlineTaskExecutionFile string
}

// resolveTaskImage determines which image and execution file to use based on task type.
func resolveTaskImage(task tfv1beta1.TaskName, images *tfv1beta1.Images, specifiedInlineFile string, urlSource string, configMapSourceName string, configMapSourceKey string) taskImageConfig {
	config := taskImageConfig{
		imagePullPolicy:         corev1.PullAlways,
		inlineTaskExecutionFile: specifiedInlineFile,
	}

	// Determine if we should use the default inline execution file
	hasCustomScript := specifiedInlineFile != "" || urlSource != "" || (configMapSourceName != "" && configMapSourceKey != "")

	switch {
	case tfv1beta1.ListContainsTask(terraformTaskList(), task):
		config.image = images.Tofu.Image
		config.imagePullPolicy = images.Tofu.ImagePullPolicy
		if !hasCustomScript {
			config.inlineTaskExecutionFile = "default-terraform.sh"
		}
	case tfv1beta1.ListContainsTask(scriptTaskList(), task):
		config.image = images.Script.Image
		config.imagePullPolicy = images.Script.ImagePullPolicy
		if !hasCustomScript {
			config.inlineTaskExecutionFile = "default-noop.sh"
		}
	case tfv1beta1.ListContainsTask(setupTaskList(), task):
		config.image = images.Setup.Image
		config.imagePullPolicy = images.Setup.ImagePullPolicy
		if !hasCustomScript {
			config.inlineTaskExecutionFile = "default-setup.sh"
		}
	}

	return config
}

// outputsConfig holds configuration for terraform outputs.
type outputsConfig struct {
	secretName                   string
	saveOutputs                  bool
	stripGenerationLabelOnSecret bool
	outputsToInclude             []string
	outputsToOmit                []string
}

// resolveOutputsConfig determines how terraform outputs should be saved.
func resolveOutputsConfig(tf *tfv1beta1.Tofu, versionedName string) outputsConfig {
	config := outputsConfig{
		secretName:       versionedName + "-outputs",
		outputsToInclude: tf.Spec.OutputsToInclude,
		outputsToOmit:    tf.Spec.OutputsToOmit,
	}

	if tf.Spec.OutputsSecret != "" {
		config.secretName = tf.Spec.OutputsSecret
		config.saveOutputs = true
		config.stripGenerationLabelOnSecret = true
	} else if tf.Spec.WriteOutputsToStatus {
		config.saveOutputs = true
	}

	return config
}

// buildResourceLabels creates the standard labels applied to task pods.
func buildResourceLabels(generation int64, resourceName, prefixedName, terraformVersion string, isPlugin bool) map[string]string {
	labels := map[string]string{
		"tofus.tf.defn.dev/generation":       fmt.Sprintf("%d", generation),
		"tofus.tf.defn.dev/resourceName":     utils.AutoHashLabeler(resourceName),
		"tofus.tf.defn.dev/podPrefix":        prefixedName,
		"tofus.tf.defn.dev/terraformVersion": terraformVersion,
		"app.kubernetes.io/name":             "terraform-operator",
		"app.kubernetes.io/component":        "terraform-operator-runner",
		"app.kubernetes.io/created-by":       "controller",
	}
	if isPlugin {
		labels["tofus.tf.defn.dev/isPlugin"] = "true"
	}
	return labels
}

func newTaskOptions(tf *tfv1beta1.Tofu, task tfv1beta1.TaskName, generation int64, globalEnvFrom []corev1.EnvFromSource, affinity *corev1.Affinity, nodeSelector map[string]string, tolerations []corev1.Toleration, requireApprovalImage string) TaskOptions {
	// Basic resource identifiers
	resourceName := tf.Name
	resourceUUID := string(tf.UID)
	prefixedName := tf.Status.PodNamePrefix
	versionedName := prefixedName + "-v" + fmt.Sprint(tf.Generation)

	terraformVersion := tf.Spec.TerraformVersion
	if terraformVersion == "" {
		terraformVersion = "latest"
	}

	// Extract task-specific options from spec
	specOpts := extractTaskOptionsFromSpec(tf, task, globalEnvFrom)

	// Resolve images with defaults
	images := resolveImages(tf.Spec.Images, terraformVersion)

	// Determine which image and execution file to use for this task type
	imageConfig := resolveTaskImage(task, images, specOpts.inlineTaskExecutionFile, specOpts.urlSource, specOpts.configMapSourceName, specOpts.configMapSourceKey)

	// Resolve service account
	serviceAccount := tf.Spec.ServiceAccount
	if serviceAccount == "" {
		// Prefix with "tf-" so IRSA roles can use wildcard "tf-*" for AWS credentials
		serviceAccount = "tf-" + versionedName
	}

	// Resolve outputs configuration
	outputsConfig := resolveOutputsConfig(tf, versionedName)

	// Check for disk cleanup setting
	cleanupDisk := false
	if tf.Spec.Setup != nil {
		cleanupDisk = tf.Spec.Setup.CleanupDisk
	}

	// Build resource labels (task.ID() == -2 indicates a plugin)
	isPlugin := task.ID() == -2
	resourceLabels := buildResourceLabels(generation, resourceName, prefixedName, terraformVersion, isPlugin)

	return TaskOptions{
		// Task identification
		task:       task,
		generation: generation,
		namespace:  tf.Namespace,

		// Resource identifiers
		resourceName:  resourceName,
		resourceUUID:  resourceUUID,
		prefixedName:  prefixedName,
		versionedName: versionedName,

		// Image configuration
		image:           imageConfig.image,
		imagePullPolicy: imageConfig.imagePullPolicy,

		// Script execution configuration
		inlineTaskExecutionFile: imageConfig.inlineTaskExecutionFile,
		urlSource:               specOpts.urlSource,
		configMapSourceName:     specOpts.configMapSourceName,
		configMapSourceKey:      specOpts.configMapSourceKey,

		// Pod configuration from spec
		env:           specOpts.env,
		envFrom:       specOpts.envFrom,
		policyRules:   specOpts.policyRules,
		annotations:   specOpts.annotations,
		labels:        specOpts.labels,
		restartPolicy: specOpts.restartPolicy,
		volumes:       specOpts.volumes,
		volumeMounts:  specOpts.volumeMounts,

		// Inherited scheduling configuration
		inheritedAffinity:     affinity,
		inheritedNodeSelector: nodeSelector,
		inheritedTolerations:  tolerations,

		// Outputs configuration
		outputsSecretName:                   outputsConfig.secretName,
		saveOutputs:                         outputsConfig.saveOutputs,
		stripGenerationLabelOnOutputsSecret: outputsConfig.stripGenerationLabelOnSecret,
		outputsToInclude:                    outputsConfig.outputsToInclude,
		outputsToOmit:                       outputsConfig.outputsToOmit,

		// Other configuration
		credentials:          tf.Spec.Credentials,
		terraformVersion:     terraformVersion,
		resourceLabels:       resourceLabels,
		serviceAccount:       serviceAccount,
		cleanupDisk:          cleanupDisk,
		requireApproval:      tf.Spec.RequireApproval,
		requireApprovalImage: requireApprovalImage,

		// Initialized empty maps/slices
		mainModulePluginData: make(map[string]string),
		secretData:           make(map[string][]byte),
		sidecarPlugins:       nil,
	}
}

const terraformFinalizer = "finalizer.tf.defn.dev"

// reconcileResult wraps reconcile.Result with an indication of whether
// the reconcile loop should return early.
type reconcileResult struct {
	result       reconcile.Result
	err          error
	shouldReturn bool
}

// continueReconcile indicates the reconcile loop should continue processing.
func continueReconcile() reconcileResult {
	return reconcileResult{shouldReturn: false}
}

// returnResult indicates the reconcile loop should return with the given result.
func returnResult(result reconcile.Result, err error) reconcileResult {
	return reconcileResult{result: result, err: err, shouldReturn: true}
}

// handleFinalizerRemoval processes the final deletion phase by removing finalizers.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleFinalizerRemoval(ctx context.Context, tf *tfv1beta1.Tofu, reqLogger logr.Logger) reconcileResult {
	if tf.Status.Phase != tfv1beta1.PhaseDeleted {
		return continueReconcile()
	}

	reqLogger.Info("Remove finalizers")
	if err := r.updateSecretFinalizer(ctx, tf); err != nil {
		r.Recorder.Event(tf, "Warning", "ProcessingError", err.Error())
		return returnResult(reconcile.Result{}, err)
	}
	_ = updateFinalizer(tf)
	if err := r.update(ctx, tf); err != nil {
		r.Recorder.Event(tf, "Warning", "ProcessingError", err.Error())
		return returnResult(reconcile.Result{}, err)
	}
	return returnResult(reconcile.Result{}, nil)
}

// handleFinalizerUpdate adds or removes finalizers as needed.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleFinalizerUpdate(ctx context.Context, tf *tfv1beta1.Tofu, reqLogger logr.Logger) reconcileResult {
	if !updateFinalizer(tf) {
		return continueReconcile()
	}

	if err := r.update(ctx, tf); err != nil {
		return returnResult(reconcile.Result{}, err)
	}
	reqLogger.V(1).Info("Updated finalizer")
	return returnResult(reconcile.Result{}, nil)
}

// handleResourceInitialization sets up the initial status fields for a new resource.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleResourceInitialization(ctx context.Context, tf *tfv1beta1.Tofu, reqLogger logr.Logger) reconcileResult {
	if tf.Status.PodNamePrefix != "" {
		return continueReconcile()
	}

	// Generate a unique name for everything related to this tf resource
	// Must truncate at 220 chars of original name to ensure room for the
	// suffixes that will be added (and possible future suffix expansion)
	tf.Status.PodNamePrefix = fmt.Sprintf("%s-%s",
		utils.TruncateResourceName(tf.Name, 54),
		utils.StringWithCharset(8, utils.AlphaNum),
	)
	tf.Status.LastCompletedGeneration = 0
	tf.Status.Phase = tfv1beta1.PhaseInitializing

	if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
		reqLogger.V(1).Info(err.Error())
	}
	return returnResult(reconcile.Result{}, nil)
}

// handleFirstStageCreation creates the initial stage for a new resource.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleFirstStageCreation(ctx context.Context, tf *tfv1beta1.Tofu, reqLogger logr.Logger) reconcileResult {
	if tf.Status.Stage.Generation != 0 {
		return continueReconcile()
	}

	task := tfv1beta1.RunSetup
	stageState := tfv1beta1.StateInitializing
	interruptible := tfv1beta1.CanNotBeInterrupt
	stage := newStage(tf, task, "TF_RESOURCE_CREATED", interruptible, stageState)
	if stage == nil {
		return returnResult(reconcile.Result{}, fmt.Errorf("failed to create a new stage"))
	}
	tf.Status.Stage = *stage
	tf.Status.PluginsStarted = []tfv1beta1.TaskName{}

	if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
		return returnResult(reconcile.Result{}, err)
	}
	return returnResult(reconcile.Result{}, nil)
}

// checkDeletionTimestamp checks if the resource is marked for deletion and updates phase if needed.
func checkDeletionTimestamp(tf *tfv1beta1.Tofu) {
	deletePhases := []string{
		string(tfv1beta1.PhaseDeleting),
		string(tfv1beta1.PhaseInitDelete),
		string(tfv1beta1.PhaseDeleted),
	}

	if tf.GetDeletionTimestamp() != nil && !utils.ListContainsStr(deletePhases, string(tf.Status.Phase)) {
		tf.Status.Phase = tfv1beta1.PhaseInitDelete
	}
}

// checkRetryLabel checks for the kubernetes.io/change-cause label to trigger a retry.
// Returns true if a retry should be triggered.
func checkRetryLabel(tf *tfv1beta1.Tofu) bool {
	if tf.Labels == nil {
		return false
	}

	label, found := tf.Labels["kubernetes.io/change-cause"]
	if !found {
		return false
	}

	retry := false
	if tf.Status.RetryEventReason == nil {
		retry = true
	} else if *tf.Status.RetryEventReason != label {
		retry = true
	}

	if retry {
		// Once a single retry is triggered via the change-cause label method,
		// the retry* status entries will persist for the lifetime of
		// the resource. This doesn't affect workflows, but it's a little annoying to see the
		// status long after the retry has occurred. In the future, see if there is a way to clean
		// up the status.
		// As of today, attempting to clean the retry* status when the change-cause label still exists
		// causes the controller to skip new generation steps like creating configmaps, secrets, etc.
		// TODO clean retry* status
		now := metav1.Now()
		tf.Status.RetryEventReason = &label
		tf.Status.RetryTimestamp = &now
		tf.Status.Phase = tfv1beta1.PhaseInitializing
	}

	return retry
}

// handleStageTransition checks for and processes stage transitions.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleStageTransition(ctx context.Context, tf *tfv1beta1.Tofu, retry bool, reqLogger logr.Logger) reconcileResult {
	stage := r.checkSetNewStage(ctx, tf, retry)
	if stage == nil {
		return continueReconcile()
	}

	if stage.Reason == "RESTARTED_WORKFLOW" || stage.Reason == "RESTARTED_DELETE_WORKFLOW" {
		_ = r.removeOldPlan(tf.Namespace, tf.Name, tf.Status.Stage.Reason, tf.Generation)
		// TODO what to do if the remove old plan function fails
	}
	reqLogger.V(2).Info(fmt.Sprintf("Stage moving from '%s' -> '%s'", tf.Status.Stage.TaskType, stage.TaskType))
	tf.Status.Stage = *stage
	desiredStatus := tf.Status
	if err := r.updateStatusWithRetry(ctx, tf, &desiredStatus, reqLogger); err != nil {
		reqLogger.V(1).Info(fmt.Sprintf("Error adding stage '%s': %s", stage.TaskType, err.Error()))
	}
	if tf.Spec.KeepLatestPodsOnly {
		go r.backgroundReapOldGenerationPods(tf, 0)
	}
	return returnResult(reconcile.Result{}, nil)
}

// handleWorkflowCompletion handles the case when the terraform workflow has completed.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleWorkflowCompletion(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions, reqLogger logr.Logger) reconcileResult {
	if runOpts.task != tfv1beta1.RunNil {
		return continueReconcile()
	}

	// podType is blank when the terraform workflow has completed for either create or delete.
	if tf.Status.Phase == tfv1beta1.PhaseRunning {
		tf.Status.Phase = tfv1beta1.PhaseCompleted
		if tf.Spec.WriteOutputsToStatus {
			if err := r.writeOutputsToStatus(ctx, tf, runOpts, reqLogger); err != nil {
				reqLogger.Error(err, "failed to write outputs to status")
			}
		}
		if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
			reqLogger.V(1).Info(err.Error())
			return returnResult(reconcile.Result{}, err)
		}
	} else if tf.Status.Phase == tfv1beta1.PhaseDeleting {
		tf.Status.Phase = tfv1beta1.PhaseDeleted
		if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
			reqLogger.V(1).Info(err.Error())
			return returnResult(reconcile.Result{}, err)
		}
	}
	return returnResult(reconcile.Result{Requeue: false}, nil)
}

// writeOutputsToStatus loads the outputs secret and writes its contents to the terraform status.
func (r *ReconcileTofu) writeOutputsToStatus(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions, reqLogger logr.Logger) error {
	secret, err := r.loadSecret(ctx, runOpts.outputsSecretName, runOpts.namespace)
	if err != nil {
		return fmt.Errorf("failed to load secret '%s': %w", runOpts.outputsSecretName, err)
	}

	// Get a list of outputs to clean up any removed outputs
	keysInOutputs := make([]string, 0, len(secret.Data))
	for key := range secret.Data {
		keysInOutputs = append(keysInOutputs, key)
	}

	// Remove keys that are no longer in the outputs
	for key := range tf.Status.Outputs {
		if !utils.ListContainsStr(keysInOutputs, key) {
			delete(tf.Status.Outputs, key)
		}
	}

	// Add/update outputs from secret
	for key, value := range secret.Data {
		if tf.Status.Outputs == nil {
			tf.Status.Outputs = make(map[string]string)
		}
		tf.Status.Outputs[key] = string(value)
	}

	return nil
}

// findPodsForStage finds pods matching the current stage.
func (r *ReconcileTofu) findPodsForStage(ctx context.Context, tf *tfv1beta1.Tofu, generation int64, podType tfv1beta1.TaskName) (*corev1.PodList, error) {
	inNamespace := client.InNamespace(tf.Namespace)
	f := fields.Set{
		"metadata.generateName": fmt.Sprintf("%s-%s-", tf.Status.PodNamePrefix+"-v"+fmt.Sprint(generation), podType),
	}
	labelSelector := map[string]string{
		"tofus.tf.defn.dev/generation": fmt.Sprintf("%d", generation),
	}
	matchingFields := client.MatchingFields(f)
	matchingLabels := client.MatchingLabels(labelSelector)

	pods := &corev1.PodList{}
	if err := r.Client.List(ctx, pods, inNamespace, matchingFields, matchingLabels); err != nil {
		return nil, err
	}

	// Filter out pods from before retry timestamp
	if tf.Status.RetryTimestamp != nil {
		filteredPods := make([]corev1.Pod, 0, len(pods.Items))
		for _, pod := range pods.Items {
			if pod.CreationTimestamp.IsZero() || !pod.CreationTimestamp.Before(tf.Status.RetryTimestamp) {
				filteredPods = append(filteredPods, pod)
			}
		}
		pods.Items = filteredPods
	}

	return pods, nil
}

// handleMissingPodInProgress handles the case where a pod was deleted while in progress.
// Returns true if reconcile should return.
func (r *ReconcileTofu) handleMissingPodInProgress(ctx context.Context, tf *tfv1beta1.Tofu, podsFound int, reqLogger logr.Logger) reconcileResult {
	if podsFound != 0 || tf.Status.Stage.State != tfv1beta1.StateInProgress {
		return continueReconcile()
	}

	// This condition is generally met when the user deletes the pod.
	// Force the state to transition away from in-progress and then requeue.
	tf.Status.Stage.State = tfv1beta1.StateInitializing
	if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
		reqLogger.V(1).Info(err.Error())
		return returnResult(reconcile.Result{Requeue: true}, nil)
	}
	return returnResult(reconcile.Result{}, nil)
}

// collectSidecarPlugins gathers sidecar plugins that should run with the current task.
func (r *ReconcileTofu) collectSidecarPlugins(ctx context.Context, tf *tfv1beta1.Tofu, podType tfv1beta1.TaskName, runOpts *TaskOptions, globalEnvFrom []corev1.EnvFromSource, reqLogger logr.Logger) (bool, error) {
	sidecarNames := []string{}

	for pluginTaskName, pluginConfig := range tf.Spec.Plugins {
		if tfv1beta1.ListContainsTask(tf.Status.PluginsStarted, pluginTaskName) {
			continue
		}

		when := pluginConfig.When
		whenTask := pluginConfig.Task
		switch when {
		case "After":
			if whenTask.ID() < podType.ID() {
				defer r.createPluginJob(ctx, reqLogger, tf, pluginTaskName, pluginConfig, globalEnvFrom)
			}
		case "At":
			if whenTask.ID() == podType.ID() {
				defer r.createPluginJob(ctx, reqLogger, tf, pluginTaskName, pluginConfig, globalEnvFrom)
			}
		case "Sidecar":
			if whenTask.ID() == podType.ID() {
				pluginSidecarPod, err := r.getPluginSidecarPod(ctx, reqLogger, tf, pluginTaskName, pluginConfig, globalEnvFrom)
				if err != nil {
					if pluginConfig.Must {
						return true, err
					}
					reqLogger.V(1).Info("Error adding sidecar plugin: %s", err.Error())
					continue
				}

				exists := false
				for _, c := range pluginSidecarPod.Spec.Containers {
					if utils.ListContainsStr(sidecarNames, c.Name) {
						exists = true
					}
				}
				if !exists {
					sidecarNames = append(sidecarNames, getContainerNames(pluginSidecarPod)...)
					runOpts.sidecarPlugins = append(runOpts.sidecarPlugins, *pluginSidecarPod)
				}
			}
		}
	}

	// Add require-approval plugin for plan tasks if needed
	if (podType == tfv1beta1.RunPlan || podType == tfv1beta1.RunPlanDelete) && runOpts.requireApproval {
		requireApprovalPlugin := tfv1beta1.Plugin{
			ImageConfig: tfv1beta1.ImageConfig{
				Image:           runOpts.requireApprovalImage,
				ImagePullPolicy: corev1.PullIfNotPresent,
			},
			Must: true,
		}
		pluginSidecarPod, err := r.getPluginSidecarPod(ctx, reqLogger, tf, tfv1beta1.TaskName("require-approval"), requireApprovalPlugin, globalEnvFrom)
		if err != nil {
			return true, err
		}

		exists := false
		for _, c := range pluginSidecarPod.Spec.Containers {
			if utils.ListContainsStr(sidecarNames, c.Name) {
				exists = true
			}
		}
		if !exists {
			runOpts.sidecarPlugins = append(runOpts.sidecarPlugins, *pluginSidecarPod)
		}
	}

	return false, nil
}

// createAndStartPod creates a new pod for the current stage.
// Returns true if reconcile should return.
func (r *ReconcileTofu) createAndStartPod(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions, globalEnvFrom []corev1.EnvFromSource, reqLogger logr.Logger) reconcileResult {
	// Collect sidecar plugins
	shouldRequeue, err := r.collectSidecarPlugins(ctx, tf, runOpts.task, &runOpts, globalEnvFrom, reqLogger)
	if err != nil {
		reqLogger.V(1).Info(err.Error())
		if shouldRequeue {
			return returnResult(reconcile.Result{Requeue: true}, nil)
		}
	}

	reqLogger.V(1).Info(fmt.Sprintf("Setting up the '%s' pod", runOpts.task))
	if err := r.setupAndRun(ctx, tf, runOpts); err != nil {
		reqLogger.Error(err, err.Error())
		return returnResult(reconcile.Result{}, err)
	}

	// Update phase based on current state
	if tf.Status.Phase == tfv1beta1.PhaseInitializing {
		tf.Status.Phase = tfv1beta1.PhaseRunning
	} else if tf.Status.Phase == tfv1beta1.PhaseInitDelete {
		tf.Status.Phase = tfv1beta1.PhaseDeleting
	}
	tf.Status.Stage.State = tfv1beta1.StateInProgress

	if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
		reqLogger.V(1).Info(err.Error())
		return returnResult(reconcile.Result{Requeue: true}, nil)
	}
	// When the pod is created, don't requeue. The pod's status changes will trigger tfo to reconcile.
	return returnResult(reconcile.Result{}, nil)
}

// updateStageFromPodStatus updates the stage status based on the current pod status.
func (r *ReconcileTofu) updateStageFromPodStatus(ctx context.Context, tf *tfv1beta1.Tofu, pod *corev1.Pod, reqLogger logr.Logger) reconcileResult {
	podName := pod.ObjectMeta.Name
	podPhase := pod.Status.Phase
	msg := fmt.Sprintf("Pod '%s' %s", podName, podPhase)

	tf.Status.Stage.PodUID = string(pod.UID)
	tf.Status.Stage.PodName = podName
	if tf.Status.Stage.Message != msg {
		tf.Status.Stage.Message = msg
		reqLogger.Info(msg)
	}

	switch pod.Status.Phase {
	case corev1.PodFailed:
		tf.Status.Stage.State = tfv1beta1.StateFailed
		tf.Status.Stage.StopTime = metav1.NewTime(time.Now())
		if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
			reqLogger.V(1).Info(err.Error())
			return returnResult(reconcile.Result{}, err)
		}
		return returnResult(reconcile.Result{}, nil)

	case corev1.PodSucceeded:
		tf.Status.Stage.State = tfv1beta1.StateComplete
		tf.Status.Stage.StopTime = metav1.NewTime(time.Now())
		if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
			reqLogger.V(1).Info(err.Error())
			return returnResult(reconcile.Result{}, err)
		}
		if !tf.Spec.KeepCompletedPods && !tf.Spec.KeepLatestPodsOnly {
			if err := r.Client.Delete(ctx, pod); err != nil {
				reqLogger.V(1).Info(err.Error())
			}
		}
		return returnResult(reconcile.Result{}, nil)

	default:
		tf.Status.Stage.State = tfv1beta1.StageState(pod.Status.Phase)
		// Update any statuses that have been changed. This is probably for pending condition.
		if err := r.updateStatusWithRetry(ctx, tf, &tf.Status, reqLogger); err != nil {
			reqLogger.V(1).Info(err.Error())
			return returnResult(reconcile.Result{}, err)
		}
		return returnResult(reconcile.Result{}, nil)
	}
}

// Reconcile reads that state of the cluster for a Tofu object and makes changes based on the state read
// and what is in the Tofu.Spec
// Note:
// The Controller will requeue the Request to be processed again if the returned error is non-nil or
// Result.Requeue is true, otherwise upon completion it will remove the work from the queue.
func (r *ReconcileTofu) Reconcile(ctx context.Context, request reconcile.Request) (reconcile.Result, error) {
	reconcilerID := string(uuid.NewUUID())
	reqLogger := r.Log.WithValues("Tofu", request.NamespacedName, "id", reconcilerID)

	// Cache node selectors for inheritance
	if err := r.cacheNodeSelectors(ctx, reqLogger); err != nil {
		panic(err)
	}

	// Acquire reconcile lock
	lockKey := request.String() + "-reconcile-lock"
	if lockOwner, lockFound := r.Cache.Get(lockKey); lockFound {
		reqLogger.Info(fmt.Sprintf("Request is locked by '%s'", lockOwner.(string)))
		return reconcile.Result{RequeueAfter: 30 * time.Second}, nil
	}
	r.Cache.Set(lockKey, reconcilerID, -1)
	defer r.Cache.Delete(lockKey)
	defer reqLogger.V(6).Info("Request has released reconcile lock")
	reqLogger.V(6).Info("Request has acquired reconcile lock")

	// Fetch the Tofu resource
	tf, err := r.getTerraformResource(ctx, request.NamespacedName, 3, reqLogger)
	if err != nil {
		if errors.IsNotFound(err) {
			reqLogger.V(1).Info("Tofu resource not found. Ignoring since object must be deleted")
			return reconcile.Result{}, nil
		}
		reqLogger.Error(err, "Failed to get Tofu")
		return reconcile.Result{}, err
	}

	// Step 1: Handle final deletion (remove finalizers)
	if result := r.handleFinalizerRemoval(ctx, tf, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 2: Handle finalizer updates
	if result := r.handleFinalizerUpdate(ctx, tf, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 3: Initialize resource if needed
	if result := r.handleResourceInitialization(ctx, tf, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 4: Create first stage if needed
	if result := r.handleFirstStageCreation(ctx, tf, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 5: Deletion-phase transition is disabled. The defn fork removes
	// destroy from this controller entirely; with no finalizer attached, k8s
	// removes the object directly and the controller never enters the
	// destroy workflow.

	// Step 6: Check for retry label
	retry := checkRetryLabel(tf)

	// Step 7: Handle stage transitions
	if result := r.handleStageTransition(ctx, tf, retry, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Prepare task options for current stage
	globalEnvFrom := r.listEnvFromSources(tf)
	currentStage := tf.Status.Stage
	affinity, nodeSelector, tolerations := r.getNodeSelectorsFromCache()
	runOpts := newTaskOptions(tf, currentStage.TaskType, currentStage.Generation, globalEnvFrom, affinity, nodeSelector, tolerations, r.RequireApprovalImage)

	// Step 8: Handle workflow completion
	if result := r.handleWorkflowCompletion(ctx, tf, runOpts, reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 9: Find pods for current stage
	pods, err := r.findPodsForStage(ctx, tf, currentStage.Generation, currentStage.TaskType)
	if err != nil {
		reqLogger.Error(err, "")
		return reconcile.Result{}, nil
	}

	// Step 10: Handle missing pod while in progress
	if result := r.handleMissingPodInProgress(ctx, tf, len(pods.Items), reqLogger); result.shouldReturn {
		return result.result, result.err
	}

	// Step 11: Create pod if none exists
	if len(pods.Items) == 0 {
		result := r.createAndStartPod(ctx, tf, runOpts, globalEnvFrom, reqLogger)
		return result.result, result.err
	}

	// Step 12: Update stage based on existing pod status
	result := r.updateStageFromPodStatus(ctx, tf, &pods.Items[0], reqLogger)
	return result.result, result.err
}

// getTerraformResource fetches the terraform resource with a retry
func (r ReconcileTofu) getTerraformResource(ctx context.Context, namespacedName types.NamespacedName, maxRetry int, reqLogger logr.Logger) (*tfv1beta1.Tofu, error) {
	tf := &tfv1beta1.Tofu{}
	for retryCount := 1; retryCount <= maxRetry; retryCount++ {
		err := r.Client.Get(ctx, namespacedName, tf)
		if err != nil {
			if errors.IsNotFound(err) {
				return tf, err
			} else if retryCount < maxRetry {
				time.Sleep(100 * time.Millisecond)
				continue
			}
			return tf, err
		} else {
			break
		}
	}
	return tf, nil
}

func newStage(tf *tfv1beta1.Tofu, taskType tfv1beta1.TaskName, reason string, interruptible tfv1beta1.Interruptible, stageState tfv1beta1.StageState) *tfv1beta1.Stage {
	if reason == "GENERATION_CHANGE" {
		tf.Status.PluginsStarted = []tfv1beta1.TaskName{}
		tf.Status.Phase = tfv1beta1.PhaseInitializing
	}
	startTime := metav1.NewTime(time.Now())
	stopTime := metav1.NewTime(time.Unix(0, 0))
	if stageState == tfv1beta1.StateComplete {
		stopTime = startTime
	}
	return &tfv1beta1.Stage{
		Generation:    tf.Generation,
		Interruptible: interruptible,
		Reason:        reason,
		State:         stageState,
		TaskType:      taskType,
		StartTime:     startTime,
		StopTime:      stopTime,
	}
}

func getConfiguredTasks(taskOptions *[]tfv1beta1.TaskOption) []tfv1beta1.TaskName {
	tasks := []tfv1beta1.TaskName{
		tfv1beta1.RunSetup,
		tfv1beta1.RunInit,
		tfv1beta1.RunPlan,
		tfv1beta1.RunApply,
		tfv1beta1.RunSetupDelete,
		tfv1beta1.RunInitDelete,
		tfv1beta1.RunPlanDelete,
		tfv1beta1.RunApplyDelete,
	}
	if taskOptions == nil {
		return tasks
	}
	for _, taskOption := range *taskOptions {
		for _, affected := range taskOption.For {
			if affected == "*" {
				continue
			}
			if !tfv1beta1.ListContainsTask(tasks, affected) {
				tasks = append(tasks, affected)
			}
		}
	}
	return tasks
}

// checkSetNewStage uses the tf resource's `.status.stage` state to find the next stage of the terraform run.
//
// The conditions are evaluated in priority order (first match wins):
//
//  1. Retry (non-delete workflow): Triggered when isRetry=true and resource is not being deleted.
//     Restarts from RunInit (or RunSetup if reason ends with ".setup").
//     Note: This won't trigger if isNewGeneration=true; new generation takes precedence.
//
//  2. Retry (delete workflow): Same as above but for resources being deleted.
//     Restarts from RunInitDelete (or RunSetupDelete if reason ends with ".setup").
//
//  3. Uninterruptible stage running: Blocks ALL stage transitions when the current stage
//     cannot be interrupted (e.g., init, plan, apply) and is currently in progress.
//     This applies even if there's a new generation - we must wait for completion.
//
//  4. New generation (non-delete): When the resource spec changes (generation increments),
//     restart the entire workflow from RunSetup.
//
//  5. New generation with InitDelete: Resource was just marked for deletion (phase=InitDelete).
//     Start the destroy workflow from RunSetupDelete. Marked as non-interruptible.
//
//  6. New generation while deleting: Resource is already in delete workflow but got updated.
//     Restart the destroy workflow from RunSetupDelete. This differs from #5 in that
//     it's interruptible (the delete is already in progress).
//
//  7. Stage completed: Normal progression - advance to the next task in the workflow.
//     If current task is RunNil, the workflow is complete and no new stage is created.
//     After the final task (e.g., RunApply), nextTask returns RunNil with StateComplete.
//
//  8. Stage failed (apply only): Only RunApply and RunApplyDelete failures can trigger
//     a restart, and only if the pod has been deleted. This prevents infinite restart
//     loops when apply keeps failing. The workflow restarts from RunPrePlan (skipping
//     setup/init which already succeeded).
//     Note: Failed non-apply stages return nil - they require manual intervention or retry.
//
// If none of the above conditions match, returns nil (no stage transition).
func (r ReconcileTofu) checkSetNewStage(ctx context.Context, tf *tfv1beta1.Tofu, isRetry bool) *tfv1beta1.Stage {
	var isNewStage bool
	var podType tfv1beta1.TaskName
	var reason string
	configuredTasks := getConfiguredTasks(&tf.Spec.TaskOptions)

	deletePhases := []string{
		string(tfv1beta1.PhaseDeleted),
		string(tfv1beta1.PhaseInitDelete),
		string(tfv1beta1.PhaseDeleting),
	}
	isToBeDeletedOrIsDeleting := utils.ListContainsStr(deletePhases, string(tf.Status.Phase))
	initDelete := tf.Status.Phase == tfv1beta1.PhaseInitDelete
	stageState := tfv1beta1.StateInitializing
	interruptible := tfv1beta1.CanBeInterrupt

	currentStage := tf.Status.Stage
	currentStagePodType := currentStage.TaskType
	currentStageCanNotBeInterrupted := currentStage.Interruptible == tfv1beta1.CanNotBeInterrupt
	currentStageIsRunning := currentStage.State == tfv1beta1.StateInProgress
	isNewGeneration := currentStage.Generation != tf.Generation

	// Case 1: Retry triggered for non-delete workflow (same generation only)
	// The !isNewGeneration check ensures new generation takes precedence over retry
	if isRetry && !isToBeDeletedOrIsDeleting && !isNewGeneration {
		isNewStage = true
		reason = *tf.Status.RetryEventReason // Safe: checkRetryLabel sets this before returning true
		podType = tfv1beta1.RunInit
		if strings.HasSuffix(reason, ".setup") {
			podType = tfv1beta1.RunSetup
		}
		interruptible = isTaskInterruptable(podType)

		// Case 2: Retry triggered for delete workflow (same generation only)
	} else if isRetry && isToBeDeletedOrIsDeleting && !isNewGeneration {
		isNewStage = true
		reason = *tf.Status.RetryEventReason
		podType = tfv1beta1.RunInitDelete
		if strings.HasSuffix(reason, ".setup") {
			podType = tfv1beta1.RunSetupDelete
		}
		interruptible = isTaskInterruptable(podType)

		// Case 3: Block transitions when uninterruptible stage is running
		// This takes precedence over new generation checks to protect terraform state
	} else if currentStageCanNotBeInterrupted && currentStageIsRunning {
		isNewStage = false

		// Case 4: New generation triggers fresh workflow (non-delete)
	} else if isNewGeneration && !isToBeDeletedOrIsDeleting {
		isNewStage = true
		reason = "GENERATION_CHANGE"
		podType = tfv1beta1.RunSetup

		// Case 5: New generation with InitDelete - start destroy workflow
		// initDelete is specifically PhaseInitDelete (just marked for deletion)
		// This is non-interruptible to ensure deletion starts cleanly
	} else if isNewGeneration && initDelete {
		isNewStage = true
		reason = "TF_RESOURCE_DELETED"
		podType = tfv1beta1.RunSetupDelete
		interruptible = tfv1beta1.CanNotBeInterrupt

		// Case 6: New generation while already deleting (PhaseDeleting or PhaseDeleted)
		// Resource was updated during deletion; restart destroy workflow but allow interruption
	} else if isNewGeneration && isToBeDeletedOrIsDeleting {
		isNewStage = true
		reason = "TF_RESOURCE_DELETED"
		podType = tfv1beta1.RunSetupDelete

		// Case 7: Normal progression when current stage completes
	} else if currentStage.State == tfv1beta1.StateComplete {
		isNewStage = true
		reason = fmt.Sprintf("COMPLETED_%s", strings.ToUpper(currentStage.TaskType.String()))

		switch currentStagePodType {
		case tfv1beta1.RunNil:
			// Workflow already complete, no new stage needed
			isNewStage = false
		default:
			podType = nextTask(currentStagePodType, configuredTasks)
			interruptible = isTaskInterruptable(podType)
			if podType == tfv1beta1.RunNil {
				// This is the final stage transition (workflow complete)
				stageState = tfv1beta1.StateComplete
			}
		}

		// Case 8: Failed apply/apply-delete can restart if pod was deleted
		// Only these tasks support auto-restart to prevent infinite loops on persistent failures.
		// The pod must be deleted (manually or by TTL) before restart triggers.
	} else if currentStage.State == tfv1beta1.StateFailed {
		if currentStage.TaskType == tfv1beta1.RunApply {
			err := r.Client.Get(ctx, types.NamespacedName{Namespace: tf.Namespace, Name: tf.Status.Stage.PodName}, &corev1.Pod{})
			if err != nil && errors.IsNotFound(err) {
				// Pod deleted after failure - restart from plan stage (skip setup/init)
				isNewStage = true
				reason = "RESTARTED_WORKFLOW"
				podType = nextTask(tfv1beta1.RunPostInit, configuredTasks)
				interruptible = isTaskInterruptable(podType)
			}
			// If pod still exists, no transition - wait for manual intervention
		} else if currentStage.TaskType == tfv1beta1.RunApplyDelete {
			pod := corev1.Pod{}
			err := r.Client.Get(ctx, types.NamespacedName{Namespace: tf.Namespace, Name: tf.Status.Stage.PodName}, &pod)
			if err != nil && errors.IsNotFound(err) {
				// Pod deleted after failure - restart delete workflow from plan-delete
				isNewStage = true
				reason = "RESTARTED_DELETE_WORKFLOW"
				podType = nextTask(tfv1beta1.RunPostInitDelete, configuredTasks)
				interruptible = isTaskInterruptable(podType)
			}
		}
		// Note: Failed stages other than apply/apply-delete do not auto-restart.
		// They require manual retry via the change-cause label or a new generation.
	}

	if !isNewStage {
		return nil
	}
	return newStage(tf, podType, reason, interruptible, stageState)
}

func (r ReconcileTofu) removeOldPlan(namespace, name, reason string, generation int64) error {

	labelSelectors := []string{
		fmt.Sprintf("tofus.tf.defn.dev/generation==%d", generation),
		fmt.Sprintf("tofus.tf.defn.dev/resourceName=%s", utils.AutoHashLabeler(name)),
		"app.kubernetes.io/instance",
	}
	if reason == "RESTARTED_WORKFLOW" {
		labelSelectors = append(labelSelectors, []string{
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunSetup),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunPreInit),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunInit),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunPostInit),
		}...)
	} else if reason == "RESTARTED_DELETE_WORKFLOW" {
		labelSelectors = append(labelSelectors, []string{
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunSetupDelete),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunPreInitDelete),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunInitDelete),
			fmt.Sprintf("app.kubernetes.io/instance!=%s", tfv1beta1.RunPostInitDelete),
		}...)
	}
	labelSelector, err := labels.Parse(strings.Join(labelSelectors, ","))
	if err != nil {
		return err
	}
	fieldSelector, err := fields.ParseSelector("status.phase!=Running")
	if err != nil {
		return err
	}
	err = r.Client.DeleteAllOf(context.TODO(), &corev1.Pod{}, &client.DeleteAllOfOptions{
		ListOptions: client.ListOptions{
			LabelSelector: labelSelector,
			Namespace:     namespace,
			FieldSelector: fieldSelector,
		},
	})
	if err != nil {
		return err
	}
	return nil
}

// These are pods that are known to cause issues with terraform state when
// not run to completion.
func isTaskInterruptable(task tfv1beta1.TaskName) tfv1beta1.Interruptible {
	uninterruptibleTasks := []tfv1beta1.TaskName{
		tfv1beta1.RunInit,
		tfv1beta1.RunPlan,
		tfv1beta1.RunApply,
		tfv1beta1.RunInitDelete,
		tfv1beta1.RunPlanDelete,
		tfv1beta1.RunApplyDelete,
	}
	if tfv1beta1.ListContainsTask(uninterruptibleTasks, task) {
		return tfv1beta1.CanNotBeInterrupt
	}
	return tfv1beta1.CanBeInterrupt
}

func nextTask(currentTask tfv1beta1.TaskName, configuredTasks []tfv1beta1.TaskName) tfv1beta1.TaskName {
	tasksInOrder := []tfv1beta1.TaskName{
		tfv1beta1.RunSetup,
		tfv1beta1.RunPreInit,
		tfv1beta1.RunInit,
		tfv1beta1.RunPostInit,
		tfv1beta1.RunPrePlan,
		tfv1beta1.RunPlan,
		tfv1beta1.RunPostPlan,
		tfv1beta1.RunPreApply,
		tfv1beta1.RunApply,
		tfv1beta1.RunPostApply,
	}
	deleteTasksInOrder := []tfv1beta1.TaskName{
		tfv1beta1.RunSetupDelete,
		tfv1beta1.RunPreInitDelete,
		tfv1beta1.RunInitDelete,
		tfv1beta1.RunPostInitDelete,
		tfv1beta1.RunPrePlanDelete,
		tfv1beta1.RunPlanDelete,
		tfv1beta1.RunPostPlanDelete,
		tfv1beta1.RunPreApplyDelete,
		tfv1beta1.RunApplyDelete,
		tfv1beta1.RunPostApplyDelete,
	}

	next := tfv1beta1.RunNil
	isUpNext := false
	if tfv1beta1.ListContainsTask(tasksInOrder, currentTask) {
		for _, task := range tasksInOrder {
			if task == currentTask {
				isUpNext = true
				continue
			}
			if isUpNext && tfv1beta1.ListContainsTask(configuredTasks, task) {
				next = task
				break
			}
		}
	} else if tfv1beta1.ListContainsTask(deleteTasksInOrder, currentTask) {
		for _, task := range deleteTasksInOrder {
			if task == currentTask {
				isUpNext = true
				continue
			}
			if isUpNext && tfv1beta1.ListContainsTask(configuredTasks, task) {
				next = task
				break
			}
		}
	}
	return next
}

func (r ReconcileTofu) backgroundReapOldGenerationPods(tf *tfv1beta1.Tofu, attempt int) {
	logger := r.Log.WithName("Reaper").WithValues("Tofu", fmt.Sprintf("%s/%s", tf.Namespace, tf.Name))
	if attempt > 20 {
		// TODO explain what and way resources cannot be reaped
		logger.Info("Could not reap resources: Max attempts to reap old-generation resources")
		return
	}

	// Before running a deletion, make sure we've got the most up-to-date resource in case a background
	// process takes longer than normal to complete.
	ctx := context.TODO()
	namespacedName := types.NamespacedName{Namespace: tf.Namespace, Name: tf.Name}
	tf, err := r.getTerraformResource(ctx, namespacedName, 3, logger)
	if err != nil {
		if errors.IsNotFound(err) {
			logger.V(1).Info("Tofu resource not found. Ignoring since object must be deleted")
			return
		}
		// Error reading the object - requeue the request.
		logger.Error(err, "Failed to get Tofu")
		return
	}

	// The labels required are read as:
	// 1. The tofus.tf.defn.dev/generation key MUST exist
	// 2. The tofus.tf.defn.dev/generation value MUST match the current resource generation
	// 3. The tofus.tf.defn.dev/resourceName key MUST exist
	// 4. The tofus.tf.defn.dev/resourceName value MUST match the resource name
	labelSelector, err := labels.Parse(fmt.Sprintf("tofus.tf.defn.dev/generation,tofus.tf.defn.dev/generation!=%d,tofus.tf.defn.dev/resourceName,tofus.tf.defn.dev/resourceName=%s", tf.Generation, utils.AutoHashLabeler(tf.Name)))
	if err != nil {
		logger.Error(err, "Could not parse labels")
		return
	}
	fieldSelector, err := fields.ParseSelector("status.phase!=Running")
	if err != nil {
		logger.Error(err, "Could not parse fields")
		return
	}

	err = r.Client.DeleteAllOf(context.TODO(), &corev1.Pod{}, &client.DeleteAllOfOptions{
		ListOptions: client.ListOptions{
			LabelSelector: labelSelector,
			Namespace:     tf.Namespace,
			FieldSelector: fieldSelector,
		},
	})
	if err != nil {
		logger.Error(err, "Could not reap old generation pods")
		return
	}

	// Wait for all the pods of the previous generations to be gone. Only after
	// the pods are cleaned up, clean up other associated resources like roles
	// and rolebindings.
	podList := corev1.PodList{}
	err = r.Client.List(context.TODO(), &podList, &client.ListOptions{
		LabelSelector: labelSelector,
		Namespace:     tf.Namespace,
	})
	if err != nil {
		logger.Error(err, "Could not list pods to reap")
		return
	}
	if len(podList.Items) > 0 {
		// There are still some pods from a previous generation hanging around
		// for some reason. Wait some time and try to reap again later.
		time.Sleep(30 * time.Second)
		attempt++
		go r.backgroundReapOldGenerationPods(tf, attempt)
	} else {
		// All old pods are gone and the other resouces will now be removed
		err = r.Client.DeleteAllOf(context.TODO(), &corev1.ConfigMap{}, &client.DeleteAllOfOptions{
			ListOptions: client.ListOptions{
				LabelSelector: labelSelector,
				Namespace:     tf.Namespace,
			},
		})
		if err != nil {
			logger.Error(err, "Could not reap old generation configmaps")
			return
		}

		err = r.Client.DeleteAllOf(context.TODO(), &corev1.Secret{}, &client.DeleteAllOfOptions{
			ListOptions: client.ListOptions{
				LabelSelector: labelSelector,
				Namespace:     tf.Namespace,
			},
		})
		if err != nil {
			logger.Error(err, "Could not reap old generation secrets")
			return
		}

		err = r.Client.DeleteAllOf(context.TODO(), &rbacv1.Role{}, &client.DeleteAllOfOptions{
			ListOptions: client.ListOptions{
				LabelSelector: labelSelector,
				Namespace:     tf.Namespace,
			},
		})
		if err != nil {
			logger.Error(err, "Could not reap old generation roles")
			return
		}

		err = r.Client.DeleteAllOf(context.TODO(), &rbacv1.RoleBinding{}, &client.DeleteAllOfOptions{
			ListOptions: client.ListOptions{
				LabelSelector: labelSelector,
				Namespace:     tf.Namespace,
			},
		})
		if err != nil {
			logger.Error(err, "Could not reap old generation roleBindings")
			return
		}

		err = r.Client.DeleteAllOf(context.TODO(), &corev1.ServiceAccount{}, &client.DeleteAllOfOptions{
			ListOptions: client.ListOptions{
				LabelSelector: labelSelector,
				Namespace:     tf.Namespace,
			},
		})
		if err != nil {
			logger.Error(err, "Could not reap old generation serviceAccounts")
			return
		}
	}
}

func (r ReconcileTofu) reapPlugins(tf *tfv1beta1.Tofu, attempt int) {
	logger := r.Log.WithName("ReaperPlugins").WithValues("Tofu", fmt.Sprintf("%s/%s", tf.Namespace, tf.Name))
	if attempt > 20 {
		// TODO explain what and way resources cannot be reaped
		logger.Info("Could not reap resources: Max attempts to reap old-generation resources")
		return
	}
	// Before running a deletion, make sure we've got the most up-to-date resource in case a background
	// process takes longer than normal to complete.
	ctx := context.TODO()
	namespacedName := types.NamespacedName{Namespace: tf.Namespace, Name: tf.Name}
	tf, err := r.getTerraformResource(ctx, namespacedName, 3, logger)
	if err != nil {
		if errors.IsNotFound(err) {
			logger.V(1).Info("Tofu resource not found. Ignoring since object must be deleted")
			return
		}
		// Error reading the object - requeue the request.
		logger.Error(err, "Failed to get Tofu")
		return
	}

	// Delete old plugins regardless of pod phase
	labelSelectorForPlugins, err := labels.Parse(fmt.Sprintf("tofus.tf.defn.dev/isPlugin=true,tofus.tf.defn.dev/generation,tofus.tf.defn.dev/generation!=%d,tofus.tf.defn.dev/resourceName,tofus.tf.defn.dev/resourceName=%s", tf.Generation, utils.AutoHashLabeler(tf.Name)))
	if err != nil {
		logger.Error(err, "Could not parse labels")
	}

	deleteProppagationBackground := metav1.DeletePropagationBackground
	err = r.Client.DeleteAllOf(context.TODO(), &batchv1.Job{}, &client.DeleteAllOfOptions{
		ListOptions: client.ListOptions{
			LabelSelector: labelSelectorForPlugins,
			Namespace:     tf.Namespace,
		},
		DeleteOptions: client.DeleteOptions{
			PropagationPolicy: &deleteProppagationBackground,
		},
	})
	if err != nil {
		logger.Error(err, "Could not reap old generation jobs")
	}

	err = r.Client.DeleteAllOf(context.TODO(), &corev1.Pod{}, &client.DeleteAllOfOptions{
		ListOptions: client.ListOptions{
			LabelSelector: labelSelectorForPlugins,
			Namespace:     tf.Namespace,
		},
	})
	if err != nil {
		logger.Error(err, "Could not reap old generation pods")
	}

	// Wait for all the pods of the previous generations to be gone. Only after
	// the pods are cleaned up, clean up other associated resources like roles
	// and rolebindings.
	podList := corev1.PodList{}
	err = r.Client.List(context.TODO(), &podList, &client.ListOptions{
		LabelSelector: labelSelectorForPlugins,
		Namespace:     tf.Namespace,
	})
	if err != nil {
		logger.Error(err, "Could not list pods to reap")
	}
	if len(podList.Items) > 0 {
		// There are still some pods from a previous generation hanging around
		// for some reason. Wait some time and try to reap again later.
		time.Sleep(30 * time.Second)
		attempt++
		go r.reapPlugins(tf, attempt)
	}
}

func (r ReconcileTofu) getNodeSelectorsFromCache() (*corev1.Affinity, map[string]string, []corev1.Toleration) {
	var affinity *corev1.Affinity
	var nodeSelector map[string]string
	var tolerations []corev1.Toleration
	if r.InheritAffinity {
		if obj, found := r.Cache.Get(r.AffinityCacheKey); found {
			affinity = obj.(*corev1.Affinity)
		}
	}
	if r.InheritNodeSelector {
		if obj, found := r.Cache.Get(r.NodeSelectorCacheKey); found {
			nodeSelector = obj.(map[string]string)
		}
	}
	if r.InheritTolerations {
		if obj, found := r.Cache.Get(r.TolerationsCacheKey); found {
			tolerations = obj.([]corev1.Toleration)
		}
	}

	return affinity, nodeSelector, tolerations
}

// Define a set of TaskOptions specific for the plugin task
func (r ReconcileTofu) getPluginRunOpts(tf *tfv1beta1.Tofu, pluginTaskName tfv1beta1.TaskName, pluginConfig tfv1beta1.Plugin, globalEnvFrom []corev1.EnvFromSource) TaskOptions {
	affinity, nodeSelector, tolerations := r.getNodeSelectorsFromCache()
	pluginRunOpts := newTaskOptions(tf, pluginTaskName, tf.Generation, globalEnvFrom, affinity, nodeSelector, tolerations, r.RequireApprovalImage)
	pluginRunOpts.image = pluginConfig.Image
	pluginRunOpts.imagePullPolicy = pluginConfig.ImagePullPolicy
	return pluginRunOpts
}

func (r ReconcileTofu) getPluginSidecarPod(ctx context.Context, logger logr.Logger, tf *tfv1beta1.Tofu, pluginTaskName tfv1beta1.TaskName, pluginConfig tfv1beta1.Plugin, globalEnvFrom []corev1.EnvFromSource) (*corev1.Pod, error) {
	return r.getPluginRunOpts(tf, pluginTaskName, pluginConfig, globalEnvFrom).generatePod()
}

// createPluginJob will attempt to create the plugin pod and mark it as added in the resource's status.
// No logic is used to determine if the plugin was successful. If the createPod function errors, a log event
// is recorded in the controller.
func (r ReconcileTofu) createPluginJob(ctx context.Context, logger logr.Logger, tf *tfv1beta1.Tofu, pluginTaskName tfv1beta1.TaskName, pluginConfig tfv1beta1.Plugin, globalEnvFrom []corev1.EnvFromSource) (reconcile.Result, error) {
	pluginRunOpts := r.getPluginRunOpts(tf, pluginTaskName, pluginConfig, globalEnvFrom)

	go func() {
		err := r.createJob(ctx, tf, pluginRunOpts)
		if err != nil {
			logger.Error(err, fmt.Sprintf("Failed creating plugin job %s", pluginTaskName))
		} else {
			logger.Info(fmt.Sprintf("Starting the plugin job '%s'", pluginTaskName.String()))
		}
	}()
	tf.Status.PluginsStarted = append(tf.Status.PluginsStarted, pluginTaskName)
	err := r.updateStatusWithRetry(ctx, tf, &tf.Status, logger)
	if err != nil {
		logger.V(1).Info(err.Error())
	}
	return reconcile.Result{}, err
}

// updateFinalizer guarantees the deletion finalizer is never present on a
// Tofu resource. The finalizer would otherwise drive the destroy workflow;
// the defn fork removes destroy from this controller entirely, so we strip
// the finalizer if it exists and never add it. Destruction of underlying
// infrastructure must be handled out of band.
func updateFinalizer(tf *tfv1beta1.Tofu) bool {
	finalizers := tf.GetFinalizers()
	if utils.ListContainsStr(finalizers, terraformFinalizer) {
		tf.SetFinalizers(utils.ListRemoveStr(finalizers, terraformFinalizer))
		return true
	}
	return false
}

// Here we determine if secret in SCMAuthMethods array should be locked via finalizer or not

type gitSecret struct {
	name          string
	namespace     string
	shoudBeLocked bool
}

func (r ReconcileTofu) getGitSecrets(tf *tfv1beta1.Tofu) []gitSecret {
	secrets := []gitSecret{}
	for _, m := range tf.Spec.SCMAuthMethods {
		if m.Git.HTTPS != nil {
			ref := m.Git.HTTPS.TokenSecretRef
			namespace := ref.Namespace
			if ref.Namespace == "" {
				namespace = tf.Namespace
			}
			secrets = append(secrets, gitSecret{
				name:          ref.Name,
				namespace:     namespace,
				shoudBeLocked: ref.LockSecretDeletion && !tf.Spec.IgnoreDelete,
			})
		}
		if m.Git.SSH != nil {
			ref := m.Git.SSH.SSHKeySecretRef
			namespace := ref.Namespace
			if ref.Namespace == "" {
				namespace = tf.Namespace
			}
			secrets = append(secrets, gitSecret{
				name:          ref.Name,
				namespace:     namespace,
				shoudBeLocked: ref.LockSecretDeletion && !tf.Spec.IgnoreDelete,
			})
		}
	}
	return secrets
}

// updateSecretFinalizer sets and unsets finalizers on all secrets mentioned in spec.scmAuthMethods
// to ensure terraform workflow will work properly.
func (r ReconcileTofu) updateSecretFinalizer(ctx context.Context, tf *tfv1beta1.Tofu) error {
	finalizerKey := utils.TruncateResourceName(fmt.Sprintf("finalizer.tf.defn.dev/%s", tf.Name), 53)

	secrets := r.getGitSecrets(tf)
	for _, m := range secrets {
		if m.shoudBeLocked && tf.Status.Phase != tfv1beta1.PhaseDeleted {
			if err := r.lockGitSecretDeletion(ctx, m.name, m.namespace, finalizerKey); err != nil {
				return err
			}
		} else {
			if err := r.unlockGitSecretDeletion(ctx, m.name, m.namespace, finalizerKey); err != nil {
				return err
			}
		}
	}
	return nil
}

func (r ReconcileTofu) lockGitSecretDeletion(ctx context.Context, name, namespace, finalizerKey string) error {
	secret, err := r.loadSecret(ctx, name, namespace)
	if err != nil {
		return err
	}
	if !controllerutil.ContainsFinalizer(secret, finalizerKey) {
		controllerutil.AddFinalizer(secret, finalizerKey)
		if err := r.Client.Update(ctx, secret); err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) unlockGitSecretDeletion(ctx context.Context, name, namespace, finalizerKey string) error {
	secret, err := r.loadSecret(ctx, name, namespace)
	if err != nil {
		return err
	}
	if controllerutil.ContainsFinalizer(secret, finalizerKey) {
		controllerutil.RemoveFinalizer(secret, finalizerKey)
		if err := r.Client.Update(ctx, secret); err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) update(ctx context.Context, tf *tfv1beta1.Tofu) error {
	err := r.Client.Update(ctx, tf)
	if err != nil {
		return fmt.Errorf("failed to update tf resource: %s", err)
	}
	return nil
}

func (r ReconcileTofu) updateStatus(ctx context.Context, tf *tfv1beta1.Tofu) error {
	err := r.Client.Status().Update(ctx, tf)
	if err != nil {
		return fmt.Errorf("failed to update tf status: %s", err)
	}
	return nil
}

func (r ReconcileTofu) updateStatusWithRetry(ctx context.Context, tf *tfv1beta1.Tofu, desiredStatus *tfv1beta1.TofuStatus, logger logr.Logger) error {
	resourceNamespacedName := types.NamespacedName{Namespace: tf.Namespace, Name: tf.Name}
	var getResourceErr error
	var updateErr error
	for i := 0; i < 10; i++ {
		if i > 0 {
			n := math.Pow(2, float64(i+3))
			backoffTime := math.Ceil(.5 * (n - 1))
			time.Sleep(time.Duration(backoffTime) * time.Millisecond)
			tf, getResourceErr = r.getTerraformResource(ctx, resourceNamespacedName, 10, logger)
			if getResourceErr != nil {
				return fmt.Errorf("failed to get latest terraform while updating status: %s", getResourceErr)
			}
			if desiredStatus != nil {
				tf.Status = *desiredStatus
			}
		}
		updateErr = r.Client.Status().Update(ctx, tf)
		if updateErr != nil {
			logger.V(7).Info(fmt.Sprintf("Retrying to update status because an error has occurred while updating: %s", updateErr))
			continue
		}

		// Confirm the status is up to date
		isUpdateConfirmed := false
		for j := 0; j < 10; j++ {
			tf, updatedResourceErr := r.getTerraformResource(ctx, resourceNamespacedName, 10, logger)
			if updatedResourceErr != nil {
				return fmt.Errorf("failed to get latest terraform while validating status: %s", updatedResourceErr)
			}

			if !tfv1beta1.TaskListsAreEqual(tf.Status.PluginsStarted, desiredStatus.PluginsStarted) {
				logger.V(7).Info(fmt.Sprintf("Failed to confirm the status update because plugins did not equal. Have %s and Want %s", tf.Status.PluginsStarted, desiredStatus.PluginsStarted))

			} else if stageItem := tf.Status.Stage.IsEqual(desiredStatus.Stage); stageItem != "" {
				logger.V(7).Info(fmt.Sprintf("Failed to confirm the status update because stage item %s did not equal", stageItem))

			} else if tf.Status.Phase != desiredStatus.Phase {
				logger.V(7).Info("Failed to confirm the status update because phase did not equal")

			} else if tf.Status.PodNamePrefix != desiredStatus.PodNamePrefix {
				logger.V(7).Info("Failed to confirm the status update because podNamePrefix did not equal")

			} else {
				isUpdateConfirmed = true
			}

			if isUpdateConfirmed {
				break
			}

			logger.V(7).Info("Retrying to confirm the status update")
			n := math.Pow(2, float64(j+3))
			backoffTime := math.Ceil(.5 * (n - 1))
			time.Sleep(time.Duration(backoffTime) * time.Millisecond)
		}

		if isUpdateConfirmed {
			break
		}
		logger.V(7).Info("Retrying to update status because the update was not confirmed")

	}
	if updateErr != nil {
		return fmt.Errorf("failed to update tf status: %s", updateErr)
	}
	return nil
}

// IsJobFinished returns true if the job has completed
func IsJobFinished(job *batchv1.Job) bool {
	BackoffLimit := job.Spec.BackoffLimit
	return job.Status.CompletionTime != nil || (job.Status.Active == 0 && BackoffLimit != nil && job.Status.Failed >= *BackoffLimit)
}

func formatJobSSHConfig(ctx context.Context, reqLogger logr.Logger, tf *tfv1beta1.Tofu, k8sclient client.Client) (map[string][]byte, error) {
	data := make(map[string]string)
	dataAsByte := make(map[string][]byte)
	if tf.Spec.SSHTunnel != nil {
		data["config"] = fmt.Sprintf("Host proxy\n"+
			"\tStrictHostKeyChecking no\n"+
			"\tUserKnownHostsFile=/dev/null\n"+
			"\tUser %s\n"+
			"\tHostname %s\n"+
			"\tIdentityFile ~/.ssh/proxy_key\n",
			tf.Spec.SSHTunnel.User,
			tf.Spec.SSHTunnel.Host)
		k := tf.Spec.SSHTunnel.SSHKeySecretRef.Key
		if k == "" {
			k = "id_rsa"
		}
		ns := tf.Spec.SSHTunnel.SSHKeySecretRef.Namespace
		if ns == "" {
			ns = tf.Namespace
		}

		key, err := loadPassword(ctx, k8sclient, k, tf.Spec.SSHTunnel.SSHKeySecretRef.Name, ns)
		if err != nil {
			return dataAsByte, err
		}
		data["proxy_key"] = key

	}

	for _, m := range tf.Spec.SCMAuthMethods {

		// TODO validate SSH in resource manifest
		if m.Git.SSH != nil {
			if m.Git.SSH.RequireProxy {
				data["config"] += fmt.Sprintf("\nHost %s\n"+
					"\tStrictHostKeyChecking no\n"+
					"\tUserKnownHostsFile=/dev/null\n"+
					"\tHostname %s\n"+
					"\tIdentityFile ~/.ssh/%s\n"+
					"\tProxyJump proxy",
					m.Host,
					m.Host,
					m.Host)
			} else {
				data["config"] += fmt.Sprintf("\nHost %s\n"+
					"\tStrictHostKeyChecking no\n"+
					"\tUserKnownHostsFile=/dev/null\n"+
					"\tHostname %s\n"+
					"\tIdentityFile ~/.ssh/%s\n",
					m.Host,
					m.Host,
					m.Host)
			}
			k := m.Git.SSH.SSHKeySecretRef.Key
			if k == "" {
				k = "id_rsa"
			}
			ns := m.Git.SSH.SSHKeySecretRef.Namespace
			if ns == "" {
				ns = tf.Namespace
			}
			key, err := loadPassword(ctx, k8sclient, k, m.Git.SSH.SSHKeySecretRef.Name, ns)
			if err != nil {
				return dataAsByte, err
			}
			data[m.Host] = key
		}
	}

	for k, v := range data {
		dataAsByte[k] = []byte(v)
	}

	return dataAsByte, nil
}

func (r *ReconcileTofu) setupAndRun(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	reqLogger := r.Log.WithValues("Tofu", types.NamespacedName{Name: tf.Name, Namespace: tf.Namespace}.String())
	var err error

	reason := tf.Status.Stage.Reason
	isNewGeneration := reason == "GENERATION_CHANGE" || reason == "TF_RESOURCE_DELETED"
	isFirstInstall := reason == "TF_RESOURCE_CREATED"
	isChanged := isNewGeneration || isFirstInstall
	// r.Recorder.Event(tf, "Normal", "InitializeJobCreate", fmt.Sprintf("Setting up a Job"))
	// TODO(user): Add the cleanup steps that the operator
	// needs to do before the CR can be deleted. Examples
	// of finalizers include performing backups and deleting
	// resources that are not owned by this CR, like a PVC.
	scmMap := make(map[string]scmType)
	for _, v := range tf.Spec.SCMAuthMethods {
		if v.Git != nil {
			scmMap[v.Host] = gitScmType
		}
	}

	if tf.Spec.TerraformModule.Inline != "" {
		// Inline module: content goes directly into the addons configmap.
		runOpts.mainModulePluginData["inline-module.tf"] = tf.Spec.TerraformModule.Inline
	} else if tf.Spec.TerraformModule.ConfigMapSeclector_x != nil {
		// Read the module ConfigMap and inject its content into the addons
		// configmap. The runner pod gets the module files directly -- no
		// kubectl needed, no RBAC for the runner SA to read configmaps.
		if err := r.injectConfigMapModule(ctx, tf.Spec.TerraformModule.ConfigMapSeclector_x, tf.Namespace, &runOpts); err != nil {
			return err
		}
	} else if tf.Spec.TerraformModule.ConfigMapSelector != nil {
		if err := r.injectConfigMapModule(ctx, tf.Spec.TerraformModule.ConfigMapSelector, tf.Namespace, &runOpts); err != nil {
			return err
		}
	} else if tf.Spec.TerraformModule.Source != "" {
		runOpts.terraformModuleParsed, err = getParsedAddress(tf.Spec.TerraformModule.Source, "", false, scmMap)
		if err != nil {
			return err
		}
	} else {
		return fmt.Errorf("no terraform module detected")
	}

	if isChanged {
		// Secret finalizers
		if err := r.updateSecretFinalizer(ctx, tf); err != nil {
			reqLogger.V(3).Info("Could not update secret finalizer", "ERR", err.Error())
		}

		go r.reapPlugins(tf, 0)

		// Add all default inine files
		runOpts.mainModulePluginData["default-terraform.sh"] = defaultInlineTerraformTaskExecutionFile
		runOpts.mainModulePluginData["default-setup.sh"] = defaultInlineSetupTaskExecutionFile
		runOpts.mainModulePluginData["default-noop.sh"] = defaultInlineNoOpExecutionFile

		for _, taskOption := range tf.Spec.TaskOptions {
			if inlineScript := taskOption.Script.Inline; inlineScript != "" {
				for _, affected := range taskOption.For {
					if affected.String() == "*" {
						continue
					}
					// This adds all the inline scripts found in taskOptions into a configmap. The configmap is not changed
					// for the generation of the workflow.
					runOpts.mainModulePluginData[fmt.Sprintf("inline-%s.sh", affected)] = inlineScript

				}
			}
		}

		// Set up the HTTPS token to use if defined
		for _, m := range tf.Spec.SCMAuthMethods {
			// This loop is used to find the first HTTPS token-based
			// authentication which gets added to all runners' "GIT_ASKPASS"
			// script/env var.
			// TODO
			//		Is there a way to allow multiple tokens for HTTPS access
			//		to git scm?
			if m.Git.HTTPS != nil {
				if _, found := runOpts.secretData["gitAskpass"]; found {
					continue
				}
				tokenSecret := *m.Git.HTTPS.TokenSecretRef
				if tokenSecret.Key == "" {
					tokenSecret.Key = "token"
				}
				gitAskpass, err := r.createGitAskpass(ctx, tokenSecret)
				if err != nil {
					return err
				}
				runOpts.secretData["gitAskpass"] = gitAskpass

			}
		}

		// Set up the SSH keys to use if defined
		sshConfigData, err := formatJobSSHConfig(ctx, reqLogger, tf, r.Client)
		if err != nil {
			r.Recorder.Event(tf, "Warning", "SSHConfigError", fmt.Errorf("%v", err).Error())
			return fmt.Errorf("error setting up sshconfig: %v", err)
		}
		for k, v := range sshConfigData {
			runOpts.secretData[k] = v
		}

		resourceDownloadItems := []ParsedAddress{}
		// Configure the resourceDownloads in JSON that the setupRunner will
		// use to download the resources into the main module directory

		// ConfigMap Data only needs to be updated when generation changes
		if tf.Spec.Setup != nil {
			for _, s := range tf.Spec.Setup.ResourceDownloads {
				address := strings.TrimSpace(s.Address)
				parsedAddress, err := getParsedAddress(address, s.Path, s.UseAsVar, scmMap)
				if err != nil {
					return err
				}
				// b, err := json.Marshal(parsedAddress)
				// if err != nil {
				// 	return err
				// }
				resourceDownloadItems = append(resourceDownloadItems, parsedAddress)
			}
		}
		b, err := json.Marshal(resourceDownloadItems)
		if err != nil {
			return err
		}
		resourceDownloads := string(b)

		runOpts.mainModulePluginData[".__TFO__ResourceDownloads.json"] = resourceDownloads

		// Override the backend.tf by inserting a custom backend
		runOpts.mainModulePluginData["backend_override.tf"] = tf.Spec.Backend
	}

	// RUN
	err = r.run(ctx, reqLogger, tf, runOpts, isNewGeneration, isFirstInstall)
	if err != nil {
		return err
	}

	return nil
}

func (r ReconcileTofu) checkPersistentVolumeClaimExists(ctx context.Context, lookupKey types.NamespacedName) (*corev1.PersistentVolumeClaim, bool, error) {
	resource := &corev1.PersistentVolumeClaim{}

	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) createPVC(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "PersistentVolumeClaim"
	_, found, err := r.checkPersistentVolumeClaimExists(ctx, types.NamespacedName{
		Name:      runOpts.prefixedName,
		Namespace: runOpts.namespace,
	})
	if err != nil {
		return nil
	} else if found {
		return nil
	}
	persistentVolumeSize := resource.MustParse("2Gi")
	if tf.Spec.PersistentVolumeSize != nil {
		persistentVolumeSize = *tf.Spec.PersistentVolumeSize
	}
	resource := runOpts.generatePVC(persistentVolumeSize, tf.Spec.StorageClassName)
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r ReconcileTofu) checkConfigMapExists(ctx context.Context, lookupKey types.NamespacedName) (*corev1.ConfigMap, bool, error) {
	resource := &corev1.ConfigMap{}

	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) deleteConfigMapIfExists(ctx context.Context, name, namespace string) error {
	lookupKey := types.NamespacedName{
		Name:      name,
		Namespace: namespace,
	}
	resource, found, err := r.checkConfigMapExists(ctx, lookupKey)
	if err != nil {
		return err
	}
	if found {
		err = r.Client.Delete(ctx, resource)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) createConfigMap(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "ConfigMap"

	resource := runOpts.generateConfigMap()
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err := r.deleteConfigMapIfExists(ctx, resource.Name, resource.Namespace)
	if err != nil {
		return err
	}
	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r ReconcileTofu) checkSecretExists(ctx context.Context, lookupKey types.NamespacedName) (*corev1.Secret, bool, error) {
	resource := &corev1.Secret{}

	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) deleteSecretIfExists(ctx context.Context, name, namespace string) error {
	lookupKey := types.NamespacedName{
		Name:      name,
		Namespace: namespace,
	}
	resource, found, err := r.checkSecretExists(ctx, lookupKey)
	if err != nil {
		return err
	}
	if found {
		err = r.Client.Delete(ctx, resource)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) createSecret(ctx context.Context, tf *tfv1beta1.Tofu, name, namespace string, data map[string][]byte, recreate bool, labelsToOmit []string, runOpts TaskOptions) error {
	kind := "Secret"

	// Must make a clean map of labels since the memory address is shared
	// for the entire RunOptions struct
	labels := make(map[string]string)
	for key, value := range runOpts.resourceLabels {
		labels[key] = value
	}
	for _, labelKey := range labelsToOmit {
		delete(labels, labelKey)
	}

	resource := runOpts.generateSecret(name, namespace, data, labels)
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	if recreate {
		err := r.deleteSecretIfExists(ctx, resource.Name, resource.Namespace)
		if err != nil {
			return err
		}
	}

	err := r.Client.Create(ctx, resource)
	if err != nil {
		if !recreate && errors.IsAlreadyExists(err) {
			// This is acceptable since the resource exists and was not
			// expected to be a new resource.
		} else {
			r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
			return err
		}
	} else {
		r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	}
	return nil
}

func (r ReconcileTofu) checkServiceAccountExists(ctx context.Context, lookupKey types.NamespacedName) (*corev1.ServiceAccount, bool, error) {
	resource := &corev1.ServiceAccount{}

	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) deleteServiceAccountIfExists(ctx context.Context, name, namespace string) error {
	lookupKey := types.NamespacedName{
		Name:      name,
		Namespace: namespace,
	}
	resource, found, err := r.checkServiceAccountExists(ctx, lookupKey)
	if err != nil {
		return err
	}
	if found {
		err = r.Client.Delete(ctx, resource)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) createServiceAccount(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "ServiceAccount"

	resource := runOpts.generateServiceAccount()
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err := r.deleteServiceAccountIfExists(ctx, resource.Name, resource.Namespace)
	if err != nil {
		return err
	}
	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r ReconcileTofu) checkRoleExists(ctx context.Context, lookupKey types.NamespacedName) (*rbacv1.Role, bool, error) {
	resource := &rbacv1.Role{}
	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) deleteRoleIfExists(ctx context.Context, name, namespace string) error {
	lookupKey := types.NamespacedName{
		Name:      name,
		Namespace: namespace,
	}
	resource, found, err := r.checkRoleExists(ctx, lookupKey)
	if err != nil {
		return err
	}
	if found {
		err = r.Client.Delete(ctx, resource)
		if err != nil {
			return err
		}
	}
	return nil
}

// injectConfigMapModule reads the user's module ConfigMap and puts its content
// directly into the addons configmap data. The runner pod gets the .tf files
// without needing kubectl or RBAC to read configmaps.
func (r ReconcileTofu) injectConfigMapModule(ctx context.Context, sel *tfv1beta1.ConfigMapSelector, namespace string, runOpts *TaskOptions) error {
	var cm corev1.ConfigMap
	if err := r.Client.Get(ctx, types.NamespacedName{Name: sel.Name, Namespace: namespace}, &cm); err != nil {
		return fmt.Errorf("get module configmap %s: %w", sel.Name, err)
	}

	if sel.Key != "" {
		// Single key: inject one file as inline-module.tf
		content, ok := cm.Data[sel.Key]
		if !ok {
			return fmt.Errorf("key %q not found in configmap %s", sel.Key, sel.Name)
		}
		runOpts.mainModulePluginData["inline-module.tf"] = content
	} else {
		// All keys: inject each as a file in the module directory.
		for key, content := range cm.Data {
			runOpts.mainModulePluginData[key] = content
		}
	}
	return nil
}

func (r ReconcileTofu) createRole(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "Role"

	resource := runOpts.generateRole()
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err := r.deleteRoleIfExists(ctx, resource.Name, resource.Namespace)
	if err != nil {
		return err
	}
	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r ReconcileTofu) checkRoleBindingExists(ctx context.Context, lookupKey types.NamespacedName) (*rbacv1.RoleBinding, bool, error) {
	resource := &rbacv1.RoleBinding{}
	err := r.Client.Get(ctx, lookupKey, resource)
	if err != nil && errors.IsNotFound(err) {
		return resource, false, nil
	} else if err != nil {
		return resource, false, err
	}
	return resource, true, nil
}

func (r ReconcileTofu) deleteRoleBindingIfExists(ctx context.Context, name, namespace string) error {
	lookupKey := types.NamespacedName{
		Name:      name,
		Namespace: namespace,
	}
	resource, found, err := r.checkRoleBindingExists(ctx, lookupKey)
	if err != nil {
		return err
	}
	if found {
		err = r.Client.Delete(ctx, resource)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r ReconcileTofu) createRoleBinding(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "RoleBinding"

	resource := runOpts.generateRoleBinding()
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err := r.deleteRoleBindingIfExists(ctx, resource.Name, resource.Namespace)
	if err != nil {
		return err
	}
	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r ReconcileTofu) createPod(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "Pod"

	resource, err := runOpts.generatePod()
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("%s", err))
		return err
	}

	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err = r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func int32p(i int32) *int32 {
	return &i
}

func (r ReconcileTofu) createJob(ctx context.Context, tf *tfv1beta1.Tofu, runOpts TaskOptions) error {
	kind := "Job"

	resource := runOpts.generateJob()
	controllerutil.SetControllerReference(tf, resource, r.Scheme)

	err := r.Client.Create(ctx, resource)
	if err != nil {
		r.Recorder.Event(tf, "Warning", fmt.Sprintf("%sCreateError", kind), fmt.Sprintf("Could not create %s %v", kind, err))
		return err
	}
	r.Recorder.Event(tf, "Normal", "SuccessfulCreate", fmt.Sprintf("Created %s: '%s'", kind, resource.Name))
	return nil
}

func (r TaskOptions) generateJob() *batchv1.Job {
	pod, _ := r.generatePod()

	// In a job, pod's can only have OnFailure or Never restart policies
	if pod.Spec.RestartPolicy == corev1.RestartPolicyAlways || pod.Spec.RestartPolicy == corev1.RestartPolicyOnFailure {
		pod.Spec.RestartPolicy = corev1.RestartPolicyOnFailure
	} else {
		pod.Spec.RestartPolicy = corev1.RestartPolicyNever
	}
	return &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name:         pod.Name,
			GenerateName: pod.GenerateName,
			Labels:       pod.Labels,
			Annotations:  pod.Annotations,
			Namespace:    pod.Namespace,
		},
		Spec: batchv1.JobSpec{
			BackoffLimit: int32p(1000000),
			Template: corev1.PodTemplateSpec{
				Spec: pod.Spec,
			},
		},
	}
}

func (r TaskOptions) generateConfigMap() *corev1.ConfigMap {

	cm := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      r.versionedName,
			Namespace: r.namespace,
			Labels:    r.resourceLabels,
		},
		Data: r.mainModulePluginData,
	}
	return cm
}

func (r TaskOptions) generateServiceAccount() *corev1.ServiceAccount {
	annotations := make(map[string]string)

	for _, c := range r.credentials {
		for k, v := range c.ServiceAccountAnnotations {
			annotations[k] = v
		}
		if c.AWSCredentials.IRSA != "" {
			annotations["eks.amazonaws.com/role-arn"] = c.AWSCredentials.IRSA
		}
	}

	sa := &corev1.ServiceAccount{
		ObjectMeta: metav1.ObjectMeta{
			Name:        r.serviceAccount, // "tf-" + r.versionedName
			Namespace:   r.namespace,
			Annotations: annotations,
			Labels:      r.resourceLabels,
		},
	}
	return sa
}

func (r TaskOptions) generateRole() *rbacv1.Role {
	// TODO tighten up default rbac security since all the cm and secret names
	// can be predicted.

	rules := []rbacv1.PolicyRule{
		{
			Verbs:     []string{"*"},
			APIGroups: []string{""},
			Resources: []string{"configmaps"},
		},
		{
			Verbs:         []string{"get"},
			APIGroups:     []string{"tf.defn.dev"},
			Resources:     []string{"terraforms"},
			ResourceNames: []string{r.resourceName},
		},
	}

	// When using the Kubernetes backend, allow the operator to create secrets and leases
	secretsRule := rbacv1.PolicyRule{
		Verbs:     []string{"*"},
		APIGroups: []string{""},
		Resources: []string{"secrets"},
	}
	leasesRule := rbacv1.PolicyRule{
		Verbs:     []string{"*"},
		APIGroups: []string{"coordination.k8s.io"},
		Resources: []string{"leases"},
	}
	if r.mainModulePluginData["backend_override.tf"] != "" {
		// parse the backennd string the way most people write it
		// example:
		// terraform {
		//   backend "kubernetes" {
		//     ...
		//   }
		// }
		s := strings.Split(r.mainModulePluginData["backend_override.tf"], "\n")
		for _, line := range s {
			// Assuming that config lines contain an equal sign
			// All other lines are discarded
			if strings.Contains(line, "backend ") && strings.Contains(line, "kubernetes") {
				// the extra space in "backend " is intentional since thats generally
				// how it's written
				rules = append(rules, secretsRule, leasesRule)
				break
			}
		}
	}

	rules = append(rules, r.policyRules...)

	role := &rbacv1.Role{
		ObjectMeta: metav1.ObjectMeta{
			Name:      r.versionedName,
			Namespace: r.namespace,
			Labels:    r.resourceLabels,
		},
		Rules: rules,
	}
	return role
}

func (r TaskOptions) generateRoleBinding() *rbacv1.RoleBinding {
	rb := &rbacv1.RoleBinding{
		ObjectMeta: metav1.ObjectMeta{
			Name:      r.versionedName,
			Namespace: r.namespace,
			Labels:    r.resourceLabels,
		},
		Subjects: []rbacv1.Subject{
			{
				Kind:      "ServiceAccount",
				Name:      r.serviceAccount,
				Namespace: r.namespace,
			},
		},
		RoleRef: rbacv1.RoleRef{
			Kind:     "Role",
			Name:     r.versionedName,
			APIGroup: "rbac.authorization.k8s.io",
		},
	}
	return rb
}

func (r TaskOptions) generatePVC(size resource.Quantity, storageClassName *string) *corev1.PersistentVolumeClaim {
	return &corev1.PersistentVolumeClaim{
		ObjectMeta: metav1.ObjectMeta{
			Name:      r.prefixedName,
			Namespace: r.namespace,
			Labels:    r.resourceLabels,
		},
		Spec: corev1.PersistentVolumeClaimSpec{
			AccessModes: []corev1.PersistentVolumeAccessMode{
				corev1.ReadWriteOnce,
			},
			StorageClassName: storageClassName,
			Resources: corev1.VolumeResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceStorage: size,
				},
			},
		},
	}
}

func (r TaskOptions) validateVolume() error {
	prohibitedNames := map[string]string{
		"tfohome":            "",
		"config-map-source":  "",
		"main-module-addons": "",
		"gitaskpass":         "",
		"ssh":                "",
	}
	mounts := map[string]string{}
	volumes := map[string]string{}

	for _, v := range r.volumeMounts {
		mounts[v.Name] = ""
	}

	for _, v := range r.volumes {
		// check if any system volume name is defined in task volumes
		_, ok := prohibitedNames[v.Name]
		if ok {
			return fmt.Errorf("task '%s' is misconfigured: volume name '%s' is reserved by tf-operator", r.task, v.Name)
		}
		// check if volume name has his own volumeMount
		_, ok = mounts[v.Name]
		if !ok {
			return fmt.Errorf("task '%s' is misconfigured: volume: '%s' doesn't have corresponding volumeMount", r.task, v.Name)
		}
		volumes[v.Name] = ""
	}

	for _, v := range r.volumeMounts {
		// check if volumeMount refers to existing volume
		_, ok := volumes[v.Name]
		if !ok {
			return fmt.Errorf("task '%s' is misconfigured: volumeMount: '%s' doesn't have corresponding volume", r.task, v.Name)
		}
	}

	return nil
}

// generatePod puts together all the contents required to execute the taskType.
// Although most of the tasks use similar.... (TODO EDIT ME)
func (r TaskOptions) generatePod() (*corev1.Pod, error) {

	home := "/home/tfo-runner"
	generateName := r.versionedName + "-" + r.task.String() + "-"
	generationPath := fmt.Sprintf("%s/generations/%d", home, r.generation)

	runnerLabels := r.labels
	annotations := r.annotations
	envFrom := r.envFrom
	envs := r.env
	envs = append(envs, []corev1.EnvVar{
		{
			Name: "POD_UID",
			ValueFrom: &corev1.EnvVarSource{
				FieldRef: &corev1.ObjectFieldSelector{
					FieldPath: "metadata.uid",
				},
			},
		},
		{
			/*

				What is the significance of having an env about the TFO_RUNNER?

				Only used to idenify the taskType for the log.out file. This
				should simply be the taskType name.

			*/
			Name:  "TFO_TASK",
			Value: r.task.String(),
		},
		{
			Name:  "TFO_TASK_EXEC_URL_SOURCE",
			Value: r.urlSource,
		},
		{
			Name:  "TFO_TASK_EXEC_CONFIGMAP_SOURCE_NAME",
			Value: r.configMapSourceName,
		},
		{
			Name:  "TFO_TASK_EXEC_CONFIGMAP_SOURCE_KEY",
			Value: r.configMapSourceKey,
		},
		{
			Name:  "TFO_TASK_EXEC_INLINE_SOURCE_FILE",
			Value: r.inlineTaskExecutionFile,
		},
		{
			Name:  "TFO_RESOURCE",
			Value: r.resourceName,
		},
		{
			Name:  "TFO_RESOURCE_UUID",
			Value: r.resourceUUID,
		},
		{
			Name:  "TFO_NAMESPACE",
			Value: r.namespace,
		},
		{
			Name:  "TFO_GENERATION",
			Value: fmt.Sprintf("%d", r.generation),
		},
		{
			Name:  "TFO_GENERATION_PATH",
			Value: generationPath,
		},
		{
			Name:  "TFO_MAIN_MODULE",
			Value: generationPath + "/main",
		},
		{
			Name:  "TFO_TERRAFORM_VERSION",
			Value: r.terraformVersion,
		},
		{
			Name:  "TFO_SAVE_OUTPUTS",
			Value: strconv.FormatBool(r.saveOutputs),
		},
		{
			Name:  "TFO_OUTPUTS_SECRET_NAME",
			Value: r.outputsSecretName,
		},
		{
			Name:  "TFO_OUTPUTS_TO_INCLUDE",
			Value: strings.Join(r.outputsToInclude, ","),
		},
		{
			Name:  "TFO_OUTPUTS_TO_OMIT",
			Value: strings.Join(r.outputsToOmit, ","),
		},
	}...)

	if r.cleanupDisk {
		envs = append(envs, corev1.EnvVar{
			Name:  "TFO_CLEANUP_DISK",
			Value: "true",
		})
	}

	volumes := []corev1.Volume{
		{
			Name: "tfohome",
			VolumeSource: corev1.VolumeSource{
				//
				// TODO add an option to the tf to use host or pvc
				// 		for the plan.
				//
				PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
					ClaimName: r.prefixedName,
					ReadOnly:  false,
				},
				//
				// TODO if host is used, develop a cleanup plan so
				//		so the volume does not fill up with old data
				//
				// TODO if host is used, affinity rules must be placed
				// 		that will ensure all the pods use the same host
				//
				// HostPath: &corev1.HostPathVolumeSource{
				// 	Path: "/mnt",
				// },
			},
		},
	}

	if err := r.validateVolume(); err != nil {
		return nil, err
	}
	volumes = append(volumes, r.volumes...)
	volumeMounts := []corev1.VolumeMount{
		{
			Name:      "tfohome",
			MountPath: home,
			ReadOnly:  false,
		},
	}
	volumeMounts = append(volumeMounts, r.volumeMounts...)
	envs = append(envs, corev1.EnvVar{
		Name:  "TFO_ROOT_PATH",
		Value: home,
	})

	if r.terraformModuleParsed.Repo != "" {
		envs = append(envs, []corev1.EnvVar{
			{
				Name:  "TFO_MAIN_MODULE_REPO",
				Value: r.terraformModuleParsed.Repo,
			},
			{
				Name:  "TFO_MAIN_MODULE_REPO_REF",
				Value: r.terraformModuleParsed.Hash,
			},
		}...)

		if len(r.terraformModuleParsed.Files) > 0 {
			// The terraform module may be in a sub-directory of the repo
			// Add this subdir value to envs so the pod can properly fetch it
			value := r.terraformModuleParsed.Files[0]
			if value == "" {
				value = "."
			}
			envs = append(envs, []corev1.EnvVar{
				{
					Name:  "TFO_MAIN_MODULE_REPO_SUBDIR",
					Value: value,
				},
			}...)
		} else {
			// TODO maybe set a default in r.stack.subdirs[0] so we can get rid
			//		of this if statement
			envs = append(envs, []corev1.EnvVar{
				{
					Name:  "TFO_MAIN_MODULE_REPO_SUBDIR",
					Value: ".",
				},
			}...)
		}
	}

	configMapSourceVolumeName := "config-map-source"
	configMapSourcePath := "/tmp/config-map-source"
	if r.configMapSourceName != "" && r.configMapSourceKey != "" {
		volumes = append(volumes, corev1.Volume{
			Name: configMapSourceVolumeName,
			VolumeSource: corev1.VolumeSource{
				ConfigMap: &corev1.ConfigMapVolumeSource{
					LocalObjectReference: corev1.LocalObjectReference{
						Name: r.configMapSourceName,
					},
				},
			},
		})
		volumeMounts = append(volumeMounts, corev1.VolumeMount{
			Name:      configMapSourceVolumeName,
			MountPath: configMapSourcePath,
		})
	}
	envs = append(envs, []corev1.EnvVar{
		{
			Name:  "TFO_TASK_EXEC_CONFIGMAP_SOURCE_PATH",
			Value: configMapSourcePath,
		},
	}...)

	mainModulePluginsConfigMapName := "main-module-addons"
	mainModulePluginsConfigMapPath := "/tmp/main-module-addons"
	volumes = append(volumes, []corev1.Volume{
		{
			Name: mainModulePluginsConfigMapName,
			VolumeSource: corev1.VolumeSource{
				ConfigMap: &corev1.ConfigMapVolumeSource{
					LocalObjectReference: corev1.LocalObjectReference{
						Name: r.versionedName,
					},
				},
			},
		},
	}...)
	volumeMounts = append(volumeMounts, []corev1.VolumeMount{
		{
			Name:      mainModulePluginsConfigMapName,
			MountPath: mainModulePluginsConfigMapPath,
		},
	}...)
	envs = append(envs, []corev1.EnvVar{
		{
			Name:  "TFO_MAIN_MODULE_ADDONS",
			Value: mainModulePluginsConfigMapPath,
		},
	}...)

	optional := true
	xmode := int32(0775)
	volumes = append(volumes, corev1.Volume{
		Name: "gitaskpass",
		VolumeSource: corev1.VolumeSource{
			Secret: &corev1.SecretVolumeSource{
				SecretName: r.versionedName,
				Optional:   &optional,
				Items: []corev1.KeyToPath{
					{
						Key:  "gitAskpass",
						Path: "GIT_ASKPASS",
						Mode: &xmode,
					},
				},
			},
		},
	})
	volumeMounts = append(volumeMounts, []corev1.VolumeMount{
		{
			Name:      "gitaskpass",
			MountPath: "/git/askpass",
		},
	}...)
	envs = append(envs, []corev1.EnvVar{
		{
			Name:  "GIT_ASKPASS",
			Value: "/git/askpass/GIT_ASKPASS",
		},
	}...)

	sshMountName := "ssh"
	sshMountPath := "/tmp/ssh"
	mode := int32(0775)
	sshConfigItems := []corev1.KeyToPath{}
	keysToIgnore := []string{"gitAskpass"}
	for key := range r.secretData {
		if utils.ListContainsStr(keysToIgnore, key) {
			continue
		}
		sshConfigItems = append(sshConfigItems, corev1.KeyToPath{
			Key:  key,
			Path: key,
			Mode: &mode,
		})
	}
	volumes = append(volumes, []corev1.Volume{
		{
			Name: sshMountName,
			VolumeSource: corev1.VolumeSource{
				Secret: &corev1.SecretVolumeSource{
					SecretName:  r.versionedName,
					DefaultMode: &mode,
					Optional:    &optional,
					Items:       sshConfigItems,
				},
			},
		},
	}...)
	volumeMounts = append(volumeMounts, []corev1.VolumeMount{
		{
			Name:      sshMountName,
			MountPath: sshMountPath,
		},
	}...)
	envs = append(envs, []corev1.EnvVar{
		{
			Name:  "TFO_SSH",
			Value: sshMountPath,
		},
	}...)

	for _, c := range r.credentials {
		if c.AWSCredentials.KIAM != "" {
			annotations["iam.amazonaws.com/role"] = c.AWSCredentials.KIAM
		}
	}

	for _, c := range r.credentials {
		if (tfv1beta1.SecretNameRef{}) != c.SecretNameRef {
			envFrom = append(envFrom, []corev1.EnvFromSource{
				{
					SecretRef: &corev1.SecretEnvSource{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: c.SecretNameRef.Name,
						},
					},
				},
			}...)
		}
	}

	// labels for all resources for use in queries
	for key, value := range r.resourceLabels {
		runnerLabels[key] = value
	}
	runnerLabels["app.kubernetes.io/instance"] = r.task.String()

	// Run as ubuntu (UID 1000) to match the edge container's user.
	// This ensures HOME=/home/ubuntu and mise tools are on PATH.
	user := int64(1000)
	group := int64(1000)
	runAsNonRoot := true
	securityContext := &corev1.SecurityContext{
		RunAsUser:    &user,
		RunAsGroup:   &group,
		RunAsNonRoot: &runAsNonRoot,
	}
	restartPolicy := r.restartPolicy

	containerName := "task"
	if r.task.ID() == -2 {
		containerName = string(r.task)
	}

	// Build the container command. The upstream runner images had a built-in
	// entrypoint that read TFO_TASK_EXEC_INLINE_SOURCE_FILE and executed it.
	// Since we use a generic image (defn edge), we set the command explicitly
	// to execute the inline script from the configmap mount.
	var containerCommand []string
	for _, env := range envs {
		if env.Name == "TFO_TASK_EXEC_INLINE_SOURCE_FILE" && env.Value != "" {
			containerCommand = []string{"/bin/bash", "-e", "/tmp/main-module-addons/" + env.Value}
			break
		}
	}

	containers := []corev1.Container{}
	containers = append(containers, corev1.Container{
		Name:            containerName,
		SecurityContext: securityContext,
		Image:           r.image,
		ImagePullPolicy: r.imagePullPolicy,
		Command:         containerCommand,
		EnvFrom:         envFrom,
		Env:             envs,
		VolumeMounts:    volumeMounts,
	})

	if r.sidecarPlugins != nil {
		for _, sidecarPlugin := range r.sidecarPlugins {
			spec := sidecarPlugin.Spec
			// Updates with sidecar container info when found
			containers = append(containers, spec.Containers...)

			volumeList := []string{}
			for _, volume := range volumes {
				volumeList = append(volumeList, volume.Name)
			}

			for _, volume := range spec.Volumes {
				if !utils.ListContainsStr(volumeList, volume.Name) {
					volumes = append(volumes, volume)
				}
			}
		}
	}

	// Inject IRSA projected token volume, env vars, and volume mount when
	// credentials.aws.irsa is set. In k3d (no EKS pod identity webhook),
	// we must configure this ourselves on the runner pod.
	irsaRoleARN := ""
	for _, c := range r.credentials {
		if c.AWSCredentials.IRSA != "" {
			irsaRoleARN = c.AWSCredentials.IRSA
			break
		}
	}
	if irsaRoleARN != "" {
		tokenExpiry := int64(86400)
		volumes = append(volumes, corev1.Volume{
			Name: "irsa-token",
			VolumeSource: corev1.VolumeSource{
				Projected: &corev1.ProjectedVolumeSource{
					Sources: []corev1.VolumeProjection{{
						ServiceAccountToken: &corev1.ServiceAccountTokenProjection{
							Audience:          "sts.amazonaws.com",
							ExpirationSeconds: &tokenExpiry,
							Path:              "token",
						},
					}},
				},
			},
		})
		irsaEnvs := []corev1.EnvVar{
			{Name: "AWS_ROLE_ARN", Value: irsaRoleARN},
			{Name: "AWS_WEB_IDENTITY_TOKEN_FILE", Value: "/var/run/secrets/irsa/token"},
		}
		irsaMount := corev1.VolumeMount{
			Name:      "irsa-token",
			MountPath: "/var/run/secrets/irsa",
			ReadOnly:  true,
		}
		for i := range containers {
			containers[i].Env = append(containers[i].Env, irsaEnvs...)
			containers[i].VolumeMounts = append(containers[i].VolumeMounts, irsaMount)
		}
	}

	podSecurityContext := corev1.PodSecurityContext{
		FSGroup:            &group,
		RunAsUser:          &user,
		RunAsGroup:         &group,
		SupplementalGroups: []int64{group},
	}

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: generateName,
			Namespace:    r.namespace,
			Labels:       runnerLabels,
			Annotations:  annotations,
		},
		Spec: corev1.PodSpec{
			Affinity:           r.inheritedAffinity,
			NodeSelector:       r.inheritedNodeSelector,
			Tolerations:        r.inheritedTolerations,
			SecurityContext:    &podSecurityContext,
			ServiceAccountName: r.serviceAccount,
			RestartPolicy:      restartPolicy,
			Containers:         containers,
			Volumes:            volumes,
		},
	}

	return pod, nil
}

func (r ReconcileTofu) run(ctx context.Context, reqLogger logr.Logger, tf *tfv1beta1.Tofu, runOpts TaskOptions, isNewGeneration, isFirstInstall bool) (err error) {

	if isFirstInstall || isNewGeneration {
		if err := r.createEnvFromSources(ctx, tf); err != nil {
			return err
		}

		if err := r.createPVC(ctx, tf, runOpts); err != nil {
			return err
		}

		if err := r.createSecret(ctx, tf, runOpts.versionedName, runOpts.namespace, runOpts.secretData, true, []string{}, runOpts); err != nil {
			return err
		}

		if err := r.createConfigMap(ctx, tf, runOpts); err != nil {
			return err
		}

		if err := r.createRoleBinding(ctx, tf, runOpts); err != nil {
			return err
		}

		if err := r.createRole(ctx, tf, runOpts); err != nil {
			return err
		}

		if tf.Spec.ServiceAccount == "" {
			// since sa is not defined in the resource spec, it must be created
			if err := r.createServiceAccount(ctx, tf, runOpts); err != nil {
				return err
			}
		}

		labelsToOmit := []string{}
		if runOpts.stripGenerationLabelOnOutputsSecret {
			labelsToOmit = append(labelsToOmit, "tofus.tf.defn.dev/generation")
		}
		if err := r.createSecret(ctx, tf, runOpts.outputsSecretName, runOpts.namespace, map[string][]byte{}, false, labelsToOmit, runOpts); err != nil {
			return err
		}

	} else {
		// check resources exists
		lookupKey := types.NamespacedName{
			Name:      runOpts.prefixedName,
			Namespace: runOpts.namespace,
		}

		if _, found, err := r.checkPersistentVolumeClaimExists(ctx, lookupKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find PersistentVolumeClaim '%s'", lookupKey)
		}

		lookupVersionedKey := types.NamespacedName{
			Name:      runOpts.versionedName,
			Namespace: runOpts.namespace,
		}

		if _, found, err := r.checkConfigMapExists(ctx, lookupVersionedKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find ConfigMap '%s'", lookupVersionedKey)
		}

		if _, found, err := r.checkSecretExists(ctx, lookupVersionedKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find Secret '%s'", lookupVersionedKey)
		}

		if _, found, err := r.checkRoleBindingExists(ctx, lookupVersionedKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find RoleBinding '%s'", lookupVersionedKey)
		}

		if _, found, err := r.checkRoleExists(ctx, lookupVersionedKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find Role '%s'", lookupVersionedKey)
		}

		serviceAccountLookupKey := types.NamespacedName{
			Name:      runOpts.serviceAccount,
			Namespace: runOpts.namespace,
		}
		if _, found, err := r.checkServiceAccountExists(ctx, serviceAccountLookupKey); err != nil {
			return err
		} else if !found {
			return fmt.Errorf("could not find ServiceAccount '%s'", serviceAccountLookupKey)
		}

	}

	if err := r.createPod(ctx, tf, runOpts); err != nil {
		return err
	}

	return nil
}

func (r ReconcileTofu) createGitAskpass(ctx context.Context, tokenSecret tfv1beta1.TokenSecretRef) ([]byte, error) {
	secret, err := r.loadSecret(ctx, tokenSecret.Name, tokenSecret.Namespace)
	if err != nil {
		return []byte{}, err
	}
	if key, ok := secret.Data[tokenSecret.Key]; !ok {
		return []byte{}, fmt.Errorf("secret '%s' did not contain '%s'", secret.Name, key)
	}
	s := heredoc.Docf(`
		#!/bin/sh
		exec echo "%s"
	`, secret.Data[tokenSecret.Key])
	gitAskpass := []byte(s)
	return gitAskpass, nil

}

func (r ReconcileTofu) loadSecret(ctx context.Context, name, namespace string) (*corev1.Secret, error) {
	if namespace == "" {
		namespace = "default"
	}
	lookupKey := types.NamespacedName{Name: name, Namespace: namespace}
	secret := &corev1.Secret{}
	err := r.Client.Get(ctx, lookupKey, secret)
	if err != nil {
		return secret, err
	}
	return secret, nil
}

func (r ReconcileTofu) cacheNodeSelectors(ctx context.Context, logger logr.Logger) error {
	var affinity *corev1.Affinity
	var tolerations []corev1.Toleration
	var nodeSelector map[string]string
	if !r.InheritAffinity && !r.InheritNodeSelector && !r.InheritTolerations {
		return nil
	}
	foundAll := true
	_, found := r.Cache.Get(r.AffinityCacheKey)
	if r.InheritAffinity && !found {
		foundAll = false
	}
	_, found = r.Cache.Get(r.NodeSelectorCacheKey)
	if r.InheritNodeSelector && !found {
		foundAll = false
	}
	_, found = r.Cache.Get(r.TolerationsCacheKey)
	if r.InheritTolerations && !found {
		foundAll = false
	}
	if foundAll {
		return nil
	}
	podNamespace := os.Getenv("POD_NAMESPACE")
	if podNamespace == "" {
		logger.Info("POD_NAMESPACE not found but required to get node selectors configs")
		return nil
	}
	podName := os.Getenv("POD_NAME")
	if podName == "" {
		logger.Info("POD_NAME not found but required to get node selectors configs")
		return nil
	}
	podNamespacedName := types.NamespacedName{Namespace: podNamespace, Name: podName}
	pod := corev1.Pod{}
	err := r.Client.Get(ctx, podNamespacedName, &pod)
	if err != nil {
		logger.Info(fmt.Sprintf("Could not get pod '%s'", podNamespacedName.String()))
		return nil
	}
	if len(pod.ObjectMeta.OwnerReferences) != 1 {
		logger.Info(fmt.Sprintf("unexpected ownership for pod '%s'", podNamespacedName.String()))
		return nil
	}
	if pod.ObjectMeta.OwnerReferences[0].Kind != "ReplicaSet" {
		logger.Info(fmt.Sprintf("unexpected ownership kind for pod '%s'", podNamespacedName.String()))
		return nil
	}

	replicaSetName := pod.ObjectMeta.OwnerReferences[0].Name
	replicaSetNamespacedName := types.NamespacedName{Namespace: podNamespace, Name: replicaSetName}
	replicaSet := appsv1.ReplicaSet{}
	err = r.Client.Get(ctx, replicaSetNamespacedName, &replicaSet)
	if err != nil {
		logger.Info(fmt.Sprintf("Could not get replicaset '%s'", replicaSetNamespacedName.String()))
		return nil
	}
	if len(replicaSet.ObjectMeta.OwnerReferences) != 1 {
		logger.Info(fmt.Sprintf("unexpected ownership for replicaSet '%s'", replicaSetNamespacedName.String()))
		return nil
	}
	if replicaSet.ObjectMeta.OwnerReferences[0].Kind != "Deployment" {
		logger.Info(fmt.Sprintf("unexpected ownership kind for replicaSet '%s'", replicaSetNamespacedName.String()))
		return nil
	}

	deploymentName := replicaSet.ObjectMeta.OwnerReferences[0].Name
	deploymentNamespacedName := types.NamespacedName{Namespace: podNamespace, Name: deploymentName}
	deployment := appsv1.Deployment{}
	err = r.Client.Get(ctx, deploymentNamespacedName, &deployment)
	if err != nil {
		logger.Info(fmt.Sprintf("Could not get deployment '%s'", deploymentNamespacedName.String()))
		return nil
	}

	affinity = deployment.Spec.Template.Spec.Affinity
	tolerations = deployment.Spec.Template.Spec.Tolerations
	nodeSelector = deployment.Spec.Template.Spec.NodeSelector

	if r.InheritAffinity {
		r.Cache.Set(r.AffinityCacheKey, affinity, localcache.NoExpiration)
	}

	if r.InheritNodeSelector {
		r.Cache.Set(r.NodeSelectorCacheKey, nodeSelector, localcache.NoExpiration)
	}

	if r.InheritTolerations {
		r.Cache.Set(r.TolerationsCacheKey, tolerations, localcache.NoExpiration)
	}

	return nil
}

func (r TaskOptions) generateSecret(name, namespace string, data map[string][]byte, labels map[string]string) *corev1.Secret {
	secretObject := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels:    labels,
		},
		Data: data,
		Type: corev1.SecretTypeOpaque,
	}
	return secretObject
}

func loadPassword(ctx context.Context, k8sclient client.Client, key, name, namespace string) (string, error) {

	secret := &corev1.Secret{}
	namespacedName := types.NamespacedName{Namespace: namespace, Name: name}
	err := k8sclient.Get(ctx, namespacedName, secret)
	// secret, err := c.clientset.CoreV1().Secrets(namespace).Get(name, metav1.GetOptions{})
	if err != nil {
		return "", fmt.Errorf("could not get secret: %v", err)
	}

	var password []byte
	for k, value := range secret.Data {
		if k == key {
			password = value
		}
	}

	if len(password) == 0 {
		return "", fmt.Errorf("unable to locate '%s' in secret: %v", key, err)
	}

	return string(password), nil

}

// forcedRegexp is the regular expression that finds forced getters. This
// syntax is schema::url, example: git::https://foo.com
var forcedRegexp = regexp.MustCompile(`^([A-Za-z0-9]+)::(.+)$`)

// getForcedGetter takes a source and returns the tuple of the forced
// getter and the raw URL (without the force syntax).
func getForcedGetter(src string) (string, string) {
	var forced string
	if ms := forcedRegexp.FindStringSubmatch(src); ms != nil {
		forced = ms[1]
		src = ms[2]
	}

	return forced, src
}

var sshPattern = regexp.MustCompile("^(?:([^@]+)@)?([^:]+):/?(.+)$")

type sshDetector struct{}

func (s *sshDetector) Detect(src, _ string) (string, bool, error) {
	matched := sshPattern.FindStringSubmatch(src)
	if matched == nil {
		return "", false, nil
	}

	user := matched[1]
	host := matched[2]
	path := matched[3]
	qidx := strings.Index(path, "?")
	if qidx == -1 {
		qidx = len(path)
	}

	var u url.URL
	u.Scheme = "ssh"
	u.User = url.User(user)
	u.Host = host
	u.Path = path[0:qidx]
	if qidx < len(path) {
		q, err := url.ParseQuery(path[qidx+1:])
		if err != nil {
			return "", false, fmt.Errorf("error parsing GitHub SSH URL: %s", err)
		}
		u.RawQuery = q.Encode()
	}

	return u.String(), true, nil
}

type scmType string

var gitScmType scmType = "git"

func getParsedAddress(address, path string, useAsVar bool, scmMap map[string]scmType) (ParsedAddress, error) {
	detectors := []getter.Detector{
		new(sshDetector),
	}

	detectors = append(detectors, getter.Detectors...)

	output, err := getter.Detect(address, "moduleDir", detectors)
	if err != nil {
		return ParsedAddress{}, err
	}

	forcedDetect, result := getForcedGetter(output)
	urlSource, filesSource := getter.SourceDirSubdir(result)

	parsedURL, err := url.Parse(urlSource)
	if err != nil {
		return ParsedAddress{}, err
	}

	scheme := parsedURL.Scheme

	// TODO URL parse rules: github.com should check the url is 'host/user/repo'
	// Currently the below is just a host check which isn't 100% correct
	if utils.ListContainsStr([]string{"github.com"}, parsedURL.Host) {
		scheme = "git"
	}

	// Check scm configuration for hosts and what scheme to map them as
	// Use the scheme of the scm configuration.
	// If git && another scm is defined in the scm configuration, select git.
	// If the user needs another scheme, the user must use forceDetect
	// (ie scheme::url://host...)
	hosts := []string{}
	for host := range scmMap {
		hosts = append(hosts, host)
	}
	if utils.ListContainsStr(hosts, parsedURL.Host) {
		scheme = string(scmMap[parsedURL.Host])
	}

	// forceDetect shall override all other schemes
	if forcedDetect != "" {
		scheme = forcedDetect
	}

	y, err := url.ParseQuery(parsedURL.RawQuery)
	if err != nil {
		return ParsedAddress{}, err
	}
	hash := y.Get("ref")
	if hash == "" {
		hash = "master"
	}

	// subdir can contain a list seperated by double slashes
	files := strings.Split(filesSource, "//")
	if len(files) == 1 && files[0] == "" {
		files = []string{"."}
	}

	// Assign default ports for common protos
	port := parsedURL.Port()
	if port == "" {
		if parsedURL.Scheme == "ssh" {
			port = "22"
		} else if parsedURL.Scheme == "https" {
			port = "443"
		}
	}

	p := ParsedAddress{
		DetectedScheme: scheme,
		Path:           path,
		UseAsVar:       useAsVar,
		Url:            parsedURL.String(),
		Files:          files,
		Hash:           hash,
		UrlScheme:      parsedURL.Scheme,
		Host:           parsedURL.Host,
		Uri:            strings.Split(parsedURL.RequestURI(), "?")[0],
		Port:           port,
		User:           parsedURL.User.Username(),
		Repo:           strings.Split(parsedURL.String(), "?")[0],
	}
	return p, nil
}

func getContainerNames(pod *corev1.Pod) []string {
	s := []string{}
	for _, container := range pod.Spec.Containers {
		s = append(s, container.Name)
	}
	return s
}
