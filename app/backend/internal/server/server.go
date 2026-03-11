package server

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/imbivek08/school-crm/internal/config"
	"github.com/imbivek08/school-crm/internal/database"
	"github.com/imbivek08/school-crm/internal/router"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

type Server struct {
	echo   *echo.Echo
	db     *database.Databse
	config *config.Config
}

func NewServer(cfg *config.Config, db *database.Databse) *Server {
	return &Server{
		echo:   echo.New(),
		db:     db,
		config: cfg,
	}
}

func (s *Server) Start() error {
	s.echo.HideBanner = true
	s.echo.HidePort = true
	// s.echo.Validator = NewValidator()
	s.setupMiddleware()
	router.SetupRoutes(s.echo, s.db, s.config)

	//start server with graceful shutdown
	return s.StartWithGracefulShutdown()
}

func (s *Server) setupMiddleware() {
	// Logger middleware
	s.echo.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogStatus: true,
		LogURI:    true,
	}))

	// Recover middleware
	s.echo.Use(middleware.Recover())

	// CORS middleware
	s.echo.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete, http.MethodPatch},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization},
	}))

	// Request ID middleware
	s.echo.Use(middleware.RequestID())

	// Timeout middleware
	s.echo.Use(middleware.ContextTimeout(30 * time.Second))

}

func (s *Server) StartWithGracefulShutdown() error {
	serverErrors := make(chan error, 1)
	go func() {
		address := fmt.Sprintf(":%s", s.config.ServerPort)
		s.echo.Logger.Info(fmt.Sprintf("Starting the server on:%s", address))
		serverErrors <- s.echo.Start(address)
	}()

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		return fmt.Errorf("server error:%w", err)
	case sig := <-shutdown:
		s.echo.Logger.Info(fmt.Sprintf("Recieved signal:%v,Starting graceful shutdown...", sig))
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		//attempt to graceful shutdown
		if err := s.echo.Shutdown(ctx); err != nil {
			s.echo.Logger.Error(fmt.Sprintf("Graceful shutdown failed:%v", err))
			return s.echo.Close()
		}
		s.echo.Logger.Info("server stopped gracefully")
		return nil
	}
}

func (s *Server) Close() error {
	s.db.Close()
	return s.echo.Close()
}
