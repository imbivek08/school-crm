package router

import (
	"net/http"

	"github.com/imbivek08/school-crm/internal/config"
	"github.com/imbivek08/school-crm/internal/database"
	"github.com/labstack/echo/v4"
)

func SetupRoutes(e *echo.Echo, db *database.Databse, cfg *config.Config) {
	e.GET("/health", func(ctx echo.Context) error {
		return ctx.JSON(http.StatusOK, map[string]string{
			"status":  "ok",
			"message": "server is running",
		})
	})
}
