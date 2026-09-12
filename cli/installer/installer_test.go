package installer

import (
	"os"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/syncloud/golib/config"
)

func TestDefaultConfigLandsInHomeDir(t *testing.T) {
	appDir := t.TempDir()
	dataDir := t.TempDir()
	configDir := path.Join(dataDir, "config")

	defaults := path.Join(appDir, "config-default", App)
	assert.NoError(t, os.MkdirAll(defaults, 0755))
	assert.NoError(t, os.WriteFile(path.Join(defaults, "config.xml"), []byte("socket {{ .GuiSocket }}"), 0644))

	err := config.Generate(
		path.Join(appDir, "config-default"),
		configDir,
		Variables{GuiSocket: "/var/snap/syncthing/current/gui.sock"},
	)
	assert.NoError(t, err)

	body, err := os.ReadFile(path.Join(configDir, App, "config.xml"))
	assert.NoError(t, err)
	assert.Equal(t, "socket /var/snap/syncthing/current/gui.sock", string(body))
}

func TestInitHomeKeepsExistingConfig(t *testing.T) {
	dataDir := t.TempDir()
	i := &Installer{
		appDir:    t.TempDir(),
		dataDir:   dataDir,
		configDir: path.Join(dataDir, "config"),
		homeDir:   path.Join(dataDir, "config", App),
		logger:    testLogger(),
	}
	assert.NoError(t, os.MkdirAll(i.homeDir, 0755))

	existing := path.Join(i.homeDir, "config.xml")
	assert.NoError(t, os.WriteFile(existing, []byte("user config"), 0644))

	assert.NoError(t, i.InitHome())

	body, err := os.ReadFile(existing)
	assert.NoError(t, err)
	assert.Equal(t, "user config", string(body))
}
