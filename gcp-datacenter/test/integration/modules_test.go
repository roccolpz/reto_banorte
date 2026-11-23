package integration

import (
	"net"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Una prueba por módulo con examples/. Cada una usa su fixture en test/fixtures/<módulo>.

func TestCloudSQL(t *testing.T) {
	t.Parallel()
	opts := options(t, "cloud-sql", nil)
	applyIdempotent(t, opts)

	assert.NotEmpty(t, terraform.Output(t, opts, "instance_name"))
	_, psa, err := net.ParseCIDR(terraform.Output(t, opts, "psa_cidr"))
	require.NoError(t, err)
	ip := net.ParseIP(terraform.Output(t, opts, "private_ip_address"))
	require.NotNil(t, ip, "la instancia debe tener IP privada")
	assert.True(t, psa.Contains(ip), "la IP privada %s debe estar en el rango de PSA %s", ip, psa)
}

func TestComputeMIG(t *testing.T) {
	t.Parallel()
	opts := options(t, "compute-mig", nil)
	applyIdempotent(t, opts)

	assert.Contains(t, terraform.Output(t, opts, "mig_name"), "tt-mig-")
}

func TestFirewall(t *testing.T) {
	t.Parallel()
	opts := options(t, "firewall", nil)
	applyIdempotent(t, opts)

	assert.Len(t, terraform.OutputMap(t, opts, "rule_names"), 2)
	tags := terraform.OutputMap(t, opts, "secure_tag_values")
	for _, k := range []string{"gke-nodes", "vm"} {
		assert.Contains(t, tags[k], "tagValues/", k)
	}
}

func TestGKE(t *testing.T) {
	t.Parallel()
	opts := options(t, "gke", nil)
	applyIdempotent(t, opts)

	assert.NotEmpty(t, terraform.Output(t, opts, "cluster_name"))
	project := opts.Vars["project_id"].(string)
	assert.Equal(t, project+".svc.id.goog", terraform.Output(t, opts, "workload_pool"))
}

func TestHybridConnectivity(t *testing.T) {
	t.Parallel()
	opts := options(t, "hybrid-connectivity", nil)
	applyIdempotent(t, opts)

	// HA VPN: dos túneles por lado.
	assert.Len(t, terraform.OutputList(t, opts, "tunnel_self_links"), 2)
	assert.Len(t, terraform.OutputList(t, opts, "peer_tunnel_self_links"), 2)
}

func TestKMS(t *testing.T) {
	t.Parallel()
	opts := options(t, "kms", nil)
	applyIdempotent(t, opts)

	keys := terraform.OutputMap(t, opts, "key_ids")
	assert.Contains(t, keys, "test")
}

func TestNetworkHub(t *testing.T) {
	t.Parallel()
	opts := options(t, "network-hub", nil)
	applyIdempotent(t, opts)

	assert.True(t, strings.HasPrefix(terraform.Output(t, opts, "network_name"), "tt"))
	assert.NotEmpty(t, terraform.Output(t, opts, "ncc_hub_id"))
}

func TestNetworkSpoke(t *testing.T) {
	t.Parallel()
	opts := options(t, "network-spoke", nil)
	applyIdempotent(t, opts)

	assert.NotEmpty(t, terraform.Output(t, opts, "network_name"))
	assert.NotEmpty(t, terraform.OutputMapOfObjects(t, opts, "subnets"))
}

func TestObservability(t *testing.T) {
	t.Parallel()
	opts := options(t, "observability", nil)
	applyIdempotent(t, opts)

	assert.NotEmpty(t, terraform.Output(t, opts, "notification_channel_id"))
}

// Crea un proyecto real: necesita un folder y una cuenta de facturación de pruebas.
func TestProjectFactory(t *testing.T) {
	t.Parallel()
	env := requireEnv(t, "TEST_FOLDER_ID", "TEST_BILLING_ACCOUNT")
	opts := options(t, "project-factory", map[string]interface{}{
		"folder_id":       env[0],
		"billing_account": env[1],
	})
	applyIdempotent(t, opts)

	assert.Equal(t, "tt-pf-"+opts.Vars["suffix"].(string), terraform.Output(t, opts, "project_id"))
}

// El perímetro vive en la política de acceso de la organización: necesita una política de pruebas.
func TestVPCSC(t *testing.T) {
	t.Parallel()
	policy := requireEnv(t, "TEST_ACCESS_POLICY")[0]
	opts := options(t, "vpc-sc", map[string]interface{}{"access_policy_name": policy})
	applyIdempotent(t, opts)

	assert.Contains(t, terraform.Output(t, opts, "name"), "tt_")
	assert.Equal(t, "false", terraform.Output(t, opts, "enforced"))
}

func TestStorage(t *testing.T) {
	t.Parallel()
	opts := options(t, "storage", nil)
	applyIdempotent(t, opts)

	want := opts.Vars["project_id"].(string) + "-tt-" + opts.Vars["suffix"].(string)
	assert.Equal(t, want, terraform.Output(t, opts, "bucket_name"))
}
