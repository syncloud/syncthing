package installer

import (
	"fmt"
	"os"
	"path"

	cp "github.com/otiai10/copy"
	"github.com/syncloud/golib/config"
	"github.com/syncloud/golib/linux"
	"github.com/syncloud/golib/platform"
	"go.uber.org/zap"
)

const (
	App           = "syncthing"
	SyncthingPort = 1085
)

type Variables struct {
	App           string
	AppDir        string
	DataDir       string
	CommonDir     string
	SyncthingPort int
}

type Installer struct {
	newVersionFile     string
	currentVersionFile string
	installFile        string
	appDir             string
	dataDir            string
	commonDir          string
	configDir          string
	homeDir            string
	platformClient     *platform.Client
	logger             *zap.Logger
}

func New(logger *zap.Logger) *Installer {
	appDir := fmt.Sprintf("/snap/%s/current", App)
	dataDir := fmt.Sprintf("/var/snap/%s/current", App)
	commonDir := fmt.Sprintf("/var/snap/%s/common", App)
	configDir := path.Join(dataDir, "config")

	return &Installer{
		newVersionFile:     path.Join(appDir, "version"),
		currentVersionFile: path.Join(dataDir, "version"),
		installFile:        path.Join(dataDir, "installed"),
		appDir:             appDir,
		dataDir:            dataDir,
		commonDir:          commonDir,
		configDir:          configDir,
		homeDir:            path.Join(configDir, App),
		platformClient:     platform.New(),
		logger:             logger,
	}
}

func (i *Installer) Install() error {
	if err := linux.CreateUser(App); err != nil {
		return err
	}
	if err := i.UpdateConfigs(); err != nil {
		return err
	}
	if err := i.InitHome(); err != nil {
		return err
	}
	if err := i.StorageChange(); err != nil {
		return err
	}
	return i.FixPermissions()
}

func (i *Installer) Configure() error {
	if i.IsInstalled() {
		if err := i.Upgrade(); err != nil {
			return err
		}
	} else {
		if err := i.Initialize(); err != nil {
			return err
		}
	}
	if err := i.FixPermissions(); err != nil {
		return err
	}
	return i.UpdateVersion()
}

func (i *Installer) Initialize() error {
	if err := i.StorageChange(); err != nil {
		return err
	}
	return os.WriteFile(i.installFile, []byte("installed"), 0644)
}

func (i *Installer) Upgrade() error {
	return i.StorageChange()
}

func (i *Installer) IsInstalled() bool {
	_, err := os.Stat(i.installFile)
	return err == nil
}

func (i *Installer) PreRefresh() error {
	return nil
}

func (i *Installer) PostRefresh() error {
	if err := i.MigrateCommonHome(); err != nil {
		return err
	}
	if err := i.UpdateConfigs(); err != nil {
		return err
	}
	if err := i.InitHome(); err != nil {
		return err
	}
	if err := i.ClearVersion(); err != nil {
		return err
	}
	return i.FixPermissions()
}

func (i *Installer) MigrateCommonHome() error {
	oldConfig := path.Join(i.commonDir, "config")

	if _, err := os.Stat(i.configDir); err == nil {
		return nil
	}
	if _, err := os.Stat(oldConfig); os.IsNotExist(err) {
		return nil
	}

	i.logger.Info("migrating config", zap.String("from", oldConfig), zap.String("to", i.configDir))
	return cp.Copy(oldConfig, i.configDir)
}

func (i *Installer) StorageChange() error {
	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}
	return linux.Chown(storageDir, App)
}

func (i *Installer) ClearVersion() error {
	return os.RemoveAll(i.currentVersionFile)
}

func (i *Installer) UpdateVersion() error {
	return cp.Copy(i.newVersionFile, i.currentVersionFile)
}

func (i *Installer) UpdateConfigs() error {
	err := linux.CreateMissingDirs(
		i.configDir,
		path.Join(i.dataDir, "nginx"),
	)
	if err != nil {
		return err
	}

	return config.Generate(path.Join(i.appDir, "config"), i.configDir, i.variables())
}

func (i *Installer) InitHome() error {
	configFile := path.Join(i.homeDir, "config.xml")
	if _, err := os.Stat(configFile); err == nil {
		i.logger.Info("keeping existing syncthing config", zap.String("file", configFile))
		return nil
	}

	if err := linux.CreateMissingDirs(i.homeDir); err != nil {
		return err
	}

	i.logger.Info("generating syncthing config", zap.String("file", configFile))
	return config.Generate(path.Join(i.appDir, "config-default"), i.configDir, i.variables())
}

func (i *Installer) variables() Variables {
	return Variables{
		App:           App,
		AppDir:        i.appDir,
		DataDir:       i.dataDir,
		CommonDir:     i.commonDir,
		SyncthingPort: SyncthingPort,
	}
}

func (i *Installer) BackupPreStop() error {
	return i.PreRefresh()
}

func (i *Installer) RestorePreStart() error {
	return i.PostRefresh()
}

func (i *Installer) RestorePostStart() error {
	return i.Configure()
}

func (i *Installer) AccessChange() error {
	return i.UpdateConfigs()
}

func (i *Installer) FixPermissions() error {
	if err := linux.Chown(i.dataDir, App); err != nil {
		return err
	}
	return linux.Chown(i.commonDir, App)
}
