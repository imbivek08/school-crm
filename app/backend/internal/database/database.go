package database

import (
	"context"
	"fmt"
	"time"

	"github.com/imbivek08/school-crm/internal/config"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Databse struct {
	Pool *pgxpool.Pool
}

func New(cfg *config.Config) (*Databse, error) {
	dsn, err := cfg.BuildDSN(cfg)
	if err != nil {
		return nil, fmt.Errorf("Faild to buidl DSN:%w", err)
	}
	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to parse the pool config:%w", err)
	}
	poolConfig.MaxConns = int32(cfg.MaxOpenConn)
	poolConfig.MinConns = int32(cfg.MaxIdleConn)
	poolConfig.MaxConnLifetime = time.Hour
	poolConfig.MaxConnIdleTime = time.Minute * 30

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create the connection pool:%w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping the database:%w", err)
	}
	return &Databse{
		Pool: pool,
	}, nil
}

func (db *Databse) Close() {
	if db.Pool != nil {
		db.Pool.Close()
	}
}
