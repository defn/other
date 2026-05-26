package k3d

import (
	"context"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	genk3d "github.com/defn/other/m/tenant/library/go/lib/gen/k3d"
	"github.com/spf13/cobra"
)

type Config struct{}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)
	genCtx, err := gen.NewContext(".", nil)
	if err != nil {
		return err
	}
	return genk3d.Run(genCtx)
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
