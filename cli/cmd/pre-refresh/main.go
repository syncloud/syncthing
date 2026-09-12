package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
	"hooks/installer"
	"hooks/log"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:          "pre-refresh",
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			logger := log.Logger(zap.DebugLevel)
			return installer.New(logger).PreRefresh()
		},
	}

	if err := rootCmd.Execute(); err != nil {
		fmt.Print(err)
		os.Exit(1)
	}
}
