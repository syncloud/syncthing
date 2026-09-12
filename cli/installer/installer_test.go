package installer

import (
	"os"
	"path"
	"testing"

	"github.com/syncloud/golib/config"
)

func TestDefaultConfigLandsInHomeDir(t *testing.T) {
	appDir := t.TempDir()
	dataDir := t.TempDir()
	configDir := path.Join(dataDir, "config")

	defaults := path.Join(appDir, "config-default", App)
	if err := os.MkdirAll(defaults, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path.Join(defaults, "config.xml"), []byte("port {{ .SyncthingPort }}"), 0644); err != nil {
		t.Fatal(err)
	}

	err := config.Generate(path.Join(appDir, "config-default"), configDir, Variables{SyncthingPort: SyncthingPort})
	if err != nil {
		t.Fatal(err)
	}

	generated := path.Join(configDir, App, "config.xml")
	body, err := os.ReadFile(generated)
	if err != nil {
		t.Fatalf("expected %s: %v", generated, err)
	}
	if string(body) != "port 1085" {
		t.Fatalf("got %q", body)
	}
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
	if err := os.MkdirAll(i.homeDir, 0755); err != nil {
		t.Fatal(err)
	}
	existing := path.Join(i.homeDir, "config.xml")
	if err := os.WriteFile(existing, []byte("user config"), 0644); err != nil {
		t.Fatal(err)
	}

	if err := i.InitHome(); err != nil {
		t.Fatal(err)
	}

	body, err := os.ReadFile(existing)
	if err != nil {
		t.Fatal(err)
	}
	if string(body) != "user config" {
		t.Fatalf("existing config was overwritten: %q", body)
	}
}

func TestMigrateCommonHomeSkipsWhenDataConfigExists(t *testing.T) {
	dataDir := t.TempDir()
	commonDir := t.TempDir()
	configDir := path.Join(dataDir, "config")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(path.Join(commonDir, "config"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path.Join(commonDir, "config", "config.xml"), []byte("old"), 0644); err != nil {
		t.Fatal(err)
	}

	i := &Installer{dataDir: dataDir, commonDir: commonDir, configDir: configDir, logger: testLogger()}
	if err := i.MigrateCommonHome(); err != nil {
		t.Fatal(err)
	}

	if _, err := os.Stat(path.Join(configDir, "config.xml")); !os.IsNotExist(err) {
		t.Fatal("common config should not have been copied over an existing data config")
	}
}

func TestMigrateCommonHomeCopiesLegacyLayout(t *testing.T) {
	dataDir := t.TempDir()
	commonDir := t.TempDir()
	configDir := path.Join(dataDir, "config")
	legacy := path.Join(commonDir, "config", App)
	if err := os.MkdirAll(legacy, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path.Join(legacy, "config.xml"), []byte("legacy"), 0644); err != nil {
		t.Fatal(err)
	}

	i := &Installer{dataDir: dataDir, commonDir: commonDir, configDir: configDir, logger: testLogger()}
	if err := i.MigrateCommonHome(); err != nil {
		t.Fatal(err)
	}

	body, err := os.ReadFile(path.Join(configDir, App, "config.xml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(body) != "legacy" {
		t.Fatalf("got %q", body)
	}
}
