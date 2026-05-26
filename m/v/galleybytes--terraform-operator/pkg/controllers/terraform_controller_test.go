package controllers

import (
	"context"
	"testing"

	tfv1beta1 "github.com/defn/other/m/v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
)

func TestIsTaskInterruptable(t *testing.T) {
	tests := []struct {
		name     string
		task     tfv1beta1.TaskName
		expected tfv1beta1.Interruptible
	}{
		// Uninterruptible tasks (core terraform operations that affect state)
		{"init is not interruptible", tfv1beta1.RunInit, tfv1beta1.CanNotBeInterrupt},
		{"plan is not interruptible", tfv1beta1.RunPlan, tfv1beta1.CanNotBeInterrupt},
		{"apply is not interruptible", tfv1beta1.RunApply, tfv1beta1.CanNotBeInterrupt},
		{"init-delete is not interruptible", tfv1beta1.RunInitDelete, tfv1beta1.CanNotBeInterrupt},
		{"plan-delete is not interruptible", tfv1beta1.RunPlanDelete, tfv1beta1.CanNotBeInterrupt},
		{"apply-delete is not interruptible", tfv1beta1.RunApplyDelete, tfv1beta1.CanNotBeInterrupt},
		// Interruptible tasks (scripts and setup that don't affect terraform state)
		{"setup is interruptible", tfv1beta1.RunSetup, tfv1beta1.CanBeInterrupt},
		{"preinit is interruptible", tfv1beta1.RunPreInit, tfv1beta1.CanBeInterrupt},
		{"postapply is interruptible", tfv1beta1.RunPostApply, tfv1beta1.CanBeInterrupt},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isTaskInterruptable(tt.task)
			if result != tt.expected {
				t.Errorf("isTaskInterruptable(%s) = %v, expected %v", tt.task, result, tt.expected)
			}
		})
	}
}

func TestNextTask(t *testing.T) {
	// Full workflow with optional script tasks
	allTasks := []tfv1beta1.TaskName{
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

	// Minimal workflow (only required tasks, no optional scripts)
	minimalTasks := []tfv1beta1.TaskName{
		tfv1beta1.RunSetup,
		tfv1beta1.RunInit,
		tfv1beta1.RunPlan,
		tfv1beta1.RunApply,
	}

	// Delete workflow
	deleteTasks := []tfv1beta1.TaskName{
		tfv1beta1.RunSetupDelete,
		tfv1beta1.RunInitDelete,
		tfv1beta1.RunPlanDelete,
		tfv1beta1.RunApplyDelete,
	}

	tests := []struct {
		name            string
		currentTask     tfv1beta1.TaskName
		configuredTasks []tfv1beta1.TaskName
		expected        tfv1beta1.TaskName
	}{
		// Verify script tasks are included when configured
		{"setup -> preinit when scripts configured", tfv1beta1.RunSetup, allTasks, tfv1beta1.RunPreInit},
		{"plan -> postplan when scripts configured", tfv1beta1.RunPlan, allTasks, tfv1beta1.RunPostPlan},
		// Verify script tasks are skipped when not configured
		{"setup -> init when no scripts", tfv1beta1.RunSetup, minimalTasks, tfv1beta1.RunInit},
		{"init -> plan when no scripts", tfv1beta1.RunInit, minimalTasks, tfv1beta1.RunPlan},
		{"plan -> apply when no scripts", tfv1beta1.RunPlan, minimalTasks, tfv1beta1.RunApply},
		// Verify workflow ends properly
		{"apply -> nil at end of workflow", tfv1beta1.RunApply, minimalTasks, tfv1beta1.RunNil},
		{"postapply -> nil at end of full workflow", tfv1beta1.RunPostApply, allTasks, tfv1beta1.RunNil},
		// Delete workflow uses separate task sequence
		{"setup-delete -> init-delete", tfv1beta1.RunSetupDelete, deleteTasks, tfv1beta1.RunInitDelete},
		{"apply-delete -> nil at end", tfv1beta1.RunApplyDelete, deleteTasks, tfv1beta1.RunNil},
		// Edge cases
		{"unknown task returns nil", tfv1beta1.TaskName("unknown"), allTasks, tfv1beta1.RunNil},
		{"empty configured tasks returns nil", tfv1beta1.RunSetup, []tfv1beta1.TaskName{}, tfv1beta1.RunNil},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := nextTask(tt.currentTask, tt.configuredTasks)
			if result != tt.expected {
				t.Errorf("nextTask(%s, ...) = %s, expected %s", tt.currentTask, result, tt.expected)
			}
		})
	}
}

func TestGetConfiguredTasks(t *testing.T) {
	t.Run("adds custom script tasks when specified in taskOptions", func(t *testing.T) {
		opts := []tfv1beta1.TaskOption{
			{For: []tfv1beta1.TaskName{tfv1beta1.RunPreInit, tfv1beta1.RunPostApply}},
		}
		result := getConfiguredTasks(&opts)

		hasPreInit := false
		hasPostApply := false
		for _, task := range result {
			if task == tfv1beta1.RunPreInit {
				hasPreInit = true
			}
			if task == tfv1beta1.RunPostApply {
				hasPostApply = true
			}
		}
		if !hasPreInit || !hasPostApply {
			t.Error("getConfiguredTasks should include script tasks when specified in taskOptions")
		}
	})

	t.Run("does not duplicate existing tasks", func(t *testing.T) {
		opts := []tfv1beta1.TaskOption{
			{For: []tfv1beta1.TaskName{tfv1beta1.RunInit}}, // init is already in defaults
		}
		result := getConfiguredTasks(&opts)

		count := 0
		for _, task := range result {
			if task == tfv1beta1.RunInit {
				count++
			}
		}
		if count != 1 {
			t.Errorf("expected exactly 1 init task, found %d", count)
		}
	})

	t.Run("wildcard does not add extra tasks", func(t *testing.T) {
		opts := []tfv1beta1.TaskOption{
			{For: []tfv1beta1.TaskName{"*"}},
		}
		result := getConfiguredTasks(&opts)
		nilResult := getConfiguredTasks(nil)

		if len(result) != len(nilResult) {
			t.Errorf("wildcard should not add tasks: got %d, expected %d", len(result), len(nilResult))
		}
	})
}

func TestGetForcedGetter(t *testing.T) {
	tests := []struct {
		name           string
		src            string
		expectedForced string
		expectedURL    string
	}{
		{"extracts git scheme", "git::https://github.com/example/repo.git", "git", "https://github.com/example/repo.git"},
		{"extracts s3 scheme", "s3::https://s3.amazonaws.com/bucket/module.zip", "s3", "https://s3.amazonaws.com/bucket/module.zip"},
		{"returns empty for plain URL", "https://github.com/example/repo.git", "", "https://github.com/example/repo.git"},
		{"preserves query params", "git::https://github.com/repo.git?ref=v1.0", "git", "https://github.com/repo.git?ref=v1.0"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			forced, url := getForcedGetter(tt.src)
			if forced != tt.expectedForced {
				t.Errorf("getForcedGetter(%q) forced = %q, expected %q", tt.src, forced, tt.expectedForced)
			}
			if url != tt.expectedURL {
				t.Errorf("getForcedGetter(%q) url = %q, expected %q", tt.src, url, tt.expectedURL)
			}
		})
	}
}

func TestSSHDetector_Detect(t *testing.T) {
	detector := &sshDetector{}

	tests := []struct {
		name        string
		src         string
		expectedURL string
		detected    bool
	}{
		{"detects git@host:path format", "git@github.com:example/repo.git", "ssh://git@github.com/example/repo.git", true},
		{"detects user@host:path format", "user@gitlab.com:group/project.git", "ssh://user@gitlab.com/group/project.git", true},
		{"does not detect local paths", "/path/to/module", "", false},
		{"preserves query params", "git@github.com:repo.git?ref=main", "ssh://git@github.com/repo.git?ref=main", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, detected, err := detector.Detect(tt.src, "")
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if detected != tt.detected {
				t.Errorf("detected = %v, expected %v", detected, tt.detected)
			}
			if detected && result != tt.expectedURL {
				t.Errorf("result = %q, expected %q", result, tt.expectedURL)
			}
		})
	}
}

func TestExtractTaskOptionsFromSpec(t *testing.T) {
	t.Run("returns defaults when no taskOptions configured", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{}
		globalEnvFrom := []corev1.EnvFromSource{}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunInit, globalEnvFrom)

		if result.restartPolicy != corev1.RestartPolicyNever {
			t.Errorf("expected default restartPolicy to be Never, got %s", result.restartPolicy)
		}
		if len(result.env) != 0 {
			t.Errorf("expected empty env, got %d items", len(result.env))
		}
	})

	t.Run("collects options for matching task", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For:         []tfv1beta1.TaskName{tfv1beta1.RunInit},
						Labels:      map[string]string{"env": "test"},
						Annotations: map[string]string{"note": "init-task"},
						Env:         []corev1.EnvVar{{Name: "MY_VAR", Value: "my-value"}},
					},
				},
			},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunInit, nil)

		if result.labels["env"] != "test" {
			t.Error("expected label to be set for matching task")
		}
		if result.annotations["note"] != "init-task" {
			t.Error("expected annotation to be set for matching task")
		}
		if len(result.env) != 1 || result.env[0].Name != "MY_VAR" {
			t.Error("expected env var to be set for matching task")
		}
	})

	t.Run("collects options from wildcard (*)", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For:    []tfv1beta1.TaskName{"*"},
						Labels: map[string]string{"global": "true"},
					},
				},
			},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunPlan, nil)

		if result.labels["global"] != "true" {
			t.Error("expected wildcard options to apply to any task")
		}
	})

	t.Run("script configuration only applies to exact matches, not wildcards", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For: []tfv1beta1.TaskName{"*"},
						Script: tfv1beta1.StageScript{
							Source: "https://example.com/global.sh",
						},
					},
					{
						For: []tfv1beta1.TaskName{tfv1beta1.RunPreInit},
						Script: tfv1beta1.StageScript{
							Source: "https://example.com/preinit.sh",
						},
					},
				},
			},
		}

		// For RunPlan, the wildcard script should NOT apply
		planResult := extractTaskOptionsFromSpec(tf, tfv1beta1.RunPlan, nil)
		if planResult.urlSource != "" {
			t.Error("wildcard script source should not apply to plan task")
		}

		// For RunPreInit, the exact match script SHOULD apply
		preinitResult := extractTaskOptionsFromSpec(tf, tfv1beta1.RunPreInit, nil)
		if preinitResult.urlSource != "https://example.com/preinit.sh" {
			t.Errorf("expected exact match script source, got %s", preinitResult.urlSource)
		}
	})

	t.Run("sets inlineTaskExecutionFile when inline script provided", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For: []tfv1beta1.TaskName{tfv1beta1.RunPreApply},
						Script: tfv1beta1.StageScript{
							Inline: "#!/bin/bash\necho hello",
						},
					},
				},
			},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunPreApply, nil)

		if result.inlineTaskExecutionFile != "inline-preapply.sh" {
			t.Errorf("expected inline file name, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("sets configMap source when configMapSelector provided", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For: []tfv1beta1.TaskName{tfv1beta1.RunPostPlan},
						Script: tfv1beta1.StageScript{
							ConfigMapSelector: &tfv1beta1.ConfigMapSelector{
								Name: "my-scripts",
								Key:  "postplan.sh",
							},
						},
					},
				},
			},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunPostPlan, nil)

		if result.configMapSourceName != "my-scripts" {
			t.Errorf("expected configmap name, got %s", result.configMapSourceName)
		}
		if result.configMapSourceKey != "postplan.sh" {
			t.Errorf("expected configmap key, got %s", result.configMapSourceKey)
		}
	})

	t.Run("preserves globalEnvFrom", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{}
		globalEnvFrom := []corev1.EnvFromSource{
			{ConfigMapRef: &corev1.ConfigMapEnvSource{LocalObjectReference: corev1.LocalObjectReference{Name: "global-config"}}},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunInit, globalEnvFrom)

		if len(result.envFrom) != 1 || result.envFrom[0].ConfigMapRef.Name != "global-config" {
			t.Error("expected globalEnvFrom to be preserved")
		}
	})

	t.Run("collects policyRules", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				TaskOptions: []tfv1beta1.TaskOption{
					{
						For: []tfv1beta1.TaskName{tfv1beta1.RunApply},
						PolicyRules: []rbacv1.PolicyRule{
							{APIGroups: []string{""}, Resources: []string{"secrets"}, Verbs: []string{"get"}},
						},
					},
				},
			},
		}

		result := extractTaskOptionsFromSpec(tf, tfv1beta1.RunApply, nil)

		if len(result.policyRules) != 1 {
			t.Errorf("expected 1 policy rule, got %d", len(result.policyRules))
		}
	})
}

func TestResolveImages(t *testing.T) {
	t.Run("returns defaults when spec is nil", func(t *testing.T) {
		result := resolveImages(nil, "1.5.0")

		if result.Tofu == nil || result.Setup == nil || result.Script == nil {
			t.Fatal("expected all image configs to be non-nil")
		}
		if result.Tofu.Image != tfv1beta1.TerraformTaskImageRepoDefault+":1.5.0" {
			t.Errorf("unexpected terraform image: %s", result.Tofu.Image)
		}
	})

	t.Run("uses terraform version as tag", func(t *testing.T) {
		result := resolveImages(nil, "1.3.7")

		if result.Tofu.Image != tfv1beta1.TerraformTaskImageRepoDefault+":1.3.7" {
			t.Errorf("expected version tag, got %s", result.Tofu.Image)
		}
	})

	t.Run("replaces existing tag with terraform version", func(t *testing.T) {
		spec := &tfv1beta1.Images{
			Tofu: &tfv1beta1.ImageConfig{
				Image: "custom-registry.io/terraform:old-tag",
			},
		}

		result := resolveImages(spec, "1.6.0")

		if result.Tofu.Image != "custom-registry.io/terraform:1.6.0" {
			t.Errorf("expected tag replacement, got %s", result.Tofu.Image)
		}
	})

	t.Run("handles image without tag", func(t *testing.T) {
		spec := &tfv1beta1.Images{
			Tofu: &tfv1beta1.ImageConfig{
				Image: "my-terraform",
			},
		}

		result := resolveImages(spec, "1.4.0")

		if result.Tofu.Image != "my-terraform:1.4.0" {
			t.Errorf("expected tag to be appended, got %s", result.Tofu.Image)
		}
	})

	t.Run("sets default setup image", func(t *testing.T) {
		result := resolveImages(nil, "latest")

		expected := tfv1beta1.SetupTaskImageRepoDefault + ":" + tfv1beta1.SetupTaskImageTagDefault
		if result.Setup.Image != expected {
			t.Errorf("expected setup image %s, got %s", expected, result.Setup.Image)
		}
	})

	t.Run("sets default script image", func(t *testing.T) {
		result := resolveImages(nil, "latest")

		expected := tfv1beta1.ScriptTaskImageRepoDefault + ":" + tfv1beta1.ScriptTaskImageTagDefault
		if result.Script.Image != expected {
			t.Errorf("expected script image %s, got %s", expected, result.Script.Image)
		}
	})

	t.Run("preserves custom setup and script images", func(t *testing.T) {
		spec := &tfv1beta1.Images{
			Setup: &tfv1beta1.ImageConfig{
				Image: "custom-setup:v1",
			},
			Script: &tfv1beta1.ImageConfig{
				Image: "custom-script:v2",
			},
		}

		result := resolveImages(spec, "1.5.0")

		if result.Setup.Image != "custom-setup:v1" {
			t.Errorf("expected custom setup image, got %s", result.Setup.Image)
		}
		if result.Script.Image != "custom-script:v2" {
			t.Errorf("expected custom script image, got %s", result.Script.Image)
		}
	})
}

func TestResolveTaskImage(t *testing.T) {
	images := resolveImages(nil, "1.5.0")

	t.Run("uses terraform image for terraform tasks", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunInit, images, "", "", "", "")

		if result.image != images.Tofu.Image {
			t.Errorf("expected terraform image, got %s", result.image)
		}
		if result.inlineTaskExecutionFile != "default-terraform.sh" {
			t.Errorf("expected default terraform script, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("uses script image for script tasks", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunPreInit, images, "", "", "", "")

		if result.image != images.Script.Image {
			t.Errorf("expected script image, got %s", result.image)
		}
		if result.inlineTaskExecutionFile != "default-noop.sh" {
			t.Errorf("expected default noop script, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("uses setup image for setup tasks", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunSetup, images, "", "", "", "")

		if result.image != images.Setup.Image {
			t.Errorf("expected setup image, got %s", result.image)
		}
		if result.inlineTaskExecutionFile != "default-setup.sh" {
			t.Errorf("expected default setup script, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("uses custom inline file when specified", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunInit, images, "custom-script.sh", "", "", "")

		if result.inlineTaskExecutionFile != "custom-script.sh" {
			t.Errorf("expected custom script, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("does not override with default when urlSource provided", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunInit, images, "", "https://example.com/script.sh", "", "")

		if result.inlineTaskExecutionFile != "" {
			t.Errorf("expected empty inline file when URL source provided, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("does not override with default when configMap provided", func(t *testing.T) {
		result := resolveTaskImage(tfv1beta1.RunInit, images, "", "", "my-configmap", "script.sh")

		if result.inlineTaskExecutionFile != "" {
			t.Errorf("expected empty inline file when configMap provided, got %s", result.inlineTaskExecutionFile)
		}
	})

	t.Run("uses default when only partial configMap info provided", func(t *testing.T) {
		// Only name without key should still use default
		result := resolveTaskImage(tfv1beta1.RunInit, images, "", "", "my-configmap", "")

		if result.inlineTaskExecutionFile != "default-terraform.sh" {
			t.Errorf("expected default script when configMap incomplete, got %s", result.inlineTaskExecutionFile)
		}
	})
}

func TestResolveOutputsConfig(t *testing.T) {
	t.Run("uses default outputs secret name when not specified", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{}

		result := resolveOutputsConfig(tf, "my-resource-abc123-v1")

		if result.secretName != "my-resource-abc123-v1-outputs" {
			t.Errorf("expected default secret name, got %s", result.secretName)
		}
		if result.saveOutputs {
			t.Error("expected saveOutputs to be false by default")
		}
	})

	t.Run("uses custom outputs secret name when specified", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				OutputsSecret: "my-custom-outputs",
			},
		}

		result := resolveOutputsConfig(tf, "my-resource-abc123-v1")

		if result.secretName != "my-custom-outputs" {
			t.Errorf("expected custom secret name, got %s", result.secretName)
		}
		if !result.saveOutputs {
			t.Error("expected saveOutputs to be true when OutputsSecret specified")
		}
		if !result.stripGenerationLabelOnSecret {
			t.Error("expected stripGenerationLabelOnSecret to be true when OutputsSecret specified")
		}
	})

	t.Run("saves outputs when WriteOutputsToStatus is true", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				WriteOutputsToStatus: true,
			},
		}

		result := resolveOutputsConfig(tf, "my-resource-abc123-v1")

		if !result.saveOutputs {
			t.Error("expected saveOutputs to be true when WriteOutputsToStatus is true")
		}
		if result.stripGenerationLabelOnSecret {
			t.Error("expected stripGenerationLabelOnSecret to be false when only WriteOutputsToStatus is set")
		}
	})

	t.Run("includes outputsToInclude and outputsToOmit", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Spec: tfv1beta1.TofuSpec{
				OutputsToInclude: []string{"output1", "output2"},
				OutputsToOmit:    []string{"sensitive_output"},
			},
		}

		result := resolveOutputsConfig(tf, "my-resource-abc123-v1")

		if len(result.outputsToInclude) != 2 {
			t.Errorf("expected 2 outputs to include, got %d", len(result.outputsToInclude))
		}
		if len(result.outputsToOmit) != 1 {
			t.Errorf("expected 1 output to omit, got %d", len(result.outputsToOmit))
		}
	})
}

func TestBuildResourceLabels(t *testing.T) {
	t.Run("includes standard labels", func(t *testing.T) {
		labels := buildResourceLabels(5, "my-terraform", "my-terraform-abc123", "1.5.0", false)

		if labels["tofus.tf.defn.dev/generation"] != "5" {
			t.Error("expected generation label")
		}
		if labels["tofus.tf.defn.dev/podPrefix"] != "my-terraform-abc123" {
			t.Error("expected podPrefix label")
		}
		if labels["tofus.tf.defn.dev/terraformVersion"] != "1.5.0" {
			t.Error("expected terraformVersion label")
		}
		if labels["app.kubernetes.io/name"] != "terraform-operator" {
			t.Error("expected app name label")
		}
		if labels["app.kubernetes.io/component"] != "terraform-operator-runner" {
			t.Error("expected component label")
		}
		if labels["app.kubernetes.io/created-by"] != "controller" {
			t.Error("expected created-by label")
		}
	})

	t.Run("adds isPlugin label when isPlugin is true", func(t *testing.T) {
		labels := buildResourceLabels(1, "my-terraform", "my-terraform-abc123", "1.5.0", true)

		if labels["tofus.tf.defn.dev/isPlugin"] != "true" {
			t.Error("expected isPlugin label to be true")
		}
	})

	t.Run("does not add isPlugin label when isPlugin is false", func(t *testing.T) {
		labels := buildResourceLabels(1, "my-terraform", "my-terraform-abc123", "1.5.0", false)

		if _, exists := labels["tofus.tf.defn.dev/isPlugin"]; exists {
			t.Error("expected isPlugin label to not exist")
		}
	})
}

func TestCheckDeletionTimestamp(t *testing.T) {
	t.Run("sets phase to InitDelete when deletion timestamp is set", func(t *testing.T) {
		now := metav1.Now()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				DeletionTimestamp: &now,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
			},
		}

		checkDeletionTimestamp(tf)

		if tf.Status.Phase != tfv1beta1.PhaseInitDelete {
			t.Errorf("expected phase %s, got %s", tfv1beta1.PhaseInitDelete, tf.Status.Phase)
		}
	})

	t.Run("does not change phase when already in delete phase", func(t *testing.T) {
		now := metav1.Now()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				DeletionTimestamp: &now,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseDeleting,
			},
		}

		checkDeletionTimestamp(tf)

		if tf.Status.Phase != tfv1beta1.PhaseDeleting {
			t.Errorf("expected phase to remain %s, got %s", tfv1beta1.PhaseDeleting, tf.Status.Phase)
		}
	})

	t.Run("does not change phase when deletion timestamp is nil", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
			},
		}

		checkDeletionTimestamp(tf)

		if tf.Status.Phase != tfv1beta1.PhaseRunning {
			t.Errorf("expected phase to remain %s, got %s", tfv1beta1.PhaseRunning, tf.Status.Phase)
		}
	})

	t.Run("does not change phase when in InitDelete phase", func(t *testing.T) {
		now := metav1.Now()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				DeletionTimestamp: &now,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseInitDelete,
			},
		}

		checkDeletionTimestamp(tf)

		if tf.Status.Phase != tfv1beta1.PhaseInitDelete {
			t.Errorf("expected phase to remain %s, got %s", tfv1beta1.PhaseInitDelete, tf.Status.Phase)
		}
	})

	t.Run("does not change phase when in Deleted phase", func(t *testing.T) {
		now := metav1.Now()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				DeletionTimestamp: &now,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseDeleted,
			},
		}

		checkDeletionTimestamp(tf)

		if tf.Status.Phase != tfv1beta1.PhaseDeleted {
			t.Errorf("expected phase to remain %s, got %s", tfv1beta1.PhaseDeleted, tf.Status.Phase)
		}
	})
}

func TestCheckRetryLabel(t *testing.T) {
	t.Run("returns false when labels are nil", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{}

		result := checkRetryLabel(tf)

		if result {
			t.Error("expected false when labels are nil")
		}
	})

	t.Run("returns false when change-cause label is not present", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"other-label": "value",
				},
			},
		}

		result := checkRetryLabel(tf)

		if result {
			t.Error("expected false when change-cause label is not present")
		}
	})

	t.Run("returns true and updates status on first retry", func(t *testing.T) {
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"kubernetes.io/change-cause": "retry-1",
				},
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseCompleted,
			},
		}

		result := checkRetryLabel(tf)

		if !result {
			t.Error("expected true on first retry")
		}
		if tf.Status.RetryEventReason == nil || *tf.Status.RetryEventReason != "retry-1" {
			t.Error("expected RetryEventReason to be set")
		}
		if tf.Status.RetryTimestamp == nil {
			t.Error("expected RetryTimestamp to be set")
		}
		if tf.Status.Phase != tfv1beta1.PhaseInitializing {
			t.Errorf("expected phase %s, got %s", tfv1beta1.PhaseInitializing, tf.Status.Phase)
		}
	})

	t.Run("returns true when change-cause differs from previous retry", func(t *testing.T) {
		previousReason := "retry-1"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"kubernetes.io/change-cause": "retry-2",
				},
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseCompleted,
				RetryEventReason: &previousReason,
			},
		}

		result := checkRetryLabel(tf)

		if !result {
			t.Error("expected true when change-cause differs")
		}
		if tf.Status.RetryEventReason == nil || *tf.Status.RetryEventReason != "retry-2" {
			t.Error("expected RetryEventReason to be updated")
		}
	})

	t.Run("returns false when change-cause matches previous retry", func(t *testing.T) {
		previousReason := "retry-1"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"kubernetes.io/change-cause": "retry-1",
				},
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseCompleted,
				RetryEventReason: &previousReason,
			},
		}

		result := checkRetryLabel(tf)

		if result {
			t.Error("expected false when change-cause matches previous retry")
		}
	})
}

func TestCheckSetNewStage(t *testing.T) {
	// Helper to create a fake reconciler
	newTestReconciler := func() *ReconcileTofu {
		scheme := runtime.NewScheme()
		_ = corev1.AddToScheme(scheme)
		_ = tfv1beta1.AddToScheme(scheme)
		fakeClient := fake.NewClientBuilder().WithScheme(scheme).Build()
		return &ReconcileTofu{
			Client: fakeClient,
		}
	}

	t.Run("returns nil when current stage cannot be interrupted and is running", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateInProgress,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result != nil {
			t.Error("expected nil when stage cannot be interrupted and is running")
		}
	})

	t.Run("allows transition when stage is interruptible even if running", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 2, // New generation
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunSetup,
					State:         tfv1beta1.StateInProgress,
					Interruptible: tfv1beta1.CanBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result == nil {
			t.Fatal("expected new stage when generation changes and stage is interruptible")
		}
		if result.TaskType != tfv1beta1.RunSetup {
			t.Errorf("expected RunSetup, got %s", result.TaskType)
		}
		if result.Reason != "GENERATION_CHANGE" {
			t.Errorf("expected reason GENERATION_CHANGE, got %s", result.Reason)
		}
	})

	t.Run("starts delete workflow when resource is marked for deletion", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 2,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseInitDelete,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result == nil {
			t.Fatal("expected new stage for delete workflow")
		}
		if result.TaskType != tfv1beta1.RunSetupDelete {
			t.Errorf("expected RunSetupDelete, got %s", result.TaskType)
		}
		if result.Reason != "TF_RESOURCE_DELETED" {
			t.Errorf("expected reason TF_RESOURCE_DELETED, got %s", result.Reason)
		}
	})

	t.Run("transitions to next task when current stage completes", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunInit,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result == nil {
			t.Fatal("expected new stage after completion")
		}
		if result.TaskType != tfv1beta1.RunPlan {
			t.Errorf("expected RunPlan after RunInit, got %s", result.TaskType)
		}
	})

	t.Run("returns nil when workflow is complete (RunNil)", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunNil,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result != nil {
			t.Error("expected nil when task is RunNil")
		}
	})

	t.Run("retry triggers init task with retry reason", func(t *testing.T) {
		r := newTestReconciler()
		retryReason := "manual-retry"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseRunning,
				RetryEventReason: &retryReason,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, true)

		if result == nil {
			t.Fatal("expected new stage on retry")
		}
		if result.TaskType != tfv1beta1.RunInit {
			t.Errorf("expected RunInit on retry, got %s", result.TaskType)
		}
		if result.Reason != "manual-retry" {
			t.Errorf("expected reason from RetryEventReason, got %s", result.Reason)
		}
	})

	t.Run("retry with .setup suffix triggers setup task", func(t *testing.T) {
		r := newTestReconciler()
		retryReason := "force.setup"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseRunning,
				RetryEventReason: &retryReason,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, true)

		if result == nil {
			t.Fatal("expected new stage on retry")
		}
		if result.TaskType != tfv1beta1.RunSetup {
			t.Errorf("expected RunSetup on retry with .setup suffix, got %s", result.TaskType)
		}
	})

	t.Run("retry during delete workflow triggers init-delete", func(t *testing.T) {
		r := newTestReconciler()
		retryReason := "retry-delete"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseDeleting,
				RetryEventReason: &retryReason,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApplyDelete,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, true)

		if result == nil {
			t.Fatal("expected new stage on retry during delete")
		}
		if result.TaskType != tfv1beta1.RunInitDelete {
			t.Errorf("expected RunInitDelete on retry during delete, got %s", result.TaskType)
		}
	})

	t.Run("new generation takes precedence over retry", func(t *testing.T) {
		r := newTestReconciler()
		retryReason := "manual-retry"
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 2, // New generation
			},
			Status: tfv1beta1.TofuStatus{
				Phase:            tfv1beta1.PhaseRunning,
				RetryEventReason: &retryReason,
				Stage: tfv1beta1.Stage{
					Generation:    1, // Old generation
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, true)

		if result == nil {
			t.Fatal("expected new stage")
		}
		// New generation should trigger GENERATION_CHANGE, not retry
		if result.Reason != "GENERATION_CHANGE" {
			t.Errorf("expected GENERATION_CHANGE to take precedence over retry, got %s", result.Reason)
		}
		if result.TaskType != tfv1beta1.RunSetup {
			t.Errorf("expected RunSetup for new generation, got %s", result.TaskType)
		}
	})

	t.Run("failed non-apply stage returns nil (no auto-restart)", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunPlan, // Not apply
					State:         tfv1beta1.StateFailed,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result != nil {
			t.Error("expected nil for failed non-apply stage")
		}
	})

	t.Run("completes workflow after final task", func(t *testing.T) {
		r := newTestReconciler()
		tf := &tfv1beta1.Tofu{
			ObjectMeta: metav1.ObjectMeta{
				Generation: 1,
			},
			Status: tfv1beta1.TofuStatus{
				Phase: tfv1beta1.PhaseRunning,
				Stage: tfv1beta1.Stage{
					Generation:    1,
					TaskType:      tfv1beta1.RunApply,
					State:         tfv1beta1.StateComplete,
					Interruptible: tfv1beta1.CanNotBeInterrupt,
				},
			},
		}

		result := r.checkSetNewStage(context.Background(), tf, false)

		if result == nil {
			t.Fatal("expected final stage")
		}
		if result.TaskType != tfv1beta1.RunNil {
			t.Errorf("expected RunNil after RunApply, got %s", result.TaskType)
		}
		if result.State != tfv1beta1.StateComplete {
			t.Errorf("expected StateComplete for final stage, got %s", result.State)
		}
	})
}
