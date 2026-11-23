// Package integration aplica cada módulo de gcp-datacenter/modules en un proyecto efímero, comprueba
// que un segundo plan no tenga cambios (InitAndApplyAndIdempotent) y lo destruye.
//
// Lo corre .github/workflows/terratest.yml (nocturno y manual). En local, sin TEST_PROJECT_ID,
// todas las pruebas se omiten: `go test -run XXX ./...` solo compila.
// Runbook: gcp-datacenter/docs/runbooks/terratest.md.
package integration

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// requireEnv omite la prueba si falta alguna variable de entorno y devuelve sus valores en orden.
func requireEnv(t *testing.T, names ...string) []string {
	t.Helper()
	values := make([]string, len(names))
	for i, n := range names {
		values[i] = os.Getenv(n)
		if values[i] == "" {
			t.Skipf("falta %s: prueba de integración omitida", n)
		}
	}
	return values
}

// options arma las opciones de Terraform para test/fixtures/<fixture> con project_id, suffix y región.
// extra agrega variables propias del fixture.
func options(t *testing.T, fixture string, extra map[string]interface{}) *terraform.Options {
	t.Helper()
	project := requireEnv(t, "TEST_PROJECT_ID")[0]
	region := os.Getenv("TEST_REGION")
	if region == "" {
		region = "us-central1"
	}
	vars := map[string]interface{}{
		"project_id": project,
		// Minúsculas: los nombres de GCP no aceptan mayúsculas.
		"suffix": strings.ToLower(random.UniqueId()),
		"region": region,
	}
	for k, v := range extra {
		vars[k] = v
	}
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join("..", "fixtures", fixture),
		Vars:         vars,
		NoColor:      true,
	})
}

// applyIdempotent aplica el fixture, exige un segundo plan sin cambios y registra el destroy.
func applyIdempotent(t *testing.T, opts *terraform.Options) {
	t.Helper()
	t.Cleanup(func() { terraform.Destroy(t, opts) })
	terraform.InitAndApplyAndIdempotent(t, opts)
}
