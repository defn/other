package seed

import (
	"context"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	genseed "github.com/defn/other/m/tenant/library/go/lib/gen/seed"
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
	return genseed.Run(genCtx)
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
